// Copyright (c) 2026. Все права защищены.
#include "Visual/ChessBoardActor.h"
#include "Visual/ChessPieceActor.h"
#include "Visual/ChessFracturedPiece.h"
#include "Camera/ChessCameraActor.h"
#include "ChessGameManager.h"
#include "Components/StaticMeshComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"

AChessBoardActor::AChessBoardActor()
{
	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

	BoardFrameMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("BoardFrameMesh"));
	BoardFrameMesh->SetupAttachment(RootComponent);
	BoardFrameMesh->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	BoardFrameMesh->SetCollisionResponseToAllChannels(ECR_Block);
	BoardFrameMesh->SetCollisionObjectType(ECC_WorldStatic);

	// Инстансированные маркеры подсветки для минимизации Draw Calls на iOS
	MoveIndicatorMesh = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("MoveIndicatorMesh"));
	MoveIndicatorMesh->SetupAttachment(RootComponent);
	MoveIndicatorMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	MoveIndicatorMesh->SetCastShadow(false);

	CaptureIndicatorMesh = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("CaptureIndicatorMesh"));
	CaptureIndicatorMesh->SetupAttachment(RootComponent);
	CaptureIndicatorMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	CaptureIndicatorMesh->SetCastShadow(false);

	PieceActorClass = AChessPieceActor::StaticClass();
	FracturedPieceClass = AChessFracturedPiece::StaticClass();
}

void AChessBoardActor::BeginPlay()
{
	Super::BeginPlay();
}

void AChessBoardActor::InitializeWithManager(UChessGameManager* InGameManager)
{
	if (!InGameManager)
	{
		return;
	}

	GameManager = InGameManager;

	// Подписка на события шахматного менеджера
	GameManager->OnMoveExecuted.AddDynamic(this, &AChessBoardActor::HandleMoveExecuted);
	GameManager->OnPieceCaptured.AddDynamic(this, &AChessBoardActor::HandlePieceCaptured);
	GameManager->OnCheckStatus.AddDynamic(this, &AChessBoardActor::HandleCheckStatus);
	GameManager->OnBoardReset.AddDynamic(this, &AChessBoardActor::HandleBoardReset);

	RefreshBoardPieces();
}

FVector AChessBoardActor::GetTileWorldLocation(const FChessCoordinate& Coord) const
{
	if (!Coord.IsValid())
	{
		return GetActorLocation();
	}

	const float LocalX = (Coord.Col - 3.5f) * TileSize;
	const float LocalY = (Coord.Row - 3.5f) * TileSize;
	const FVector LocalPos(LocalX, LocalY, BoardHeightOffset);

	return GetActorTransform().TransformPosition(LocalPos);
}

FChessCoordinate AChessBoardActor::GetCoordinateFromWorldLocation(const FVector& WorldLocation) const
{
	const FVector LocalPos = GetActorTransform().InverseTransformPosition(WorldLocation);

	const int32 Col = FMath::FloorToInt((LocalPos.X / TileSize) + 4.0f);
	const int32 Row = FMath::FloorToInt((LocalPos.Y / TileSize) + 4.0f);

	const FChessCoordinate Coord(Col, Row);
	return Coord.IsValid() ? Coord : FChessCoordinate(-1, -1);
}

AChessPieceActor* AChessBoardActor::GetPieceActorAt(const FChessCoordinate& Coord) const
{
	AChessPieceActor* const* FoundActor = SpawnedPieceActors.Find(Coord);
	return FoundActor ? *FoundActor : nullptr;
}

void AChessBoardActor::HighlightSelectedTile(const FChessCoordinate& Coord)
{
	ClearAllHighlights();

	AChessPieceActor* SelectedPiece = GetPieceActorAt(Coord);
	if (SelectedPiece)
	{
		SelectedPiece->SetHighlightState(true);
	}
}

void AChessBoardActor::HighlightLegalMoves(const TArray<FChessMove>& LegalMoves)
{
	MoveIndicatorMesh->ClearInstances();
	CaptureIndicatorMesh->ClearInstances();

	for (const FChessMove& Move : LegalMoves)
	{
		const FVector TileLocation = GetTileWorldLocation(Move.To);
		FTransform InstanceTransform(FRotator::ZeroRotator, TileLocation + FVector(0.0f, 0.0f, 2.0f), FVector(0.8f, 0.8f, 0.1f));

		if (Move.IsCapture() || Move.SpecialType == ESpecialMoveType::EnPassant)
		{
			CaptureIndicatorMesh->AddInstance(InstanceTransform);
		}
		else
		{
			MoveIndicatorMesh->AddInstance(InstanceTransform);
		}
	}
}

void AChessBoardActor::HighlightCheck(const FChessCoordinate& KingCoord)
{
	AChessPieceActor* KingActor = GetPieceActorAt(KingCoord);
	if (KingActor)
	{
		KingActor->SetHighlightState(true);
	}
}

void AChessBoardActor::ClearAllHighlights()
{
	MoveIndicatorMesh->ClearInstances();
	CaptureIndicatorMesh->ClearInstances();

	for (auto& Pair : SpawnedPieceActors)
	{
		if (Pair.Value && IsValid(Pair.Value))
		{
			Pair.Value->SetHighlightState(false);
		}
	}
}

