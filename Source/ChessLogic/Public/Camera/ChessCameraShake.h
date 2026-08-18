// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "LegacyCameraShake.h"
#include "ChessCameraShake.generated.h"

/**
 * Кастомный шейк камеры для Unreal Engine 5 при кинематографичном ударе и разрушении фигур.
 * Реализует быстрый импульс (Fast Attack) и плавное экспоненциальное затухание.
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API UChessImpactCameraShake : public ULegacyCameraShake
{
	GENERATED_BODY()

public:
	UChessImpactCameraShake();
};
