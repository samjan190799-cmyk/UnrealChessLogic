// Copyright (c) 2026. Все права защищены.
#include "ChessTypes.h"
#include "ChessBoard.h"

FChessBoardState::FChessBoardState()
{
	Grid.SetNumZeroed(64);
	for (int32 i = 0; i < 64; ++i)
	{
		Grid[i] = FChessPiece();
	}
	WhiteKingPos = FChessCoordinate(-1, -1);
	BlackKingPos = FChessCoordinate(-1, -1);
	EnPassantTarget = FChessCoordinate(-1, -1);
	bWhiteCanCastleKingside = true;
	bWhiteCanCastleQueenside = true;
	bBlackCanCastleKingside = true;
	bBlackCanCastleQueenside = true;
	ActiveColor = EChessColor::White;
	HalfmoveClock = 0;
	FullmoveNumber = 1;
}
