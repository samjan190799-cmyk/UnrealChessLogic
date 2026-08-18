// Copyright (c) 2026. Все права защищены.
#include "Camera/ChessCameraShake.h"

UChessImpactCameraShake::UChessImpactCameraShake()
{
	OscillationDuration = 0.25f;
	OscillationBlendInTime = 0.02f;
	OscillationBlendOutTime = 0.18f;

	// Вращательные микро-колебания камеры (Pitch, Yaw, Roll)
	RotOscillation.Pitch.Amplitude = 1.2f;
	RotOscillation.Pitch.Frequency = 45.0f;
	RotOscillation.Pitch.InitialOffset = EInitialOscillatorOffset::EOO_OffsetRandom;

	RotOscillation.Yaw.Amplitude = 0.8f;
	RotOscillation.Yaw.Frequency = 35.0f;
	RotOscillation.Yaw.InitialOffset = EInitialOscillatorOffset::EOO_OffsetRandom;

	RotOscillation.Roll.Amplitude = 1.0f;
	RotOscillation.Roll.Frequency = 40.0f;
	RotOscillation.Roll.InitialOffset = EInitialOscillatorOffset::EOO_OffsetRandom;

	// Смещение камеры по вертикали (Z-ось) для ощущения массивного удара
	LocOscillation.Z.Amplitude = 4.0f;
	LocOscillation.Z.Frequency = 50.0f;
	LocOscillation.Z.InitialOffset = EInitialOscillatorOffset::EOO_OffsetZero;
}
