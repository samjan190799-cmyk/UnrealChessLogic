// Copyright (c) 2026. Все права защищены.
#include "Input/ChessPlayerController.h"
#include "Visual/ChessBoardActor.h"
#include "Visual/ChessPieceActor.h"
#include "Camera/ChessCameraActor.h"
#include "ChessGameManager.h"
#include "Engine/World.h"
#include "GameFramework/ForceFeedbackEffect.h"
#include "Kismet/GameplayStatics.h"

AChessPlayerController::AChessPlayerController()
{
	bShowMouseCursor = true;
	bEnableClickEvents = true;
	bEnableTouchEvents = true;
	bEnableTouchOverEvents = true;
	DefaultMouseCursor = EMouseCursor::Hand;

	SelectedCoord = FChessCoordinate(-1, -1);
}

void AChessPlayerController::BeginPlay()
{
	Super::BeginPlay();

	// Автоматический поиск доски и камеры на уровне, если они не были переданы вручную
	if (!BoardActor)
	{
		BoardActor = Cast<AChessBoardActor>(UGameplayStatics::GetActorOfClass(GetWorld(), AChessBoardActor::StaticClass()));
	}

	if (!CameraActor)
	{
		CameraActor = Cast<AChessCameraActor>(UGameplayStatics::GetActorOfClass(GetWorld(), AChessCameraActor::StaticClass()));
		if (CameraActor)
		{
			SetViewTargetWithBlend(CameraActor, 0.5f);
		}
	}
}

void AChessPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();

	if (InputComponent)
	{
		// Привязка сенсорного ввода под iOS / iPadOS
		InputComponent->BindTouch(IE_Pressed, this, &AChessPlayerController::OnTouchPressed);

		// Привязка левой кнопки мыши для тестирования в редакторе UE5
		InputComponent->BindKey(EKeys::LeftMouseButton, IE_Pressed, this, &AChessPlayerController::OnMouseLeftClicked);
	}
}

void AChessPlayerController::SetupGameReferences(UChessGameManager* InManager, AChessBoardActor* InBoard, AChessCameraActor* InCamera)
{
	GameManager = InManager;
	BoardActor = InBoard;
	CameraActor = InCamera;

	if (GameManager)
	{
		GameManager->OnMoveExecuted.AddDynamic(this, &AChessPlayerController::HandleMoveExecuted);
		GameManager->OnCheckStatus.AddDynamic(this, &AChessPlayerController::HandleCheckStatus);
	}

	if (CameraActor)
	{
		SetViewTargetWithBlend(CameraActor, 0.5f);
	}
}

void AChessPlayerController::OnTouchPressed(ETouchIndex::Type FingerIndex, FVector Location)
{
	if (FingerIndex == ETouchIndex::Touch1)
	{
		ProcessScreenTap(FVector2D(Location.X, Location.Y));
	}
}

void AChessPlayerController::OnMouseLeftClicked()
{
	float MouseX = 0.0f;
	float MouseY = 0.0f;
	if (GetMousePosition(MouseX, MouseY))
	{
		ProcessScreenTap(FVector2D(MouseX, MouseY));
	}
}

