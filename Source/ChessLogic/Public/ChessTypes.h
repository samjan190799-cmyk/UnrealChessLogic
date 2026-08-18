// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "ChessTypes.generated.h"

/**
 * Цвет шахматной фигуры / стороны.
 */
UENUM(BlueprintType)
enum class EChessColor : uint8
{
	None    UMETA(DisplayName = "None"),
	White   UMETA(DisplayName = "White"),
	Black   UMETA(DisplayName = "Black")
};

/**
 * Тип шахматной фигуры.
 */
UENUM(BlueprintType)
enum class EChessPieceType : uint8
{
	None    UMETA(DisplayName = "None"),
	Pawn    UMETA(DisplayName = "Pawn"),
	Knight  UMETA(DisplayName = "Knight"),
	Bishop  UMETA(DisplayName = "Bishop"),
	Rook    UMETA(DisplayName = "Rook"),
	Queen   UMETA(DisplayName = "Queen"),
	King    UMETA(DisplayName = "King")
};

/**
 * Текущее состояние шахматной партии.
 */
UENUM(BlueprintType)
enum class EChessGameState : uint8
{
	Active      UMETA(DisplayName = "Active"),
	Check       UMETA(DisplayName = "Check"),
	Checkmate   UMETA(DisplayName = "Checkmate"),
	Stalemate   UMETA(DisplayName = "Stalemate"),
	Draw        UMETA(DisplayName = "Draw")
};

/**
 * Тип специального хода (рокировка, взятие на проходе, превращение).
 */
UENUM(BlueprintType)
enum class ESpecialMoveType : uint8
{
	Normal              UMETA(DisplayName = "Normal"),
	CastlingKingside    UMETA(DisplayName = "Castling Kingside (O-O)"),
	CastlingQueenside   UMETA(DisplayName = "Castling Queenside (O-O-O)"),
	EnPassant           UMETA(DisplayName = "En Passant"),
	Promotion           UMETA(DisplayName = "Pawn Promotion")
};

/**
 * Координата клетки на шахматной доске (8x8).
 * Col (Колонка): 0 = 'a', 7 = 'h'.
 * Row (Горизонталь): 0 = '1', 7 = '8'.
 */
USTRUCT(BlueprintType)
struct CHESSLOGIC_API FChessCoordinate
{
	GENERATED_BODY()

	/** Колонка (вертикаль): 0 (a) .. 7 (h) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Coordinate")
	int32 Col = -1;

	/** Горизонталь: 0 (1) .. 7 (8) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Coordinate")
	int32 Row = -1;

	FChessCoordinate() : Col(-1), Row(-1) {}
	FChessCoordinate(int32 InCol, int32 InRow) : Col(InCol), Row(InRow) {}

	/** Проверка валидности координаты на доске 8x8 */
	FORCEINLINE bool IsValid() const
	{
		return Col >= 0 && Col < 8 && Row >= 0 && Row < 8;
	}

	/** Преобразование в алгебраическую нотацию (например, "e4", "a1") */
	FString ToAlgebraic() const
	{
		if (!IsValid())
		{
			return TEXT("??");
		}
		const TCHAR ColChar = static_cast<TCHAR>(TEXT('a') + Col);
		const TCHAR RowChar = static_cast<TCHAR>(TEXT('1') + Row);
		return FString::Printf(TEXT("%c%c"), ColChar, RowChar);
	}

	/** Создание координаты из алгебраической нотации (например, "e4") */
	static FChessCoordinate FromAlgebraic(const FString& InStr)
	{
		if (InStr.Len() < 2)
		{
			return FChessCoordinate(-1, -1);
		}

		const TCHAR ColChar = FChar::ToLower(InStr[0]);
		const TCHAR RowChar = InStr[1];

		const int32 OutCol = ColChar - TEXT('a');
		const int32 OutRow = RowChar - TEXT('1');

		FChessCoordinate Coord(OutCol, OutRow);
		return Coord.IsValid() ? Coord : FChessCoordinate(-1, -1);
	}

