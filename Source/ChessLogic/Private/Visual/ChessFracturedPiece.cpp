// Copyright (c) 2026. Все права защищены.
#include "Visual/ChessFracturedPiece.h"
#include "GeometryCollection/GeometryCollectionComponent.h"
#include "Components/SceneComponent.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraComponent.h"

AChessFracturedPiece::AChessFracturedPiece()
{
	PrimaryActorTick.bCanEverTick = true;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

	GeometryCollectionComponent = CreateDefaultSubobject<UGeometryCollectionComponent>(TEXT("GeometryCollectionComponent"));
	GeometryCollectionComponent->SetupAttachment(RootComponent);
	GeometryCollectionComponent->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	GeometryCollectionComponent->SetCollisionObjectType(ECC_Destructible);
	GeometryCollectionComponent->SetCollisionResponseToAllChannels(ECR_Block);
	GeometryCollectionComponent->SetGenerateOverlapEvents(false);
	GeometryCollectionComponent->SetSimulatePhysics(true);
	GeometryCollectionComponent->SetNotifyBreaks(true);
	GeometryCollectionComponent->CastShadow = true;
}

void AChessFracturedPiece::BeginPlay()
{
	Super::BeginPlay();
	InitialScale = GetActorScale3D();
}

void AChessFracturedPiece::TriggerFracture(const FVector& HitDirection, float ImpulseMultiplier)
{
	if (!GeometryCollectionComponent)
	{
		return;
	}

	// Формируем вектор импульса с небольшим подбросом вверх для эффектного разлета
	const FVector ImpactDir = (HitDirection.GetSafeNormal() + FVector(0.0f, 0.0f, 0.35f)).GetSafeNormal();
	const float FinalImpulse = BaseImpulseStrength * FMath::Max(0.5f, ImpulseMultiplier);

	GeometryCollectionComponent->SetSimulatePhysics(true);

	// Прикладываем радиальный взрывной импульс и направленный толчок
	GeometryCollectionComponent->AddRadialImpulse(
		GetActorLocation(),
		150.0f,
		FinalImpulse,
		ERadialImpulseFalloff::RIF_Linear,
		true
	);

	GeometryCollectionComponent->AddImpulse(ImpactDir * (FinalImpulse * 0.5f));

	// Спавн частиц каменной пыли и осколков Niagara
	if (ImpactDustVFX && GetWorld())
	{
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(
			GetWorld(),
			ImpactDustVFX,
			GetActorLocation() + FVector(0.0f, 0.0f, 15.0f),
			ImpactDir.Rotation()
		);
	}
}

void AChessFracturedPiece::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

	ElapsedLifeTime += DeltaTime;

	// 1. Перевод физики в спящий режим для оптимизации производительности на iOS
	if (ElapsedLifeTime >= SleepDelay && !bPhysicsAsleep)
	{
		bPhysicsAsleep = true;
		if (GeometryCollectionComponent)
		{
			GeometryCollectionComponent->SetSimulatePhysics(false);
			GeometryCollectionComponent->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		}
	}

	// 2. Плавное исчезновение (Fade-out) и уменьшение масштаба осколков
	if (ElapsedLifeTime >= SleepDelay)
	{
		const float FadeDuration = FMath::Max(0.1f, TotalLifeSpan - SleepDelay);
		const float FadeAlpha = FMath::Clamp((ElapsedLifeTime - SleepDelay) / FadeDuration, 0.0f, 1.0f);
		const float EaseAlpha = FMath::InterpEaseIn(0.0f, 1.0f, FadeAlpha, 2.0f);

		SetActorScale3D(FMath::Lerp(InitialScale, FVector::ZeroVector, EaseAlpha));
	}

	// 3. Полная очистка актера со сцены
	if (ElapsedLifeTime >= TotalLifeSpan)
	{
		Destroy();
	}
}
