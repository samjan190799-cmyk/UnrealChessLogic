// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ChessTypes.h"
#include "ChessCameraActor.generated.h"

class USpringArmComponent;
class UCameraComponent;
class USceneComponent;
class UCameraShakeBase;

/**
 * Кинематографичная камера шахматной партии в Unreal Engine 5.
 * Обеспечивает плавный обзор доски, адаптацию под пропорции экранов iPhone/iPad,
 * динамический кинематографичный наезд (Punch Zoom), фокусировку при шахе и микро-встряску (Camera Shake).
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API AChessCameraActor : public AActor
{
	GENERATED_BODY()

public:
	AChessCameraActor();

	virtual void Tick(float DeltaTime) override;

	/** Сброс камеры к стандартному общему обзору всей доски */
	UFUNCTION(BlueprintCallable, Category = "Chess|Camera")
	void ResetToOverview(float InInterpSpeed = 4.0f);

	/** Динамический наезд камеры при взятии фигуры или мощной атаке */
	UFUNCTION(BlueprintCallable, Category = "Chess|Camera")
	void TriggerAttackPunch(const FVector& AttackWorldLocation, float PunchZoomLength = 950.0f, float Duration = 0.6f);

	/** Фокусировка и приближение камеры на атакованном короле при объявлении шаха */
	UFUNCTION(BlueprintCallable, Category = "Chess|Camera")
	void TriggerCheckFocus(const FVector& KingWorldLocation, float ZoomLength = 850.0f, float Duration = 0.8f);

	/** Запуск микро-встряски камеры при кинематографичном ударе */
	UFUNCTION(BlueprintCallable, Category = "Chess|Camera")
	void PlayImpactShake(float Scale = 1.0f);

	/** Плавный поворот ракурса камеры для белой или черной стороны */
	UFUNCTION(BlueprintCallable, Category = "Chess|Camera")
	void SetTurnPerspective(EChessColor ActiveColor, float InInterpSpeed = 3.0f);

	// ----------------------------------------------------------------------
	// КОМПОНЕНТЫ И НАСТРОЙКИ
	// ----------------------------------------------------------------------

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	USceneComponent* SceneRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	USpringArmComponent* SpringArm;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UCameraComponent* CameraComponent;

	/** Класс встряски камеры при ударе и разрушении фигур */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Camera")
	TSubclassOf<UCameraShakeBase> ImpactCameraShakeClass;

	/** Стандартное расстояние камеры от центра доски */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Camera")
	float DefaultArmLength = 1350.0f;

	/** Угол наклона камеры (Pitch) к плоскости доски */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Camera")
	float DefaultCameraPitch = -55.0f;

	/** Скорость плавного сглаживания перемещения камеры */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Camera")
	float SmoothInterpSpeed = 5.0f;

protected:
	virtual void BeginPlay() override;

private:
	FVector DefaultFocusLocation;
	FVector TargetFocusLocation;
	float TargetArmLength;
	FRotator TargetRotation;

	float TemporaryEffectTimer = 0.0f;
	bool bIsTemporaryEffectActive = false;
};
