// Copyright (c) 2026. Все права защищены.
// Модуль шахматной логики, Chaos Physics и UMG UI для Unreal Engine 5 с поддержкой iOS.

using UnrealBuildTool;

public class ChessLogic : ModuleRules
{
	public ChessLogic(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
		CppStandard = CppStandardVersion.Cpp20;

		// Базовые модули Unreal Engine, физика, эффекты и UI (UMG)
		PublicDependencyModuleNames.AddRange(
			new string[]
			{
				"Core",
				"CoreUObject",
				"Engine",
				"ChaosSolverEngine",
				"GeometryCollectionEngine",
				"Niagara",
				"GameplayCameras",
				"UMG",
				"Slate",
				"SlateCore"
			}
		);

		PrivateDependencyModuleNames.AddRange(
			new string[]
			{
				"RenderCore",
				"RHI"
			}
		);

		// Оптимизации компилятора под мобильные платформы и iOS
		if (Target.Platform == UnrealTargetPlatform.IOS)
		{
			bEnableExceptions = false;
		}
	}
}
