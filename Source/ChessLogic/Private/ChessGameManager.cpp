// Copyright (c) 2026. Все права защищены.
#include "ChessGameManager.h"

UChessGameManager::UChessGameManager()
{
	CurrentGameState = EChessGameState::Active;
	Board.ResetToStartingPosition();
}

void UChessGameManager::StartNewGame()
{
	Board.ResetToStartingPosition();
	CurrentGameState = EChessGameState::Active;

	OnBoardReset.Broadcast();
	OnGameStateChanged.Broadcast(CurrentGameState, Board.GetActiveColor());
}

bool UChessGameManager::LoadGameFromFEN(const FString& FEN)
{
	const bool bSuccess = Board.LoadFromFEN(FEN);
	if (bSuccess)
	{
		UpdateGameStateAndBroadcast();
		OnBoardReset.Broadcast();
	}
	return bSuccess;
}

FString UChessGameManager::GetCurrentFEN() const
{
	return Board.ExportToFEN();
}

bool UChessGameManager::TryMakeMove(const FChessCoordinate& From, const FChessCoordinate& To, EChessPieceType PromotionChoice)
{
	if (!From.IsValid() || !To.IsValid())
	{
		return false;
	}

	const FChessPiece Piece = Board.GetPiece(From);
	if (Piece.IsEmpty() || Piece.Color != Board.GetActiveColor())
	{
		return false;
	}

	// Проверка на необходимость превращения пешки
	const int32 PromotionRow = (Piece.Color == EChessColor::White) ? 7 : 0;
	if (Piece.Type == EChessPieceType::Pawn && To.Row == PromotionRow)
	{
		if (PromotionChoice == EChessPieceType::None)
		{
			// Если фигура превращения не выбрана, оповещаем UI о необходимости выбора
			OnPawnPromotionRequired.Broadcast(To, Piece.Color);
			return false;
		}
	}

	FChessMove InMove(From, To, Piece, Board.GetPiece(To), ESpecialMoveType::Normal, PromotionChoice);
	FChessMove ExecutedMove;

	const bool bSuccess = Board.MakeMove(InMove, ExecutedMove);
	if (bSuccess)
	{
		// 1. Оповещение о взятии фигуры
		if (ExecutedMove.IsCapture())
		{
			const FChessCoordinate CaptureSquare = (ExecutedMove.SpecialType == ESpecialMoveType::EnPassant)
				? FChessCoordinate(ExecutedMove.To.Col, ExecutedMove.From.Row)
				: ExecutedMove.To;

			OnPieceCaptured.Broadcast(ExecutedMove.PieceCaptured, CaptureSquare);
		}

		// 2. Оповещение о совершенном ходе (для анимации перемещения фигуры)
		OnMoveExecuted.Broadcast(ExecutedMove);

		// 3. Обновление состояния партии и оповещение о шахе/мате
		UpdateGameStateAndBroadcast();

		return true;
	}

	return false;
}

bool UChessGameManager::TryMakeMoveAlgebraic(const FString& FromSquare, const FString& ToSquare, EChessPieceType PromotionChoice)
{
	const FChessCoordinate From = FChessCoordinate::FromAlgebraic(FromSquare);
	const FChessCoordinate To = FChessCoordinate::FromAlgebraic(ToSquare);
	return TryMakeMove(From, To, PromotionChoice);
}

bool UChessGameManager::UndoLastMove()
{
	const bool bSuccess = Board.UndoLastMove();
	if (bSuccess)
	{
		UpdateGameStateAndBroadcast();
	}
	return bSuccess;
}

FChessPiece UChessGameManager::GetPieceAt(const FChessCoordinate& Coord) const
{
	return Board.GetPiece(Coord);
}

FChessPiece UChessGameManager::GetPieceAtAlgebraic(const FString& Square) const
{
	return Board.GetPiece(FChessCoordinate::FromAlgebraic(Square));
}

TArray<FChessMove> UChessGameManager::GetLegalMovesForPiece(const FChessCoordinate& Coord) const
{
	TArray<FChessMove> Moves;
	Board.GetLegalMovesForPiece(Coord, Moves);
	return Moves;
}

TArray<FChessMove> UChessGameManager::GetAllCurrentLegalMoves() const
{
	TArray<FChessMove> Moves;
	Board.GenerateLegalMoves(Board.GetActiveColor(), Moves);
	return Moves;
}

EChessColor UChessGameManager::GetCurrentTurn() const
{
	return Board.GetActiveColor();
}

EChessGameState UChessGameManager::GetCurrentGameState() const
{
	return CurrentGameState;
}

bool UChessGameManager::IsKingInCheck(EChessColor Color) const
{
	return Board.IsInCheck(Color);
}

FChessCoordinate UChessGameManager::GetKingCoordinate(EChessColor Color) const
{
	return (Color == EChessColor::White) ? Board.GetState().WhiteKingPos : Board.GetState().BlackKingPos;
}

TArray<FChessMove> UChessGameManager::GetMoveHistory() const
{
	return Board.GetMoveHistory();
}

void UChessGameManager::UpdateGameStateAndBroadcast()
{
	const EChessColor ActiveColor = Board.GetActiveColor();
	const EChessGameState NewState = Board.EvaluateGameState(ActiveColor);

	CurrentGameState = NewState;

	// Оповещение о шахе с передачей клетки короля
	if (NewState == EChessGameState::Check || NewState == EChessGameState::Checkmate)
	{
		const FChessCoordinate KingPos = GetKingCoordinate(ActiveColor);
		OnCheckStatus.Broadcast(ActiveColor, KingPos);
	}

	// Оповещение об изменении состояния
	OnGameStateChanged.Broadcast(CurrentGameState, ActiveColor);
}