void AChessPlayerController::ProcessScreenTap(const FVector2D& ScreenPosition)
{
	if (!GameManager || !BoardActor)
	{
		return;
	}

	FHitResult HitResult;
	const bool bHit = GetHitResultAtScreenPosition(ScreenPosition, ECC_Visibility, true, HitResult);

	if (!bHit || !HitResult.GetActor())
	{
		ClearSelection();
		return;
	}

	FChessCoordinate TappedCoord(-1, -1);

	// 1. Проверяем, попал ли луч в фигуру AChessPieceActor
	if (AChessPieceActor* HitPiece = Cast<AChessPieceActor>(HitResult.GetActor()))
	{
		TappedCoord = HitPiece->BoardCoordinate;
	}
	// 2. Проверяем, попал ли луч в доску AChessBoardActor
	else if (HitResult.GetActor() == BoardActor)
	{
		TappedCoord = BoardActor->GetCoordinateFromWorldLocation(HitResult.Location);
	}

	if (!TappedCoord.IsValid())
	{
		ClearSelection();
		return;
	}

	const FChessPiece TappedPiece = GameManager->GetPieceAt(TappedCoord);
	const EChessColor CurrentTurn = GameManager->GetCurrentTurn();

	// Сценарий А: Уже выбрана фигура игрока
	if (SelectedCoord.IsValid())
	{
		// Если кликнули по той же самой фигуре — снимаем выделение
		if (TappedCoord == SelectedCoord)
		{
			ClearSelection();
			return;
		}

		// Если кликнули по другой своей фигуре — переключаем выбор
		if (TappedPiece.IsValidPiece() && TappedPiece.Color == CurrentTurn)
		{
			SelectCoordinate(TappedCoord);
			return;
		}

		// Попытка подтвердить ход на целевую клетку (пустую или с вражеской фигурой)
		const bool bMoveSuccess = ConfirmMove(TappedCoord);
		if (!bMoveSuccess)
		{
			ClearSelection();
		}
	}
	// Сценарий Б: Выбора еще нет — выбираем фигуру текущего игрока
	else
	{
		if (TappedPiece.IsValidPiece() && TappedPiece.Color == CurrentTurn)
		{
			SelectCoordinate(TappedCoord);
		}
	}
}

void AChessPlayerController::SelectCoordinate(const FChessCoordinate& Coord)
{
	if (!GameManager || !BoardActor || !Coord.IsValid())
	{
		return;
	}

	const FChessPiece Piece = GameManager->GetPieceAt(Coord);
	if (Piece.IsEmpty() || Piece.Color != GameManager->GetCurrentTurn())
	{
		ClearSelection();
		return;
	}

	SelectedCoord = Coord;
	CurrentLegalMoves = GameManager->GetLegalMovesForPiece(Coord);

	// Обновляем визуальную подсветку на 3D-доске
	BoardActor->HighlightSelectedTile(Coord);
	BoardActor->HighlightLegalMoves(CurrentLegalMoves);

	// Легкая тактильная отдача при выборе фигуры (iOS Haptic)
	TriggerHapticFeedback(0.3f, 0.04f);
}

void AChessPlayerController::ClearSelection()
{
	SelectedCoord = FChessCoordinate(-1, -1);
	CurrentLegalMoves.Empty();

	if (BoardActor)
	{
		BoardActor->ClearAllHighlights();
	}
}

bool AChessPlayerController::ConfirmMove(const FChessCoordinate& TargetCoord, EChessPieceType PromotionChoice)
{
	if (!SelectedCoord.IsValid() || !GameManager)
	{
		return false;
	}

	const bool bSuccess = GameManager->TryMakeMove(SelectedCoord, TargetCoord, PromotionChoice);
	if (bSuccess)
	{
		// Тактильный отклик успешного хода
		TriggerHapticFeedback(0.7f, 0.1f);
		ClearSelection();
		return true;
	}

	return false;
}

void AChessPlayerController::TriggerHapticFeedback(float Intensity, float Duration)
{
	// Воспроизведение мобильной тактильной отдачи
	if (MoveFeedbackEffect)
	{
		ClientPlayForceFeedback(MoveFeedbackEffect, false, false, FName("ChessMoveFeedback"));
	}
}

void AChessPlayerController::HandleMoveExecuted(const FChessMove& Move)
{
	// Если было взятие фигуры — активируем динамический наезд камеры
	if (Move.IsCapture() && CameraActor && BoardActor)
	{
		const FVector TargetLocation = BoardActor->GetTileWorldLocation(Move.To);
		CameraActor->TriggerAttackPunch(TargetLocation, 950.0f, 0.5f);
	}
}

void AChessPlayerController::HandleCheckStatus(EChessColor CheckedPlayer, const FChessCoordinate& KingCoordinate)
{
	// При шахе фокусируем кинематографичную камеру на атакованном короле
	if (CameraActor && BoardActor)
	{
		const FVector KingLocation = BoardActor->GetTileWorldLocation(KingCoordinate);
		CameraActor->TriggerCheckFocus(KingLocation, 820.0f, 0.8f);
	}

	// Сильный виброотклик опасности
	TriggerHapticFeedback(1.0f, 0.2f);
}
