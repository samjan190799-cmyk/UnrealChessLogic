// Copyright (c) 2026. Все права защищены.
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "ChessBoard.h"
#include "ChessGameManager.h"

#if WITH_DEV_AUTOMATION_TESTS

/**
 * Набор автоматических тестов для валидации шахматной логики FIDE в Unreal Engine 5.
 */
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FChessLogicInitialMovesTest, "ChessLogic.UnitTests.InitialMoves", EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::SmokeFilter)

bool FChessLogicInitialMovesTest::RunTest(const FString& Parameters)
{
	FChessBoard Board;
	TArray<FChessMove> Moves;
	Board.GenerateLegalMoves(EChessColor::White, Moves);

	// В стартовой позиции у белых ровно 20 легальных ходов (16 ходов пешками + 4 хода конями)
	TestEqual(TEXT("Количество легальных ходов в начале партии должно быть 20"), Moves.Num(), 20);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FChessLogicFoolsMateTest, "ChessLogic.UnitTests.FoolsMate", EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::ProductFilter)

bool FChessLogicFoolsMateTest::RunTest(const FString& Parameters)
{
	// Мат дурака (быстрейший мат за 2 хода)
	// 1. f2-f3 e7-e5
	// 2. g2-g4 Qh4# (Мат)
	FChessBoard Board;
	FChessMove ExecutedMove;

	// 1. f3
	TestTrue(TEXT("Ход f2-f3 успешен"), Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("f2"), FChessCoordinate::FromAlgebraic("f3"), FChessPiece()), ExecutedMove));
	// 1... e5
	TestTrue(TEXT("Ход e7-e5 успешен"), Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("e7"), FChessCoordinate::FromAlgebraic("e5"), FChessPiece()), ExecutedMove));
	// 2. g4
	TestTrue(TEXT("Ход g2-g4 успешен"), Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("g2"), FChessCoordinate::FromAlgebraic("g4"), FChessPiece()), ExecutedMove));
	// 2... Qh4#
	TestTrue(TEXT("Ход d8-h4 успешен"), Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("d8"), FChessCoordinate::FromAlgebraic("h4"), FChessPiece()), ExecutedMove));

	TestTrue(TEXT("Ход Qh4 должен ставить шах"), ExecutedMove.bIsCheck);
	TestTrue(TEXT("Ход Qh4 должен ставить мат"), ExecutedMove.bIsCheckmate);
	TestEqual(TEXT("Состояние игры должно быть Checkmate"), Board.EvaluateGameState(EChessColor::White), EChessGameState::Checkmate);

	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FChessLogicCastlingTest, "ChessLogic.UnitTests.Castling", EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::ProductFilter)

bool FChessLogicCastlingTest::RunTest(const FString& Parameters)
{
	// Позиция: у белых открыты пути для короткой и длинной рокировки
	// FEN: r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1
	FChessBoard Board;
	TestTrue(TEXT("Загрузка FEN позиции рокировки"), Board.LoadFromFEN(TEXT("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")));

	TArray<FChessMove> Moves;
	Board.GetLegalMovesForPiece(FChessCoordinate::FromAlgebraic("e1"), Moves);

	bool bHasKingside = false;
	bool bHasQueenside = false;

	for (const FChessMove& Move : Moves)
	{
		if (Move.SpecialType == ESpecialMoveType::CastlingKingside && Move.To == FChessCoordinate::FromAlgebraic("g1"))
		{
			bHasKingside = true;
		}
		if (Move.SpecialType == ESpecialMoveType::CastlingQueenside && Move.To == FChessCoordinate::FromAlgebraic("c1"))
		{
			bHasQueenside = true;
		}
	}

	TestTrue(TEXT("Белые могут совершить короткую рокировку (O-O)"), bHasKingside);
	TestTrue(TEXT("Белые могут совершить длинную рокировку (O-O-O)"), bHasQueenside);

	// Выполняем короткую рокировку
	FChessMove Executed;
	TestTrue(TEXT("Исполнение короткой рокировки"), Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("e1"), FChessCoordinate::FromAlgebraic("g1"), FChessPiece()), Executed));

	TestEqual(TEXT("Король на g1"), Board.GetPiece(FChessCoordinate::FromAlgebraic("g1")).Type, EChessPieceType::King);
	TestEqual(TEXT("Ладья переместилась на f1"), Board.GetPiece(FChessCoordinate::FromAlgebraic("f1")).Type, EChessPieceType::Rook);
	TestTrue(TEXT("Поле h1 пустое"), Board.GetPiece(FChessCoordinate::FromAlgebraic("h1")).IsEmpty());

	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FChessLogicEnPassantTest, "ChessLogic.UnitTests.EnPassant", EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::ProductFilter)

