// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "UObject/NoExportTypes.h"
#include "ChessTypes.h"
#include "ChessDelegates.h"
#include "ChessBoard.h"
#include "ChessGameManager.generated.h"

/**
 * Высокоуровневый игровой менеджер шахматной партии для Unreal Engine 5.
 * Предоставляет API для Blueprints, связывает математику доски с графическим UI и 3D-сценой
 * через систему Unreal Delegates.
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API UChessGameManager : public UObject
{
	GENERATED_BODY()

public:
	UChessGameManager();

	// ----------------------------------------------------------------------
	// ДЕЛЕГАТЫ (События для привязки в Blueprints и UI / UMG / C++)
	// ----------------------------------------------------------------------

	/** Вызывается после успешного выполнения хода на доске */
	UPROPERTY(BlueprintAssignable, Category = "Chess|Events")
	FOnChessMoveExecuted OnMoveExecuted;

	/** Вызывается, когда фигура взята */
	UPROPERTY(BlueprintAssignable, Category = "Chess|Events")
	FOnChessPieceCaptured OnPieceCaptured;

	/** Вызывается при изменении общего состояния игры (Шах, Мат, Пат, Ничья, Активна) */
	UPROPERTY(BlueprintAssignable, Category = "Chess|Events")
	FOnChessGameStateChanged OnGameStateChanged;

	/** Вызывается при объявлении шаха королю */
	UPROPERTY(BlueprintAssignable, Category = "Chess|Events")
	FOnChessCheckStatus OnCheckStatus;

	/** Вызывается, когда пешка дошла до конца и требует выбора превращения */
	UPROPERTY(BlueprintAssignable, Category = "Chess|Events")
	FOnPawnPromotionRequired OnPawnPromotionRequired;

	/** Вызывается при сбросе или новой загрузке доски */
	UPROPERTY(BlueprintAssignable, Category = "Chess|Events")
	FOnChessBoardReset OnBoardReset;

	// ----------------------------------------------------------------------
	// ОСНОВНОЙ ИГРОВОЙ API
	// ----------------------------------------------------------------------

	/** Начать новую стандартную шахматную партию */
	UFUNCTION(BlueprintCallable, Category = "Chess|Game")
	void StartNewGame();

	/** Загрузить партию из строки FEN */
	UFUNCTION(BlueprintCallable, Category = "Chess|Game")
	bool LoadGameFromFEN(const FString& FEN);

	/** Получить текущую позицию в формате FEN */
	UFUNCTION(BlueprintPure, Category = "Chess|Game")
	FString GetCurrentFEN() const;

	/**
	 * Попытка совершить ход на доске.
	 * @param From Координата начальной клетки
	 * @param To Координата целевой клетки
	 * @param PromotionChoice Тип фигуры в случае превращения пешки (по умолчанию Queen)
	 * @return true, если ход валиден и успешно применен
	 */
	UFUNCTION(BlueprintCallable, Category = "Chess|Game")
	bool TryMakeMove(const FChessCoordinate& From, const FChessCoordinate& To, EChessPieceType PromotionChoice = EChessPieceType::Queen);

	/** Попытка совершить ход через алгебраическую запись клеток (например, "e2", "e4") */
	UFUNCTION(BlueprintCallable, Category = "Chess|Game")
	bool TryMakeMoveAlgebraic(const FString& FromSquare, const FString& ToSquare, EChessPieceType PromotionChoice = EChessPieceType::Queen);

	/** Отмена последнего совершенного хода */
	UFUNCTION(BlueprintCallable, Category = "Chess|Game")
	bool UndoLastMove();

	// ----------------------------------------------------------------------
	// ГЕТТЕРЫ И СЕРВИСНЫЕ МЕТОДЫ ДЛЯ ПОДСВЕТКИ UI И ВАЛИДАЦИИ
	// ----------------------------------------------------------------------

	/** Получение фигуры на указанной клетке */
	UFUNCTION(BlueprintPure, Category = "Chess|Board")
	FChessPiece GetPieceAt(const FChessCoordinate& Coord) const;

	/** Получение фигуры по строковому имени клетки (например, "e4") */
	UFUNCTION(BlueprintPure, Category = "Chess|Board")
	FChessPiece GetPieceAtAlgebraic(const FString& Square) const;

	/** Получение всех легальных ходов для выбранной фигуры (для подсветки клеток в UI) */
	UFUNCTION(BlueprintCallable, Category = "Chess|Board")
	TArray<FChessMove> GetLegalMovesForPiece(const FChessCoordinate& Coord) const;

	/** Получение всех доступных легальных ходов для текущего игрока */
	UFUNCTION(BlueprintCallable, Category = "Chess|Board")
	TArray<FChessMove> GetAllCurrentLegalMoves() const;

	/** Текущая очередь хода (Белые / Черные) */
	UFUNCTION(BlueprintPure, Category = "Chess|State")
	EChessColor GetCurrentTurn() const;

	/** Текущее состояние партии */
	UFUNCTION(BlueprintPure, Category = "Chess|State")
	EChessGameState GetCurrentGameState() const;

	/** Находится ли король указанного цвета под шахом */
	UFUNCTION(BlueprintPure, Category = "Chess|State")
	bool IsKingInCheck(EChessColor Color) const;

	/** Координаты короля указанного цвета */
	UFUNCTION(BlueprintPure, Category = "Chess|State")
	FChessCoordinate GetKingCoordinate(EChessColor Color) const;

	/** Получить историю ходов */
	UFUNCTION(BlueprintPure, Category = "Chess|History")
	TArray<FChessMove> GetMoveHistory() const;

private:
	FChessBoard Board;
	EChessGameState CurrentGameState = EChessGameState::Active;

	/** Обновление состояния игры и оповещение подписчиков делегатов */
	void UpdateGameStateAndBroadcast();
};