void AChessBoardActor::RefreshBoardPieces()
{
	if (!GetWorld() || !GameManager)
	{
		return;
	}

	for (auto& Pair : SpawnedPieceActors)
	{
		if (Pair.Value && IsValid(Pair.Value))
		{
			Pair.Value->Destroy();
		}
	}
	SpawnedPieceActors.Empty();
	ClearAllHighlights();

	UClass* ClassToSpawn = PieceActorClass ? PieceActorClass.Get() : AChessPieceActor::StaticClass();

	FActorSpawnParameters SpawnParams;
	SpawnParams.Owner = this;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

	for (int32 Col = 0; Col < 8; ++Col)
	{
		for (int32 Row = 0; Row < 8; ++Row)
		{
			const FChessCoordinate Coord(Col, Row);
			const FChessPiece Piece = GameManager->GetPieceAt(Coord);

			if (Piece.IsValidPiece())
			{
				const FVector SpawnLoc = GetTileWorldLocation(Coord);
				AChessPieceActor* PieceActor = GetWorld()->SpawnActor<AChessPieceActor>(ClassToSpawn, SpawnLoc, FRotator::ZeroRotator, SpawnParams);
				if (PieceActor)
				{
					PieceActor->InitializePiece(Piece.Type, Piece.Color, Coord);
					PieceActor->AttachToActor(this, FAttachmentTransformRules::KeepWorldTransform);
					SpawnedPieceActors.Add(Coord, PieceActor);
				}
			}
		}
	}
}

void AChessBoardActor::HandleMoveExecuted(const FChessMove& Move)
{
	ClearAllHighlights();

	AChessPieceActor* MovingActor = nullptr;
	if (SpawnedPieceActors.RemoveAndCopyValue(Move.From, MovingActor) && MovingActor)
	{
		SpawnedPieceActors.Add(Move.To, MovingActor);
		MovingActor->BoardCoordinate = Move.To;
		
		// Динамическая скорость удара при атаке (быстрый бросок на клетку жертвы)
		const float MoveTime = Move.IsCapture() ? 0.28f : 0.35f;
		const float ArcHeight = Move.IsCapture() ? 35.0f : 50.0f;
		MovingActor->AnimateMoveTo(GetTileWorldLocation(Move.To), MoveTime, ArcHeight);

		if (Move.SpecialType == ESpecialMoveType::Promotion)
		{
			MovingActor->UpdatePieceMesh(Move.PromotedPieceType);
		}
	}

	// Обработка рокировки: синхронное перемещение ладьи
	if (Move.SpecialType == ESpecialMoveType::CastlingKingside)
	{
		const int32 Row = Move.From.Row;
		const FChessCoordinate RookFrom(7, Row);
		const FChessCoordinate RookTo(5, Row);

		AChessPieceActor* RookActor = nullptr;
		if (SpawnedPieceActors.RemoveAndCopyValue(RookFrom, RookActor) && RookActor)
		{
			SpawnedPieceActors.Add(RookTo, RookActor);
			RookActor->BoardCoordinate = RookTo;
			RookActor->AnimateMoveTo(GetTileWorldLocation(RookTo), 0.35f, 30.0f);
		}
	}
	else if (Move.SpecialType == ESpecialMoveType::CastlingQueenside)
	{
		const int32 Row = Move.From.Row;
		const FChessCoordinate RookFrom(0, Row);
		const FChessCoordinate RookTo(3, Row);

		AChessPieceActor* RookActor = nullptr;
		if (SpawnedPieceActors.RemoveAndCopyValue(RookFrom, RookActor) && RookActor)
		{
			SpawnedPieceActors.Add(RookTo, RookActor);
			RookActor->BoardCoordinate = RookTo;
			RookActor->AnimateMoveTo(GetTileWorldLocation(RookTo), 0.35f, 30.0f);
		}
	}
}

void AChessBoardActor::HandlePieceCaptured(const FChessPiece& CapturedPiece, const FChessCoordinate& CapturedAt)
{
	AChessPieceActor* CapturedActor = nullptr;
	if (SpawnedPieceActors.RemoveAndCopyValue(CapturedAt, CapturedActor) && CapturedActor)
	{
		const FVector TargetLocation = GetTileWorldLocation(CapturedAt);

		// 1. Спавн разрушаемой фигуры Chaos Physics
		if (FracturedPieceClass && GetWorld())
		{
			FActorSpawnParameters SpawnParams;
			SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;

			AChessFracturedPiece* FracturedActor = GetWorld()->SpawnActor<AChessFracturedPiece>(
				FracturedPieceClass,
				TargetLocation,
				CapturedActor->GetActorRotation(),
				SpawnParams
			);

			if (FracturedActor)
			{
				// Множитель импульса в зависимости от ценности фигуры
				float ImpulseMultiplier = 1.0f;
				switch (CapturedPiece.Type)
				{
					case EChessPieceType::Queen:  ImpulseMultiplier = 2.2f; break;
					case EChessPieceType::Rook:   ImpulseMultiplier = 1.6f; break;
					case EChessPieceType::Bishop: ImpulseMultiplier = 1.3f; break;
					case EChessPieceType::Knight: ImpulseMultiplier = 1.3f; break;
					default: ImpulseMultiplier = 1.0f; break;
				}

				// Направление разлета обломков
				const FVector HitDir = FVector(FMath::RandRange(-0.5f, 0.5f), FMath::RandRange(-0.5f, 0.5f), 0.5f).GetSafeNormal();
				FracturedActor->TriggerFracture(HitDir, ImpulseMultiplier);

				// 2. Микро-встряска камеры
				AChessCameraActor* Camera = Cast<AChessCameraActor>(UGameplayStatics::GetActorOfClass(GetWorld(), AChessCameraActor::StaticClass()));
				if (Camera)
				{
					Camera->PlayImpactShake(ImpulseMultiplier);
				}
			}
		}

		// 3. Быстрое скрытие и уничтожение стандартного меша
		CapturedActor->Destroy();
	}
}

void AChessBoardActor::HandleCheckStatus(EChessColor CheckedPlayer, const FChessCoordinate& KingCoordinate)
{
	HighlightCheck(KingCoordinate);
}

void AChessBoardActor::HandleBoardReset()
{
	RefreshBoardPieces();
}
