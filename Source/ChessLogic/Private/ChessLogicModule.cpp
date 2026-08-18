// Copyright (c) 2026. Все права защищены.
#include "Modules/ModuleManager.h"

class FChessLogicModule : public IModuleInterface
{
public:
	virtual void StartupModule() override
	{
		// Инициализация модуля шахматной логики
	}

	virtual void ShutdownModule() override
	{
		// Очистка при выгрузке модуля
	}
};

IMPLEMENT_MODULE(FChessLogicModule, ChessLogic)
