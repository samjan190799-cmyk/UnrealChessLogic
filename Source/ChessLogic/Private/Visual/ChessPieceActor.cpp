// Copyright (c) 2026. Все права защищены.
#include "Visual/ChessPieceActor.h"
#include "Components/StaticMeshComponent.h"
#include "Components/SceneComponent.h"
#include "Materials/MaterialInstanceDynamic.h"

AChessPieceActor::AChessPieceActor()
{
	PrimaryActorTick.bCanEverTick = true;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

	MeshComponent = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("MeshComponent"));
	MeshComponent->SetupAttachment(RootComponent);
	MeshComponent->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	MeshComponent->SetCollisionResponseToAllChannels(ECR_Block);
	MeshComponent->SetCollisionObjectType(ECC_WorldDynamic);
	MeshComponent->SetGenerateOverlapEvents(false);
	MeshComponent->CastShadow = true;
}

void AChessPieceActor::BeginPlay()
{
	Super::BeginPlay();

	// Создаем динамический инстанс материала для подсветки
	if (MeshComponent && MeshComponent->GetMaterial(0))
	{
		DynamicMaterial = MeshComponent->CreateAndSetMaterialInstanceDynamic(0);
	}
}

void AChessPieceActor::InitializePiece(EChessPieceType InType, EChessColor InColor, const FChessCoordinate& InCoord)
{
	PieceType = InType;
	PieceColor = InColor;
	BoardCoordinate = InCoord;

	// Ориентируем черные фигуры навстречу белым
	if (PieceColor == EChessColor::Black)
	{
		SetActorRotation(FRotator(0.0f, 180.0f, 0.0f));
	}
	else
	{
		SetActorRotation(FRotator(0.0f, 0.0f, 0.0f));
	}
}

void AChessPieceActor::AnimateMoveTo(const FVector& TargetLocation, float InDuration, float InArcHeight)
{
	StartMoveLocation = GetActorLocation();
	TargetMoveLocation = TargetLocation;
	MoveDuration = FMath::Max(0.05f, InDuration);
	ArcHeight = InArcHeight;
	MoveElapsedTime = 0.0f;
	bIsMoving = true;
}

void AChessPieceActor::PlayCaptureAnimation(float InDuration)
{
	bIsMoving = false;
	bIsCapturing = true;
	CaptureDuration = FMath::Max(0.1f, InDuration);
	CaptureElapsedTime = 0.0f;
	StartCaptureScale = GetActorScale3D();
	StartCaptureRotation = GetActorRotation();

	// Отключаем коллизию во время анимации взятия
	MeshComponent->SetCollisionEnabled(ECollisionEnabled::NoCollision);
}

void AChessPieceActor::SetHighlightState(bool bIsSelected)
{
	if (DynamicMaterial)
	{
		// Передаем параметр свечения в шейдер материала фигуры
		DynamicMaterial->SetScalarParameterValue(TEXT("EmissiveIntensity"), bIsSelected ? 2.5f : 0.0f);
		DynamicMaterial->SetVectorParameterValue(TEXT("EmissiveColor"), bIsSelected ? FLinearColor(0.2f, 0.7f, 1.0f) : FLinearColor::Black);
	}
}

void AChessPieceActor::UpdatePieceMesh(EChessPieceType NewType)
{
	PieceType = NewType;
	// При необходимости в Blueprints можно назначить соответствующий StaticMesh через интерфейс или ассет-менеджер
}

void AChessPieceActor::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);

	// 1. Анимация перемещения по плавной параболической дуге с EaseInOut
	if (bIsMoving)
	{
		MoveElapsedTime += DeltaTime;
		const float Alpha = FMath::Clamp(MoveElapsedTime / MoveDuration, 0.0f, 1.0f);

		// Кубическая интерполяция с плавным разгоном и торможением (EaseInOut)
		const float EaseAlpha = FMath::InterpEaseInOut(0.0f, 1.0f, Alpha, 2.0f);

		// Параболический подъем по высоте Z: h(t) = 4 * H * t * (1 - t)
		const float ParabolicZ = 4.0f * ArcHeight * Alpha * (1.0f - Alpha);

		FVector CurrentPos = FMath::Lerp(StartMoveLocation, TargetMoveLocation, EaseAlpha);
		CurrentPos.Z += ParabolicZ;

		SetActorLocation(CurrentPos);

		if (Alpha >= 1.0f)
		{
			SetActorLocation(TargetMoveLocation);
			bIsMoving = false;
		}
	}

	// 2. Анимация взятия фигуры: закручивание, уменьшение масштаба и уничтожение
	if (bIsCapturing)
	{
		CaptureElapsedTime += DeltaTime;
		const float Alpha = FMath::Clamp(CaptureElapsedTime / CaptureDuration, 0.0f, 1.0f);
		const float EaseAlpha = FMath::InterpEaseIn(0.0f, 1.0f, Alpha, 2.0f);

		// Уменьшение масштаба до нуля
		const FVector NewScale = FMath::Lerp(StartCaptureScale, FVector::ZeroVector, EaseAlpha);
		SetActorScale3D(NewScale);

		// Вращение при падении
		AddActorLocalRotation(FRotator(180.0f * DeltaTime, 360.0f * DeltaTime, 90.0f * DeltaTime));

		// Небольшое смещение вверх и в сторону
		AddActorWorldOffset(FVector(0.0f, 0.0f, 40.0f * DeltaTime));

		if (Alpha >= 1.0f)
		{
			bIsCapturing = false;
			Destroy();
		}
	}
}
