// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "ChessTypes.h"
#include "ChessBoard.generated.h"

/**
 * Класс шахматной доски 8x8 и низкоуровневой логики валидации правил FIDE.
 * Оптимизирован для мобильных устройств (минимизация аллокаций, плоский массив, inline-буферы).
 */
USTRUCT(BlueprintType)
struct CHESSLOGIC_API FChessBoardState
{
	GENERATED_BODY()

	/** Массив клеток доски: 64 элемента (строки 0..7 снизу вверх, колонки 0..7 слева направо) */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	TArray<FChessPiece> Grid;

	/** Кэшированные координаты королей для O(1) проверки шаха */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	FChessCoordinate WhiteKingPos;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	FChessCoordinate BlackKingPos;

	/** Поле для взятия на проходе (если на прошлом ходу пешка совершила прыжок через клетку) */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	FChessCoordinate EnPassantTarget;

	/** Права на рокировку */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	bool bWhiteCanCastleKingside = true;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	bool bWhiteCanCastleQueenside = true;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	bool bBlackCanCastleKingside = true;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	bool bBlackCanCastleQueenside = true;

	/** Чей сейчас ход */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	EChessColor ActiveColor = EChessColor::White;

	/** Счетчик полуходов для правила 50 ходов */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	int32 HalfmoveClock = 0;

	/** Номер полного хода */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Board")
	int32 FullmoveNumber = 1;

	FChessBoardState();
};

/**
 * Основной класс движка шахматной логики.
 */
class CHESSLOGIC_API FChessBoard
{
public:
	FChessBoard();
	~FChessBoard() = default;

	/** Сброс доски в стандартную начальную позицию FIDE */
	void ResetToStartingPosition();

	/** Полная очистка доски */
	void Clear();

	/** Загрузка позиции из нотации FEN (Forsyth-Edwards Notation) */
	bool LoadFromFEN(const FString& FEN);

	/** Экспорт текущей позиции в строку FEN */
	FString ExportToFEN() const;

	/** Получение фигуры на заданной клетке */
	FORCEINLINE FChessPiece GetPiece(const FChessCoordinate& Coord) const
	{
		if (!Coord.IsValid())
		{
			return FChessPiece();
		}
		return State.Grid[Coord.ToFlatIndex()];
	}

	/** Установка фигуры на клетку */
	void SetPiece(const FChessCoordinate& Coord, const FChessPiece& Piece);

	/** Получение текущего состояния доски */
	FORCEINLINE const FChessBoardState& GetState() const { return State; }

	/** Чей сейчас ход */
	FORCEINLINE EChessColor GetActiveColor() const { return State.ActiveColor; }

	/** Смена активного цвета */
	void SetActiveColor(EChessColor NewColor) { State.ActiveColor = NewColor; }

	/** Проверка, атакована ли клетка фигурами указанного цвета */
	bool IsSquareAttacked(const FChessCoordinate& Coord, EChessColor AttackingColor) const;

	/** Находится ли король указанного цвета под шахом */
	bool IsInCheck(EChessColor KingColor) const;

	/** Генерация всех строго легальных ходов для стороны указанного цвета */
	void GenerateLegalMoves(EChessColor Color, TArray<FChessMove>& OutMoves) const;

	/** Генерация всех легальных ходов для конкретной фигуры на клетке */
	void GetLegalMovesForPiece(const FChessCoordinate& Coord, TArray<FChessMove>& OutMoves) const;

	/** Проверка легальности хода */
	bool IsMoveLegal(const FChessMove& Move) const;

	/**
	 * Совершение хода на доске.
	 * @param Move Ход для выполнения
	 * @param OutExecutedMove Возвращает ход со всеми дополненными данными (взятия, шах, мат)
	 * @return true, если ход был успешно и легально применен
	 */
	bool MakeMove(const FChessMove& Move, FChessMove& OutExecutedMove);

	/** Отмена последнего совершенного хода */
	bool UndoLastMove();

	/** Оценка текущего состояния партии (Шах, Мат, Пат, Ничья, Активна) */
	EChessGameState EvaluateGameState(EChessColor Color) const;

	/** История ходов партии */
	FORCEINLINE const TArray<FChessMove>& GetMoveHistory() const { return MoveHistory; }

private:
	FChessBoardState State;

	/** Стек истории состояний доски для быстрого и безопасного отката (Undo / Симуляция ходов) */
	TArray<FChessBoardState> StateHistory;
	TArray<FChessMove> MoveHistory;

	// Внутренние методы генерации псевдолегальных ходов
	void GeneratePseudoLegalMoves(EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GeneratePawnMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GenerateKnightMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GenerateBishopMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GenerateRookMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GenerateQueenMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GenerateKingMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;
	void GenerateCastlingMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const;

	void AddRayMoves(const FChessCoordinate& From, EChessColor Color, int32 DeltaCol, int32 DeltaRow, TArray<FChessMove>& OutMoves) const;

	/** Внутреннее применение хода без глубокой валидации (для симуляции шахов) */
	void ApplyMoveInternal(const FChessMove& Move);
};