bool FChessLogicEnPassantTest::RunTest(const FString& Parameters)
{
	// 1. e4 Nf6 2. e5 d5 -> теперь белая пешка на e5 может взять d5 на проходе на d6
	FChessBoard Board;
	FChessMove Executed;

	Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("e2"), FChessCoordinate::FromAlgebraic("e4"), FChessPiece()), Executed);
	Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("g8"), FChessCoordinate::FromAlgebraic("f6"), FChessPiece()), Executed);
	Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("e4"), FChessCoordinate::FromAlgebraic("e5"), FChessPiece()), Executed);
	Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("d7"), FChessCoordinate::FromAlgebraic("d5"), FChessPiece()), Executed);

	TestEqual(TEXT("Целевое поле En Passant равно d6"), Board.GetState().EnPassantTarget.ToAlgebraic(), FString(TEXT("d6")));

	// Белые берут на проходе: e5xd6
	const bool bEpSuccess = Board.MakeMove(FChessMove(FChessCoordinate::FromAlgebraic("e5"), FChessCoordinate::FromAlgebraic("d6"), FChessPiece()), Executed);
	TestTrue(TEXT("Взятие на проходе успешно"), bEpSuccess);
	TestEqual(TEXT("Тип хода - EnPassant"), Executed.SpecialType, ESpecialMoveType::EnPassant);
	TestTrue(TEXT("Пешка соперника на d5 удалена"), Board.GetPiece(FChessCoordinate::FromAlgebraic("d5")).IsEmpty());
	TestEqual(TEXT("Белая пешка теперь на d6"), Board.GetPiece(FChessCoordinate::FromAlgebraic("d6")).Type, EChessPieceType::Pawn);

	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FChessLogicPromotionTest, "ChessLogic.UnitTests.Promotion", EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::ProductFilter)

bool FChessLogicPromotionTest::RunTest(const FString& Parameters)
{
	// Белая пешка на e7 готова к превращению на e8
	// FEN: 8/4P3/8/8/8/8/8/4K2k w - - 0 1
	FChessBoard Board;
	TestTrue(TEXT("Загрузка позиции превращения"), Board.LoadFromFEN(TEXT("8/4P3/8/8/8/8/8/4K2k w - - 0 1")));

	FChessMove Executed;
	FChessMove PromotionMove(FChessCoordinate::FromAlgebraic("e7"), FChessCoordinate::FromAlgebraic("e8"), FChessPiece(), FChessPiece(), ESpecialMoveType::Promotion, EChessPieceType::Queen);

	TestTrue(TEXT("Превращение пешки в ферзя успешно"), Board.MakeMove(PromotionMove, Executed));
	TestEqual(TEXT("Фигура на e8 - Ферзь"), Board.GetPiece(FChessCoordinate::FromAlgebraic("e8")).Type, EChessPieceType::Queen);
	TestEqual(TEXT("Цвет нового ферзя - Белый"), Board.GetPiece(FChessCoordinate::FromAlgebraic("e8")).Color, EChessColor::White);

	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FChessLogicStalemateTest, "ChessLogic.UnitTests.Stalemate", EAutomationTestFlags::ApplicationContextMask | EAutomationTestFlags::ProductFilter)

bool FChessLogicStalemateTest::RunTest(const FString& Parameters)
{
	// Классическая позиция пата: черный король на a8, белые ферзь на c7 и король на a6, ход черных
	// FEN: k7/2Q5/K7/8/8/8/8/8 b - - 0 1
	FChessBoard Board;
	TestTrue(TEXT("Загрузка позиции пата"), Board.LoadFromFEN(TEXT("k7/2Q5/K7/8/8/8/8/8 b - - 0 1")));

	TestFalse(TEXT("Черный король НЕ под шахом"), Board.IsInCheck(EChessColor::Black));

	TArray<FChessMove> BlackMoves;
	Board.GenerateLegalMoves(EChessColor::Black, BlackMoves);
	TestEqual(TEXT("У черных нет легальных ходов"), BlackMoves.Num(), 0);

	TestEqual(TEXT("Состояние партии - Пат (Stalemate)"), Board.EvaluateGameState(EChessColor::Black), EChessGameState::Stalemate);

	return true;
}

#endif // WITH_DEV_AUTOMATION_TESTS
