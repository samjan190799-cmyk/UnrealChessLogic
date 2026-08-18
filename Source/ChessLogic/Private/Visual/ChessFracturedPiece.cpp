// Copyright (c) 2026. Все права защищены.

#include "Visual/ChessFracturedPiece.h"
#include "GeometryCollection/GeometryCollectionComponent.h"
#include "NiagaraFunctionLibrary.h"
#include "NiagaraComponent.h"

AChessFracturedPiece::AChessFracturedPiece()
{
	PrimaryActorTick.bCanEverTick = true;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

	GeometryCollectionComponent = CreateDefaultSubobject<UGeometryCollectionComponent>(TEXT("GeometryCollectionComponent"));
	GeometryCollectionComponent->SetupAttachment(RootComponent);
	GeometryCollectionComponent->SetSimulatePhysics(true);
	GeometryCollectionComponent->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	GeometryCollectionComponent->SetNotifyRigidBodyCollision(true);
}

void AChessFracturedPiece::BeginPlay()
{
	Super::BeginPlay();
	InitialScale = GetActorScale3D();
}

void AChessFracturedPiece::TriggerFracture(const FVector& HitDirection, float ImpulseMultiplier, EChessPieceColor InPieceColor)
{
	PieceColor = InPieceColor;
	if (GeometryCollectionComponent)
	{
		GeometryCollectionComponent->SetSimulatePhysics(true);

		const FVector NormalizedHit = HitDirection.GetSafeNormal();
		const FVector ImpulseVector = (NormalizedHit * 0.75f + FVector::UpVector * 0.45f) * (BaseImpulseStrength * ImpulseMultiplier);

		GeometryCollectionComponent->AddRadialImpulse(
			GetActorLocation(),
			150.0f,
			BaseImpulseStrength * ImpulseMultiplier * 0.6f,
			ERadialImpulseFalloff::RIF_Linear,
			true
		);

		GeometryCollectionComponent->AddImpulse(ImpulseVector, NAME_None, true);
	}

	// Выбор Niagara VFX по визуальному эталону:
	// 1. Белые: Древние кости, золотая пыль и искры
	// 2. Черные: Раскаленный лавовый обсидиан, огонь и дым
	UNiagaraSystem* TargetVFX = (PieceColor == EChessPieceColor::White) ? WhiteBoneGoldVFX : BlackMagmaObsidianVFX;
	if (TargetVFX)
	{
		UNiagaraFunctionLibrary::SpawnSystemAtLocation(
			GetWorld(),
			TargetVFX,
			GetActorLocation(),
			GetActorRotation(),
			FVector(1.2f),
			true,
			true,
			ENCPoolMethod::AutoRelease
		);
	}
}

void AChessFracturedPiece::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

	ElapsedLifeTime += DeltaTime;

	// 1. Засыпание физики (Sleep) через 1.8с для экономии аккумулятора и CPU на iOS
	if (!bPhysicsAsleep && ElapsedLifeTime >= SleepDelay)
	{
		bPhysicsAsleep = true;
		if (GeometryCollectionComponent)
		{
			GeometryCollectionComponent->SetSimulatePhysics(false);
		}
	}

	// 2. Плавное затухание (Fade-out scale) перед уничтожением
	if (ElapsedLifeTime >= (TotalLifeSpan - 0.7f))
	{
		const float RemainingRatio = FMath::Clamp((TotalLifeSpan - ElapsedLifeTime) / 0.7f, 0.0f, 1.0f);
		SetActorScale3D(InitialScale * RemainingRatio);
	}

	// 3. Полная сборка мусора (Garbage Collection)
	if (ElapsedLifeTime >= TotalLifeSpan)
	{
		Destroy();
	}
}
