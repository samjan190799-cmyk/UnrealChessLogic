// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ChessTypes.h"
#include "ChessPieceActor.generated.h"

class UStaticMeshComponent;
class USceneComponent;
class UMaterialInstanceDynamic;

/**
 * 3D-актер шахматной фигуры в Unreal Engine 5.
 * Реализует плавную параболическую интерполяцию перемещения (EaseInOut),
 * анимации взятия, смену материалов и визуальную подсветку.
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API AChessPieceActor : public AActor
{
	GENERATED_BODY()

public:
	AChessPieceActor();

	virtual void Tick(float DeltaTime) override;

	/** Инициализация фигуры */
	UFUNCTION(BlueprintCallable, Category = "Chess|Piece")
	void InitializePiece(EChessPieceType InType, EChessColor InColor, const FChessCoordinate& InCoord);

	/**
	 * Запуск плавного перемещения на целевую мировую позицию.
	 * @param TargetLocation Целевая 3D-позиция на доске
	 * @param InDuration Длительность анимации (в секундах)
	 * @param InArcHeight Высота параболического подъема над доской
	 */
	UFUNCTION(BlueprintCallable, Category = "Chess|Animation")
	void AnimateMoveTo(const FVector& TargetLocation, float InDuration = 0.35f, float InArcHeight = 50.0f);

	/** Запуск анимации взятия фигуры (падение, закручивание и исчезновение) */
	UFUNCTION(BlueprintCallable, Category = "Chess|Animation")
	void PlayCaptureAnimation(float InDuration = 0.4f);

	/** Установка визуальной подсветки фигуры (выбрана игроком) */
	UFUNCTION(BlueprintCallable, Category = "Chess|Visual")
	void SetHighlightState(bool bIsSelected);

	/** Обновление меша фигуры (например, при превращении пешки) */
	UFUNCTION(BlueprintCallable, Category = "Chess|Visual")
	void UpdatePieceMesh(EChessPieceType NewType);

	// ----------------------------------------------------------------------
	// СВОЙСТВА И КОМПОНЕНТЫ
	// ----------------------------------------------------------------------

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	USceneComponent* SceneRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UStaticMeshComponent* MeshComponent;

	/** Тип фигуры */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Piece")
	EChessPieceType PieceType = EChessPieceType::None;

	/** Цвет фигуры */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Piece")
	EChessColor PieceColor = EChessColor::None;

	/** Текущие координаты клетки на доске */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Piece")
	FChessCoordinate BoardCoordinate;

	/** Завершена ли анимация движения */
	UFUNCTION(BlueprintPure, Category = "Chess|Animation")
	bool IsAnimating() const { return bIsMoving || bIsCapturing; }

protected:
	virtual void BeginPlay() override;

private:
	// Параметры интерполяции перемещения
	bool bIsMoving = false;
	FVector StartMoveLocation;
	FVector TargetMoveLocation;
	float MoveDuration = 0.35f;
	float MoveElapsedTime = 0.0f;
	float ArcHeight = 50.0f;

	// Параметры анимации взятия
	bool bIsCapturing = false;
	float CaptureDuration = 0.4f;
	float CaptureElapsedTime = 0.0f;
	FVector StartCaptureScale;
	FRotator StartCaptureRotation;

	/** Динамический инстанс материала для эффектов подсветки */
	UPROPERTY()
	UMaterialInstanceDynamic* DynamicMaterial = nullptr;
};
