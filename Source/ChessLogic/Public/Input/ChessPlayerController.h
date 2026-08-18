// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "ChessTypes.h"
#include "ChessPlayerController.generated.h"

class UChessGameManager;
class AChessBoardActor;
class AChessCameraActor;
class UForceFeedbackEffect;

/**
 * Сенсорный PlayerController для Unreal Engine 5 с поддержкой iOS / мобильных устройств.
 * Обрабатывает тапы по фигурам и доске, депроецирует лучи в 3D-мир (Screen Raycast),
 * управляет подсветкой клеток, подтверждением ходов и тактильным откликом (Haptic Feedback).
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API AChessPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	AChessPlayerController();

	virtual void BeginPlay() override;
	virtual void SetupInputComponent() override;

	/** Инициализация ссылок на игровой менеджер, 3D-доску и камеру */
	UFUNCTION(BlueprintCallable, Category = "Chess|Controller")
	void SetupGameReferences(UChessGameManager* InManager, AChessBoardActor* InBoard, AChessCameraActor* InCamera);

	/** Выбор фигуры на заданной клетке */
	UFUNCTION(BlueprintCallable, Category = "Chess|Interaction")
	void SelectCoordinate(const FChessCoordinate& Coord);

	/** Сброс текущего выбора */
	UFUNCTION(BlueprintCallable, Category = "Chess|Interaction")
	void ClearSelection();

	/** Подтверждение и отправка хода */
	UFUNCTION(BlueprintCallable, Category = "Chess|Interaction")
	bool ConfirmMove(const FChessCoordinate& TargetCoord, EChessPieceType PromotionChoice = EChessPieceType::Queen);

	/** Тактильная отдача для мобильных устройств (iOS Haptic Feedback) */
	UFUNCTION(BlueprintCallable, Category = "Chess|Haptics")
	void TriggerHapticFeedback(float Intensity = 0.5f, float Duration = 0.1f);

	// ----------------------------------------------------------------------
	// СВОЙСТВА И НАСТРОЙКИ
	// ----------------------------------------------------------------------

	/** Текущая выбранная клетка доски */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|State")
	FChessCoordinate SelectedCoord;

	/** Доступные легальные ходы для выбранной фигуры */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|State")
	TArray<FChessMove> CurrentLegalMoves;

	/** Эффект виброотклика для ходов */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Config")
	UForceFeedbackEffect* MoveFeedbackEffect = nullptr;

	/** Эффект виброотклика для взятий и шаха */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Config")
	UForceFeedbackEffect* CaptureFeedbackEffect = nullptr;

protected:
	UPROPERTY(Transient, BlueprintReadOnly, Category = "Chess|Manager")
	UChessGameManager* GameManager = nullptr;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "Chess|Visual")
	AChessBoardActor* BoardActor = nullptr;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "Chess|Camera")
	AChessCameraActor* CameraActor = nullptr;

	// Обработчики сенсорного и мышиного ввода
	void OnTouchPressed(ETouchIndex::Type FingerIndex, FVector Location);
	void OnMouseLeftClicked();

	/** Обработка клика/тапа по координатам экрана */
	void ProcessScreenTap(const FVector2D& ScreenPosition);

	// Слушатели событий менеджера игры
	UFUNCTION()
	void HandleMoveExecuted(const FChessMove& Move);

	UFUNCTION()
	void HandleCheckStatus(EChessColor CheckedPlayer, const FChessCoordinate& KingCoordinate);
};
