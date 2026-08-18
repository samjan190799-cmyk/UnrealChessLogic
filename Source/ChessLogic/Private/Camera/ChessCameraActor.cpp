// Copyright (c) 2026. Все права защищены.
#include "Camera/ChessCameraActor.h"
#include "Camera/ChessCameraShake.h"
#include "GameFramework/SpringArmComponent.h"
#include "Camera/CameraComponent.h"
#include "Components/SceneComponent.h"
#include "Kismet/GameplayStatics.h"

AChessCameraActor::AChessCameraActor()
{
	PrimaryActorTick.bCanEverTick = true;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

	SpringArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("SpringArm"));
	SpringArm->SetupAttachment(RootComponent);
	SpringArm->bDoCollisionTest = false;
	SpringArm->bEnableCameraLag = true;
	SpringArm->CameraLagSpeed = 6.0f;
	SpringArm->TargetArmLength = DefaultArmLength;
	SpringArm->SetRelativeRotation(FRotator(DefaultCameraPitch, 0.0f, 0.0f));

	CameraComponent = CreateDefaultSubobject<UCameraComponent>(TEXT("CameraComponent"));
	CameraComponent->SetupAttachment(SpringArm, USpringArmComponent::SocketName);
	CameraComponent->FieldOfView = 55.0f;

	ImpactCameraShakeClass = UChessImpactCameraShake::StaticClass();
}

void AChessCameraActor::BeginPlay()
{
	Super::BeginPlay();

	DefaultFocusLocation = GetActorLocation();
	TargetFocusLocation = DefaultFocusLocation;
	TargetArmLength = DefaultArmLength;
	TargetRotation = FRotator(DefaultCameraPitch, 0.0f, 0.0f);
}

void AChessCameraActor::ResetToOverview(float InInterpSpeed)
{
	TargetFocusLocation = DefaultFocusLocation;
	TargetArmLength = DefaultArmLength;
	bIsTemporaryEffectActive = false;
	TemporaryEffectTimer = 0.0f;
}

void AChessCameraActor::TriggerAttackPunch(const FVector& AttackWorldLocation, float PunchZoomLength, float Duration)
{
	TargetFocusLocation = FMath::Lerp(DefaultFocusLocation, AttackWorldLocation, 0.4f);
	TargetArmLength = PunchZoomLength;

	TemporaryEffectTimer = FMath::Max(0.2f, Duration);
	bIsTemporaryEffectActive = true;
}

void AChessCameraActor::TriggerCheckFocus(const FVector& KingWorldLocation, float ZoomLength, float Duration)
{
	TargetFocusLocation = FMath::Lerp(DefaultFocusLocation, KingWorldLocation, 0.6f);
	TargetArmLength = ZoomLength;

	TemporaryEffectTimer = FMath::Max(0.3f, Duration);
	bIsTemporaryEffectActive = true;
}

void AChessCameraActor::PlayImpactShake(float Scale)
{
	if (ImpactCameraShakeClass && GetWorld())
	{
		APlayerController* PC = UGameplayStatics::GetPlayerController(GetWorld(), 0);
		if (PC && PC->PlayerCameraManager)
		{
			PC->PlayerCameraManager->StartCameraShake(ImpactCameraShakeClass, Scale);
		}
	}
}

void AChessCameraActor::SetTurnPerspective(EChessColor ActiveColor, float InInterpSpeed)
{
	const float TargetYaw = (ActiveColor == EChessColor::Black) ? 180.0f : 0.0f;
	TargetRotation = FRotator(DefaultCameraPitch, TargetYaw, 0.0f);
}

void AChessCameraActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

	if (bIsTemporaryEffectActive)
	{
		TemporaryEffectTimer -= DeltaTime;
		if (TemporaryEffectTimer <= 0.0f)
		{
			ResetToOverview();
		}
	}

	const FVector NewLocation = FMath::VInterpTo(GetActorLocation(), TargetFocusLocation, DeltaTime, SmoothInterpSpeed);
	SetActorLocation(NewLocation);

	SpringArm->TargetArmLength = FMath::FInterpTo(SpringArm->TargetArmLength, TargetArmLength, DeltaTime, SmoothInterpSpeed);

	const FRotator NewRotation = FMath::RInterpTo(SpringArm->GetRelativeRotation(), TargetRotation, DeltaTime, SmoothInterpSpeed);
	SpringArm->SetRelativeRotation(NewRotation);
}
