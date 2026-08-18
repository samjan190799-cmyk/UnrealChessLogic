// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ChessTypes.h"
#include "ChessFracturedPiece.generated.h"

class UGeometryCollectionComponent;
class USceneComponent;
class UNiagaraSystem;

/**
 * 3D-актер разрушаемой шахматной фигуры на базе Chaos Physics (Geometry Collection).
 * Реализует два уникальных типа эффектов разрушения:
 * 1. Белые: Светлая энергия, золотисто-костяные осколки, сияющая пыль и искры.
 * 2. Черные: Темная энергия, раскаленный лавовый обсидиан, дымящиеся угли и огонь.
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API AChessFracturedPiece : public AActor
{
	GENERATED_BODY()

public:
	AChessFracturedPiece();

	virtual void Tick(float DeltaTime) override;

	/**
	 * Инициализация и приложение кинетического импульса разрушения.
	 * @param HitDirection Направление удара атакующей фигуры
	 * @param ImpulseMultiplier Множитель силы удара (зависит от ранга фигуры)
	 * @param InPieceColor Цвет разрушаемой фигуры (для выбора типа визуального эффекта)
	 */
	UFUNCTION(BlueprintCallable, Category = "Chess|Physics")
	void TriggerFracture(const FVector& HitDirection, float ImpulseMultiplier = 1.0f, EChessPieceColor InPieceColor = EChessPieceColor::White);

	// ----------------------------------------------------------------------
	// КОМПОНЕНТЫ И ПАРАМЕТРЫ ФИЗИКИ
	// ----------------------------------------------------------------------

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	USceneComponent* SceneRoot;

	/** Компонент разрушения Chaos Physics */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UGeometryCollectionComponent* GeometryCollectionComponent;

	/** Niagara VFX для белых фигур: древние кости, золотая пыль и сияние */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|VFX")
	UNiagaraSystem* WhiteBoneGoldVFX = nullptr;

	/** Niagara VFX для черных фигур: раскаленный обсидиан, лава и дым */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|VFX")
	UNiagaraSystem* BlackMagmaObsidianVFX = nullptr;

	/** Время до перевода физических тел обломков в спящий режим (сбережение батареи/CPU iOS) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Optimization")
	float SleepDelay = 1.8f;

	/** Полное время жизни актера с обломками до удаления со сцены */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Optimization")
	float TotalLifeSpan = 2.6f;

	/** Базовая сила физического импульса удара */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Physics")
	float BaseImpulseStrength = 12000.0f;

protected:
	virtual void BeginPlay() override;

private:
	float ElapsedLifeTime = 0.0f;
	bool bPhysicsAsleep = false;
	bool bIsFadingOut = false;
	FVector InitialScale;
	EChessPieceColor PieceColor = EChessPieceColor::White;
};
