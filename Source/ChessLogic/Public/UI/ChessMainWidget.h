// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "ChessTypes.h"
#include "ChessMainWidget.generated.h"

class UTextBlock;
class UButton;
class UBorder;
class UChessGameManager;

/**
 * Главный виджет пользовательского интерфейса (UMG UI) для шахматной партии в Unreal Engine 5.
 * Отображает шахматные часы для белых и черных, индикатор текущего хода,
 * баннер статуса партии (Шах, Мат, Пат) и кнопки управления («Новая игра», «Отмена хода»).
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API UChessMainWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	UChessMainWidget(const FObjectInitializer& ObjectInitializer);

	virtual void NativeConstruct() override;
	virtual void NativeTick(const FGeometry& MyGeometry, float InDeltaTime) override;

	/** Привязка к менеджеру шахматной логики */
	UFUNCTION(BlueprintCallable, Category = "Chess|UI")
	void InitializeWithManager(UChessGameManager* InManager);

	/** Установка начального лимита времени на партию (в секундах) */
	UFUNCTION(BlueprintCallable, Category = "Chess|UI")
	void SetTimeLimit(float InSeconds = 600.0f);

	// ----------------------------------------------------------------------
	// ВИЗУАЛЬНЫЕ ЭЛЕМЕНТЫ UMG (Привязка через BindWidget)
	// ----------------------------------------------------------------------

	/** Таймер оставшегося времени белых */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UTextBlock* WhiteTimerText = nullptr;

	/** Таймер оставшегося времени черных */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UTextBlock* BlackTimerText = nullptr;

	/** Текст текущего хода («Ход Белых» / «Ход Черных») */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UTextBlock* TurnStatusText = nullptr;

	/** Баннер статуса игры («Шах!», «Мат!», «Пат») */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UTextBlock* GameStateBannerText = nullptr;

	/** Кнопка сброса и начала новой партии */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UButton* RestartButton = nullptr;

	/** Кнопка отмены последнего хода */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UButton* UndoButton = nullptr;

	/** Визуальный акцент активного хода белых */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UBorder* WhiteTurnIndicator = nullptr;

	/** Визуальный акцент активного хода черных */
	UPROPERTY(meta = (BindWidgetOptional), BlueprintReadOnly, Category = "Chess|UI")
	UBorder* BlackTurnIndicator = nullptr;

protected:
	UPROPERTY(Transient, BlueprintReadOnly, Category = "Chess|Manager")
	UChessGameManager* GameManager = nullptr;

	/** Оставшееся время белых (в секундах) */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Timer")
	float WhiteTimeRemaining = 600.0f;

	/** Оставшееся время черных (в секундах) */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Timer")
	float BlackTimeRemaining = 600.0f;

	/** Начальный лимит времени на партию */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Timer")
	float InitialTimeLimit = 600.0f;

	/** Запущены ли часы */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Timer")
	bool bIsTimerActive = false;

	// Обработчики кнопок UI
	UFUNCTION()
	void HandleRestartClicked();

	UFUNCTION()
	void HandleUndoClicked();

	// Слушатели событий движка
	UFUNCTION()
	void HandleMoveExecuted(const FChessMove& Move);

	UFUNCTION()
	void HandleGameStateChanged(EChessGameState NewState, EChessColor CurrentTurn);

	UFUNCTION()
	void HandleBoardReset();

	/** Форматирование секунд в строку «ММ:СС» */
	FText FormatTimeString(float TotalSeconds) const;

	/** Обновление текстов на экране */
	void RefreshUI();
};