	/** Индекс в плоском массиве (0..63) для сверхбыстрого доступа к кэшу */
	FORCEINLINE int32 ToFlatIndex() const
	{
		return (Row * 8) + Col;
	}

	/** Восстановление координаты из индекса плоского массива */
	FORCEINLINE static FChessCoordinate FromFlatIndex(int32 Index)
	{
		if (Index < 0 || Index >= 64)
		{
			return FChessCoordinate(-1, -1);
		}
		return FChessCoordinate(Index % 8, Index / 8);
	}

	FORCEINLINE bool operator==(const FChessCoordinate& Other) const
	{
		return Col == Other.Col && Row == Other.Row;
	}

	FORCEINLINE bool operator!=(const FChessCoordinate& Other) const
	{
		return !(*this == Other);
	}

	friend uint32 GetTypeHash(const FChessCoordinate& Coord)
	{
		return HashCombine(GetTypeHash(Coord.Col), GetTypeHash(Coord.Row));
	}
};

/**
 * Структура шахматной фигуры.
 */
USTRUCT(BlueprintType)
struct CHESSLOGIC_API FChessPiece
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Piece")
	EChessPieceType Type = EChessPieceType::None;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Piece")
	EChessColor Color = EChessColor::None;

	/** Флаг, двигалась ли фигура ранее (критично для рокировки и первого хода пешки) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Piece")
	bool bHasMoved = false;

	FChessPiece() : Type(EChessPieceType::None), Color(EChessColor::None), bHasMoved(false) {}
	FChessPiece(EChessPieceType InType, EChessColor InColor, bool InHasMoved = false)
		: Type(InType), Color(InColor), bHasMoved(InHasMoved) {}

	FORCEINLINE bool IsEmpty() const
	{
		return Type == EChessPieceType::None || Color == EChessColor::None;
	}

	FORCEINLINE bool IsValidPiece() const
	{
		return !IsEmpty();
	}

	FORCEINLINE bool operator==(const FChessPiece& Other) const
	{
		return Type == Other.Type && Color == Other.Color && bHasMoved == Other.bHasMoved;
	}

	FORCEINLINE bool operator!=(const FChessPiece& Other) const
	{
		return !(*this == Other);
	}
};

/**
 * Полное описание совершенного или планируемого хода.
 */
USTRUCT(BlueprintType)
struct CHESSLOGIC_API FChessMove
{
	GENERATED_BODY()

	/** Исходное поле */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	FChessCoordinate From;

	/** Целевое поле */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	FChessCoordinate To;

	/** Перемещаемая фигура */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	FChessPiece PieceMoved;

	/** Взятая фигура (если было взятие) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	FChessPiece PieceCaptured;

	/** Специальный тип хода */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	ESpecialMoveType SpecialType = ESpecialMoveType::Normal;

	/** Фигура, в которую превращается пешка (если SpecialType == Promotion) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	EChessPieceType PromotedPieceType = EChessPieceType::None;

	/** Объявлен ли шах после этого хода */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	bool bIsCheck = false;

	/** Объявлен ли мат после этого хода */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Move")
	bool bIsCheckmate = false;

	FChessMove() = default;

	FChessMove(const FChessCoordinate& InFrom, const FChessCoordinate& InTo, const FChessPiece& InMoved,
	           const FChessPiece& InCaptured = FChessPiece(), ESpecialMoveType InSpecial = ESpecialMoveType::Normal,
	           EChessPieceType InPromoted = EChessPieceType::None)
		: From(InFrom), To(InTo), PieceMoved(InMoved), PieceCaptured(InCaptured),
		  SpecialType(InSpecial), PromotedPieceType(InPromoted), bIsCheck(false), bIsCheckmate(false)
	{}

	FORCEINLINE bool IsCapture() const
	{
		return PieceCaptured.IsValidPiece();
	}

	FORCEINLINE bool operator==(const FChessMove& Other) const
	{
		return From == Other.From &&
		       To == Other.To &&
		       SpecialType == Other.SpecialType &&
		       PromotedPieceType == Other.PromotedPieceType;
	}
};
