// Copyright (c) 2026. Все права защищены.
#include "UI/ChessMainWidget.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/Border.h"
#include "ChessGameManager.h"

UChessMainWidget::UChessMainWidget(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	InitialTimeLimit = 600.0f;
	WhiteTimeRemaining = InitialTimeLimit;
	BlackTimeRemaining = InitialTimeLimit;
	bIsTimerActive = false;
}

void UChessMainWidget::NativeConstruct()
{
	Super::NativeConstruct();

	if (RestartButton)
	{
		RestartButton->OnClicked.AddDynamic(this, &UChessMainWidget::HandleRestartClicked);
	}

	if (UndoButton)
	{
		UndoButton->OnClicked.AddDynamic(this, &UChessMainWidget::HandleUndoClicked);
	}

	RefreshUI();
}

void UChessMainWidget::InitializeWithManager(UChessGameManager* InManager)
{
	if (!InManager)
	{
		return;
	}

	GameManager = InManager;

	GameManager->OnMoveExecuted.AddDynamic(this, &UChessMainWidget::HandleMoveExecuted);
	GameManager->OnGameStateChanged.AddDynamic(this, &UChessMainWidget::HandleGameStateChanged);
	GameManager->OnBoardReset.AddDynamic(this, &UChessMainWidget::HandleBoardReset);

	WhiteTimeRemaining = InitialTimeLimit;
	BlackTimeRemaining = InitialTimeLimit;
	bIsTimerActive = false;

	RefreshUI();
}

void UChessMainWidget::SetTimeLimit(float InSeconds)
{
	InitialTimeLimit = FMath::Max(30.0f, InSeconds);
	WhiteTimeRemaining = InitialTimeLimit;
	BlackTimeRemaining = InitialTimeLimit;
	RefreshUI();
}

void UChessMainWidget::NativeTick(const FGeometry& MyGeometry, float InDeltaTime)
{
	Super::NativeTick(MyGeometry, InDeltaTime);

	// Отсчет времени активного игрока
	if (bIsTimerActive && GameManager)
	{
		const EChessColor ActiveTurn = GameManager->GetCurrentTurn();
		if (ActiveTurn == EChessColor::White)
		{
			WhiteTimeRemaining = FMath::Max(0.0f, WhiteTimeRemaining - InDeltaTime);
		}
		else if (ActiveTurn == EChessColor::Black)
		{
			BlackTimeRemaining = FMath::Max(0.0f, BlackTimeRemaining - InDeltaTime);
		}

		if (WhiteTimerText)
		{
			WhiteTimerText->SetText(FormatTimeString(WhiteTimeRemaining));
		}
		if (BlackTimerText)
		{
			BlackTimerText->SetText(FormatTimeString(BlackTimeRemaining));
		}
	}
}

void UChessMainWidget::HandleRestartClicked()
{
	if (GameManager)
	{
		GameManager->StartNewGame();
	}
}

void UChessMainWidget::HandleUndoClicked()
{
	if (GameManager)
	{
		GameManager->UndoLastMove();
	}
}

void UChessMainWidget::HandleMoveExecuted(const FChessMove& Move)
{
	bIsTimerActive = true;
	RefreshUI();
}

void UChessMainWidget::HandleGameStateChanged(EChessGameState NewState, EChessColor CurrentTurn)
{
	if (NewState == EChessGameState::Checkmate ||
	    NewState == EChessGameState::Stalemate ||
	    NewState == EChessGameState::Draw)
	{
		bIsTimerActive = false;
	}

	RefreshUI();
}

void UChessMainWidget::HandleBoardReset()
{
	WhiteTimeRemaining = InitialTimeLimit;
	BlackTimeRemaining = InitialTimeLimit;
	bIsTimerActive = false;
	RefreshUI();
}

FText UChessMainWidget::FormatTimeString(float TotalSeconds) const
{
	const int32 Minutes = FMath::FloorToInt(TotalSeconds / 60.0f);
	const int32 Seconds = FMath::FloorToInt(FMath::Fmod(TotalSeconds, 60.0f));
	return FText::FromString(FString::Printf(TEXT("%02d:%02d"), Minutes, Seconds));
}

void UChessMainWidget::RefreshUI()
{
	// 1. Отображение таймеров
	if (WhiteTimerText)
	{
		WhiteTimerText->SetText(FormatTimeString(WhiteTimeRemaining));
	}
	if (BlackTimerText)
	{
		BlackTimerText->SetText(FormatTimeString(BlackTimeRemaining));
	}

	if (!GameManager)
	{
		return;
	}

	const EChessColor CurrentTurn = GameManager->GetCurrentTurn();
	const EChessGameState GameState = GameManager->GetCurrentGameState();

	// 2. Индикатор активного хода
	if (TurnStatusText)
	{
		const FString TurnStr = (CurrentTurn == EChessColor::White) ? TEXT("Ход Белых") : TEXT("Ход Черных");
		TurnStatusText->SetText(FText::FromString(TurnStr));
	}

	// 3. Подсветка активной рамки игрока
	if (WhiteTurnIndicator)
	{
		const FLinearColor ActiveColor = (CurrentTurn == EChessColor::White) ? FLinearColor(0.1f, 0.7f, 1.0f, 0.9f) : FLinearColor(0.2f, 0.2f, 0.2f, 0.4f);
		WhiteTurnIndicator->SetBrushColor(ActiveColor);
	}
	if (BlackTurnIndicator)
	{
		const FLinearColor ActiveColor = (CurrentTurn == EChessColor::Black) ? FLinearColor(1.0f, 0.3f, 0.2f, 0.9f) : FLinearColor(0.2f, 0.2f, 0.2f, 0.4f);
		BlackTurnIndicator->SetBrushColor(ActiveColor);
	}

	// 4. Баннер статуса партии (Шах / Мат / Пат)
	if (GameStateBannerText)
	{
		FString BannerStr = TEXT("");
		switch (GameState)
		{
			case EChessGameState::Check:
				BannerStr = TEXT("⚠️ ШАХ!");
				break;
			case EChessGameState::Checkmate:
			{
				const FString Winner = (CurrentTurn == EChessColor::White) ? TEXT("Черных") : TEXT("Белых");
				BannerStr = FString::Printf(TEXT("🏆 МАТ! Победа %s"), *Winner);
				break;
			}
			case EChessGameState::Stalemate:
				BannerStr = TEXT("🤝 ПАТ — Ничья");
				break;
			case EChessGameState::Draw:
				BannerStr = TEXT("🤝 НИЧЬЯ (Правило 50 ходов)");
				break;
			default:
				BannerStr = TEXT("");
				break;
		}
		GameStateBannerText->SetText(FText::FromString(BannerStr));
	}
}
