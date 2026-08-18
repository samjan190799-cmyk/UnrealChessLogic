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
 * Заменяет стандартный меш в момент взятия, симулирует физический раскол на обломки,
 * спавнит партиклы пыли и автоматически переводит физику в спящий режим для экономии ресурсов iOS.
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
	 */
	UFUNCTION(BlueprintCallable, Category = "Chess|Physics")
	void TriggerFracture(const FVector& HitDirection, float ImpulseMultiplier = 1.0f);

	// ----------------------------------------------------------------------
	// КОМПОНЕНТЫ И ПАРАМЕТРЫ ФИЗИКИ
	// ----------------------------------------------------------------------

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	USceneComponent* SceneRoot;

	/** Компонент разрушения Chaos Physics */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UGeometryCollectionComponent* GeometryCollectionComponent;

	/** Niagara система для частиц пыли и мелких осколков */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|VFX")
	UNiagaraSystem* ImpactDustVFX = nullptr;

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
};
