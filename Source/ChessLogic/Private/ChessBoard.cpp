// Copyright (c) 2026. Все права защищены.
#include "ChessBoard.h"

FChessBoard::FChessBoard()
{
	ResetToStartingPosition();
}

void FChessBoard::ResetToStartingPosition()
{
	Clear();

	// Расстановка белых фигур (горизонталь 0 и 1)
	SetPiece(FChessCoordinate(0, 0), FChessPiece(EChessPieceType::Rook, EChessColor::White));
	SetPiece(FChessCoordinate(1, 0), FChessPiece(EChessPieceType::Knight, EChessColor::White));
	SetPiece(FChessCoordinate(2, 0), FChessPiece(EChessPieceType::Bishop, EChessColor::White));
	SetPiece(FChessCoordinate(3, 0), FChessPiece(EChessPieceType::Queen, EChessColor::White));
	SetPiece(FChessCoordinate(4, 0), FChessPiece(EChessPieceType::King, EChessColor::White));
	SetPiece(FChessCoordinate(5, 0), FChessPiece(EChessPieceType::Bishop, EChessColor::White));
	SetPiece(FChessCoordinate(6, 0), FChessPiece(EChessPieceType::Knight, EChessColor::White));
	SetPiece(FChessCoordinate(7, 0), FChessPiece(EChessPieceType::Rook, EChessColor::White));

	for (int32 Col = 0; Col < 8; ++Col)
	{
		SetPiece(FChessCoordinate(Col, 1), FChessPiece(EChessPieceType::Pawn, EChessColor::White));
	}

	// Расстановка черных фигур (горизонталь 7 и 6)
	SetPiece(FChessCoordinate(0, 7), FChessPiece(EChessPieceType::Rook, EChessColor::Black));
	SetPiece(FChessCoordinate(1, 7), FChessPiece(EChessPieceType::Knight, EChessColor::Black));
	SetPiece(FChessCoordinate(2, 7), FChessPiece(EChessPieceType::Bishop, EChessColor::Black));
	SetPiece(FChessCoordinate(3, 7), FChessPiece(EChessPieceType::Queen, EChessColor::Black));
	SetPiece(FChessCoordinate(4, 7), FChessPiece(EChessPieceType::King, EChessColor::Black));
	SetPiece(FChessCoordinate(5, 7), FChessPiece(EChessPieceType::Bishop, EChessColor::Black));
	SetPiece(FChessCoordinate(6, 7), FChessPiece(EChessPieceType::Knight, EChessColor::Black));
	SetPiece(FChessCoordinate(7, 7), FChessPiece(EChessPieceType::Rook, EChessColor::Black));

	for (int32 Col = 0; Col < 8; ++Col)
	{
		SetPiece(FChessCoordinate(Col, 6), FChessPiece(EChessPieceType::Pawn, EChessColor::Black));
	}

	State.WhiteKingPos = FChessCoordinate(4, 0);
	State.BlackKingPos = FChessCoordinate(4, 7);
	State.EnPassantTarget = FChessCoordinate(-1, -1);
	State.bWhiteCanCastleKingside = true;
	State.bWhiteCanCastleQueenside = true;
	State.bBlackCanCastleKingside = true;
	State.bBlackCanCastleQueenside = true;
	State.ActiveColor = EChessColor::White;
	State.HalfmoveClock = 0;
	State.FullmoveNumber = 1;

	StateHistory.Empty();
	MoveHistory.Empty();
}

void FChessBoard::Clear()
{
	State = FChessBoardState();
	StateHistory.Empty();
	MoveHistory.Empty();
}

void FChessBoard::SetPiece(const FChessCoordinate& Coord, const FChessPiece& Piece)
{
	if (!Coord.IsValid())
	{
		return;
	}

	State.Grid[Coord.ToFlatIndex()] = Piece;

	if (Piece.Type == EChessPieceType::King)
	{
		if (Piece.Color == EChessColor::White)
		{
			State.WhiteKingPos = Coord;
		}
		else if (Piece.Color == EChessColor::Black)
		{
			State.BlackKingPos = Coord;
		}
	}
}

bool FChessBoard::IsSquareAttacked(const FChessCoordinate& Coord, EChessColor AttackingColor) const
{
	if (!Coord.IsValid() || AttackingColor == EChessColor::None)
	{
		return false;
	}

	// 1. Атака пешками
	const int32 PawnAttackerRow = (AttackingColor == EChessColor::White) ? Coord.Row - 1 : Coord.Row + 1;
	if (PawnAttackerRow >= 0 && PawnAttackerRow < 8)
	{
		const int32 LeftCol = Coord.Col - 1;
		const int32 RightCol = Coord.Col + 1;

		if (LeftCol >= 0)
		{
			const FChessPiece P = GetPiece(FChessCoordinate(LeftCol, PawnAttackerRow));
			if (P.Type == EChessPieceType::Pawn && P.Color == AttackingColor)
			{
				return true;
			}
		}
		if (RightCol < 8)
		{
			const FChessPiece P = GetPiece(FChessCoordinate(RightCol, PawnAttackerRow));
			if (P.Type == EChessPieceType::Pawn && P.Color == AttackingColor)
			{
				return true;
			}
		}
	}

	// 2. Атака конями
	static const int32 KnightOffsets[8][2] = {
		{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
		{1, -2},  {1, 2},  {2, -1},  {2, 1}
	};

	for (int32 i = 0; i < 8; ++i)
	{
		const FChessCoordinate KnightCoord(Coord.Col + KnightOffsets[i][0], Coord.Row + KnightOffsets[i][1]);
		if (KnightCoord.IsValid())
		{
			const FChessPiece P = GetPiece(KnightCoord);
			if (P.Type == EChessPieceType::Knight && P.Color == AttackingColor)
			{
				return true;
			}
		}
	}

	// 3. Атака королем
	static const int32 KingOffsets[8][2] = {
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1},           {0, 1},
		{1, -1},  {1, 0},  {1, 1}
	};

	for (int32 i = 0; i < 8; ++i)
	{
		const FChessCoordinate AdjacentCoord(Coord.Col + KingOffsets[i][0], Coord.Row + KingOffsets[i][1]);
		if (AdjacentCoord.IsValid())
		{
			const FChessPiece P = GetPiece(AdjacentCoord);
			if (P.Type == EChessPieceType::King && P.Color == AttackingColor)
			{
				return true;
			}
		}
	}

	// 4. Прямолинейные атаки (Ладья, Ферзь)
	static const int32 OrthogonalDirs[4][2] = {
		{0, 1}, {0, -1}, {1, 0}, {-1, 0}
	};

	for (int32 d = 0; d < 4; ++d)
	{
		int32 CurCol = Coord.Col + OrthogonalDirs[d][0];
		int32 CurRow = Coord.Row + OrthogonalDirs[d][1];

		while (CurCol >= 0 && CurCol < 8 && CurRow >= 0 && CurRow < 8)
		{
			const FChessPiece P = GetPiece(FChessCoordinate(CurCol, CurRow));
			if (P.IsValidPiece())
			{
				if (P.Color == AttackingColor && (P.Type == EChessPieceType::Rook || P.Type == EChessPieceType::Queen))
				{
					return true;
				}
				break; // Луч заблокирован другой фигурой
			}
			CurCol += OrthogonalDirs[d][0];
			CurRow += OrthogonalDirs[d][1];
		}
	}

	// 5. Диагональные атаки (Слон, Ферзь)
	static const int32 DiagonalDirs[4][2] = {
		{1, 1}, {1, -1}, {-1, 1}, {-1, -1}
	};

	for (int32 d = 0; d < 4; ++d)
	{
		int32 CurCol = Coord.Col + DiagonalDirs[d][0];
		int32 CurRow = Coord.Row + DiagonalDirs[d][1];

		while (CurCol >= 0 && CurCol < 8 && CurRow >= 0 && CurRow < 8)
		{
			const FChessPiece P = GetPiece(FChessCoordinate(CurCol, CurRow));
			if (P.IsValidPiece())
			{
				if (P.Color == AttackingColor && (P.Type == EChessPieceType::Bishop || P.Type == EChessPieceType::Queen))
				{
					return true;
				}
				break; // Луч заблокирован другой фигурой
			}
			CurCol += DiagonalDirs[d][0];
			CurRow += DiagonalDirs[d][1];
		}
	}

	return false;
}

bool FChessBoard::IsInCheck(EChessColor KingColor) const
{
	if (KingColor == EChessColor::None)
	{
		return false;
	}

	FChessCoordinate KingPos = (KingColor == EChessColor::White) ? State.WhiteKingPos : State.BlackKingPos;

	// Страховка на случай отсутствия кэша
	if (!KingPos.IsValid() || GetPiece(KingPos).Type != EChessPieceType::King || GetPiece(KingPos).Color != KingColor)
	{
		for (int32 i = 0; i < 64; ++i)
		{
			if (State.Grid[i].Type == EChessPieceType::King && State.Grid[i].Color == KingColor)
			{
				KingPos = FChessCoordinate::FromFlatIndex(i);
				break;
			}
		}
	}

	if (!KingPos.IsValid())
	{
		return false;
	}

	const EChessColor EnemyColor = (KingColor == EChessColor::White) ? EChessColor::Black : EChessColor::White;
	return IsSquareAttacked(KingPos, EnemyColor);
}

void FChessBoard::AddRayMoves(const FChessCoordinate& From, EChessColor Color, int32 DeltaCol, int32 DeltaRow, TArray<FChessMove>& OutMoves) const
{
	const FChessPiece Piece = GetPiece(From);
	int32 CurCol = From.Col + DeltaCol;
	int32 CurRow = From.Row + DeltaRow;

	while (CurCol >= 0 && CurCol < 8 && CurRow >= 0 && CurRow < 8)
	{
		const FChessCoordinate TargetCoord(CurCol, CurRow);
		const FChessPiece TargetPiece = GetPiece(TargetCoord);

		if (TargetPiece.IsEmpty())
		{
			OutMoves.Add(FChessMove(From, TargetCoord, Piece, TargetPiece, ESpecialMoveType::Normal));
		}
		else
		{
			if (TargetPiece.Color != Color)
			{
				OutMoves.Add(FChessMove(From, TargetCoord, Piece, TargetPiece, ESpecialMoveType::Normal));
			}
			break; // Луч заблокирован
		}

		CurCol += DeltaCol;
		CurRow += DeltaRow;
	}
}

void FChessBoard::GeneratePawnMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	const FChessPiece Pawn = GetPiece(From);
	const int32 ForwardDir = (Color == EChessColor::White) ? 1 : -1;
	const int32 StartRow = (Color == EChessColor::White) ? 1 : 6;
	const int32 PromotionRow = (Color == EChessColor::White) ? 7 : 0;

	// 1. Шаг вперед на 1 клетку
	const int32 NextRow = From.Row + ForwardDir;
	if (NextRow >= 0 && NextRow < 8)
	{
		const FChessCoordinate OneStepCoord(From.Col, NextRow);
		if (GetPiece(OneStepCoord).IsEmpty())
		{
			if (NextRow == PromotionRow)
			{
				// Превращение пешки
				static const EChessPieceType PromTypes[] = {
					EChessPieceType::Queen, EChessPieceType::Rook,
					EChessPieceType::Bishop, EChessPieceType::Knight
				};
				for (EChessPieceType PType : PromTypes)
				{
					OutMoves.Add(FChessMove(From, OneStepCoord, Pawn, FChessPiece(), ESpecialMoveType::Promotion, PType));
				}
			}
			else
			{
				OutMoves.Add(FChessMove(From, OneStepCoord, Pawn, FChessPiece(), ESpecialMoveType::Normal));

				// 2. Шаг вперед на 2 клетки из стартовой позиции
				if (From.Row == StartRow)
				{
					const FChessCoordinate TwoStepCoord(From.Col, From.Row + (2 * ForwardDir));
					if (GetPiece(TwoStepCoord).IsEmpty())
					{
						OutMoves.Add(FChessMove(From, TwoStepCoord, Pawn, FChessPiece(), ESpecialMoveType::Normal));
					}
				}
			}
		}
	}

	// 3. Диагональные взятия
	const int32 CaptureCols[2] = {From.Col - 1, From.Col + 1};
	for (int32 CapCol : CaptureCols)
	{
		if (CapCol >= 0 && CapCol < 8 && NextRow >= 0 && NextRow < 8)
		{
			const FChessCoordinate CapCoord(CapCol, NextRow);
			const FChessPiece TargetPiece = GetPiece(CapCoord);

			// Обычное взятие фигуры соперника
			if (TargetPiece.IsValidPiece() && TargetPiece.Color != Color)
			{
				if (NextRow == PromotionRow)
				{
					static const EChessPieceType PromTypes[] = {
						EChessPieceType::Queen, EChessPieceType::Rook,
						EChessPieceType::Bishop, EChessPieceType::Knight
					};
					for (EChessPieceType PType : PromTypes)
					{
						OutMoves.Add(FChessMove(From, CapCoord, Pawn, TargetPiece, ESpecialMoveType::Promotion, PType));
					}
				}
				else
				{
					OutMoves.Add(FChessMove(From, CapCoord, Pawn, TargetPiece, ESpecialMoveType::Normal));
				}
			}
			// Взятие на проходе (En Passant)
			else if (CapCoord == State.EnPassantTarget)
			{
				const FChessCoordinate VictimCoord(CapCol, From.Row);
				const FChessPiece VictimPiece = GetPiece(VictimCoord);
				if (VictimPiece.Type == EChessPieceType::Pawn && VictimPiece.Color != Color)
				{
					OutMoves.Add(FChessMove(From, CapCoord, Pawn, VictimPiece, ESpecialMoveType::EnPassant));
				}
			}
		}
	}
}

void FChessBoard::GenerateKnightMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	const FChessPiece Knight = GetPiece(From);
	static const int32 Offsets[8][2] = {
		{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2},
		{1, -2},  {1, 2},  {2, -1},  {2, 1}
	};

	for (int32 i = 0; i < 8; ++i)
	{
		const FChessCoordinate TargetCoord(From.Col + Offsets[i][0], From.Row + Offsets[i][1]);
		if (TargetCoord.IsValid())
		{
			const FChessPiece TargetPiece = GetPiece(TargetCoord);
			if (TargetPiece.IsEmpty() || TargetPiece.Color != Color)
			{
				OutMoves.Add(FChessMove(From, TargetCoord, Knight, TargetPiece, ESpecialMoveType::Normal));
			}
		}
	}
}

void FChessBoard::GenerateBishopMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	AddRayMoves(From, Color, 1, 1, OutMoves);
	AddRayMoves(From, Color, 1, -1, OutMoves);
	AddRayMoves(From, Color, -1, 1, OutMoves);
	AddRayMoves(From, Color, -1, -1, OutMoves);
}

void FChessBoard::GenerateRookMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	AddRayMoves(From, Color, 0, 1, OutMoves);
	AddRayMoves(From, Color, 0, -1, OutMoves);
	AddRayMoves(From, Color, 1, 0, OutMoves);
	AddRayMoves(From, Color, -1, 0, OutMoves);
}

void FChessBoard::GenerateQueenMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	GenerateRookMoves(From, Color, OutMoves);
	GenerateBishopMoves(From, Color, OutMoves);
}

void FChessBoard::GenerateKingMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	const FChessPiece King = GetPiece(From);
	static const int32 Offsets[8][2] = {
		{-1, -1}, {-1, 0}, {-1, 1},
		{0, -1},           {0, 1},
		{1, -1},  {1, 0},  {1, 1}
	};

	for (int32 i = 0; i < 8; ++i)
	{
		const FChessCoordinate TargetCoord(From.Col + Offsets[i][0], From.Row + Offsets[i][1]);
		if (TargetCoord.IsValid())
		{
			const FChessPiece TargetPiece = GetPiece(TargetCoord);
			if (TargetPiece.IsEmpty() || TargetPiece.Color != Color)
			{
				OutMoves.Add(FChessMove(From, TargetCoord, King, TargetPiece, ESpecialMoveType::Normal));
			}
		}
	}

	// Генерация рокировки
	GenerateCastlingMoves(From, Color, OutMoves);
}

void FChessBoard::GenerateCastlingMoves(const FChessCoordinate& From, EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	// Рокировка невозможна, если король уже под шахом
	if (IsInCheck(Color))
	{
		return;
	}

	const EChessColor EnemyColor = (Color == EChessColor::White) ? EChessColor::Black : EChessColor::White;
	const FChessPiece King = GetPiece(From);

	if (Color == EChessColor::White)
	{
		if (From == FChessCoordinate(4, 0))
		{
			// Короткая рокировка белых (O-O) -> e1-g1
			if (State.bWhiteCanCastleKingside)
			{
				const FChessCoordinate f1(5, 0);
				const FChessCoordinate g1(6, 0);
				const FChessCoordinate h1(7, 0);
				const FChessPiece Rook = GetPiece(h1);

				if (GetPiece(f1).IsEmpty() && GetPiece(g1).IsEmpty() &&
				    Rook.Type == EChessPieceType::Rook && Rook.Color == EChessColor::White && !Rook.bHasMoved)
				{
					if (!IsSquareAttacked(f1, EnemyColor) && !IsSquareAttacked(g1, EnemyColor))
					{
						OutMoves.Add(FChessMove(From, g1, King, FChessPiece(), ESpecialMoveType::CastlingKingside));
					}
				}
			}

			// Длинная рокировка белых (O-O-O) -> e1-c1
			if (State.bWhiteCanCastleQueenside)
			{
				const FChessCoordinate d1(3, 0);
				const FChessCoordinate c1(2, 0);
				const FChessCoordinate b1(1, 0);
				const FChessCoordinate a1(0, 0);
				const FChessPiece Rook = GetPiece(a1);

				if (GetPiece(d1).IsEmpty() && GetPiece(c1).IsEmpty() && GetPiece(b1).IsEmpty() &&
				    Rook.Type == EChessPieceType::Rook && Rook.Color == EChessColor::White && !Rook.bHasMoved)
				{
					if (!IsSquareAttacked(d1, EnemyColor) && !IsSquareAttacked(c1, EnemyColor))
					{
						OutMoves.Add(FChessMove(From, c1, King, FChessPiece(), ESpecialMoveType::CastlingQueenside));
					}
				}
			}
		}
	}
	else if (Color == EChessColor::Black)
	{
		if (From == FChessCoordinate(4, 7))
		{
			// Короткая рокировка черных (O-O) -> e8-g8
			if (State.bBlackCanCastleKingside)
			{
				const FChessCoordinate f8(5, 7);
				const FChessCoordinate g8(6, 7);
				const FChessCoordinate h8(7, 7);
				const FChessPiece Rook = GetPiece(h8);

				if (GetPiece(f8).IsEmpty() && GetPiece(g8).IsEmpty() &&
				    Rook.Type == EChessPieceType::Rook && Rook.Color == EChessColor::Black && !Rook.bHasMoved)
				{
					if (!IsSquareAttacked(f8, EnemyColor) && !IsSquareAttacked(g8, EnemyColor))
					{
						OutMoves.Add(FChessMove(From, g8, King, FChessPiece(), ESpecialMoveType::CastlingKingside));
					}
				}
			}

			// Длинная рокировка черных (O-O-O) -> e8-c8
			if (State.bBlackCanCastleQueenside)
			{
				const FChessCoordinate d8(3, 7);
				const FChessCoordinate c8(2, 7);
				const FChessCoordinate b8(1, 7);
				const FChessCoordinate a8(0, 7);
				const FChessPiece Rook = GetPiece(a8);

				if (GetPiece(d8).IsEmpty() && GetPiece(c8).IsEmpty() && GetPiece(b8).IsEmpty() &&
				    Rook.Type == EChessPieceType::Rook && Rook.Color == EChessColor::Black && !Rook.bHasMoved)
				{
					if (!IsSquareAttacked(d8, EnemyColor) && !IsSquareAttacked(c8, EnemyColor))
					{
						OutMoves.Add(FChessMove(From, c8, King, FChessPiece(), ESpecialMoveType::CastlingQueenside));
					}
				}
			}
		}
	}
}

void FChessBoard::GeneratePseudoLegalMoves(EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	for (int32 i = 0; i < 64; ++i)
	{
		const FChessPiece Piece = State.Grid[i];
		if (Piece.IsValidPiece() && Piece.Color == Color)
		{
			const FChessCoordinate Coord = FChessCoordinate::FromFlatIndex(i);
			switch (Piece.Type)
			{
				case EChessPieceType::Pawn:   GeneratePawnMoves(Coord, Color, OutMoves); break;
				case EChessPieceType::Knight: GenerateKnightMoves(Coord, Color, OutMoves); break;
				case EChessPieceType::Bishop: GenerateBishopMoves(Coord, Color, OutMoves); break;
				case EChessPieceType::Rook:   GenerateRookMoves(Coord, Color, OutMoves); break;
				case EChessPieceType::Queen:  GenerateQueenMoves(Coord, Color, OutMoves); break;
				case EChessPieceType::King:   GenerateKingMoves(Coord, Color, OutMoves); break;
				default: break;
			}
		}
	}
}

void FChessBoard::ApplyMoveInternal(const FChessMove& Move)
{
	FChessPiece MovingPiece = GetPiece(Move.From);
	MovingPiece.bHasMoved = true;

	// Очищаем клетку отправления
	SetPiece(Move.From, FChessPiece());

	// Обработка особых ходов
	if (Move.SpecialType == ESpecialMoveType::EnPassant)
	{
		// Удаляем сбитую на проходе пешку
		const FChessCoordinate VictimCoord(Move.To.Col, Move.From.Row);
		SetPiece(VictimCoord, FChessPiece());
		SetPiece(Move.To, MovingPiece);
	}
	else if (Move.SpecialType == ESpecialMoveType::CastlingKingside)
	{
		SetPiece(Move.To, MovingPiece);
		// Перемещаем ладью с h на f
		const int32 Row = Move.From.Row;
		FChessPiece Rook = GetPiece(FChessCoordinate(7, Row));
		Rook.bHasMoved = true;
		SetPiece(FChessCoordinate(7, Row), FChessPiece());
		SetPiece(FChessCoordinate(5, Row), Rook);
	}
	else if (Move.SpecialType == ESpecialMoveType::CastlingQueenside)
	{
		SetPiece(Move.To, MovingPiece);
		// Перемещаем ладью с a на d
		const int32 Row = Move.From.Row;
		FChessPiece Rook = GetPiece(FChessCoordinate(0, Row));
		Rook.bHasMoved = true;
		SetPiece(FChessCoordinate(0, Row), FChessPiece());
		SetPiece(FChessCoordinate(3, Row), Rook);
	}
	else if (Move.SpecialType == ESpecialMoveType::Promotion)
	{
		EChessPieceType NewType = Move.PromotedPieceType != EChessPieceType::None ? Move.PromotedPieceType : EChessPieceType::Queen;
		FChessPiece PromotedPiece(NewType, MovingPiece.Color, true);
		SetPiece(Move.To, PromotedPiece);
	}
	else
	{
		SetPiece(Move.To, MovingPiece);
	}
}

void FChessBoard::GenerateLegalMoves(EChessColor Color, TArray<FChessMove>& OutMoves) const
{
	OutMoves.Reset();
	TArray<FChessMove> PseudoMoves;
	PseudoMoves.Reserve(64);
	GeneratePseudoLegalMoves(Color, PseudoMoves);

	FChessBoard* MutableThis = const_cast<FChessBoard*>(this);

	for (const FChessMove& Move : PseudoMoves)
	{
		// Сохраняем состояние для симуляции
		const FChessBoardState SavedState = State;

		MutableThis->ApplyMoveInternal(Move);

		// Если после хода свой король не под шахом — ход полностью легален
		if (!MutableThis->IsInCheck(Color))
		{
			FChessMove LegalMove = Move;

			// Проверяем, ставит ли этот ход шах/мат противнику
			const EChessColor EnemyColor = (Color == EChessColor::White) ? EChessColor::Black : EChessColor::White;
			LegalMove.bIsCheck = MutableThis->IsInCheck(EnemyColor);

			OutMoves.Add(LegalMove);
		}

		// Восстанавливаем состояние
		MutableThis->State = SavedState;
	}
}

void FChessBoard::GetLegalMovesForPiece(const FChessCoordinate& Coord, TArray<FChessMove>& OutMoves) const
{
	OutMoves.Reset();
	if (!Coord.IsValid())
	{
		return;
	}

	const FChessPiece Piece = GetPiece(Coord);
	if (Piece.IsEmpty())
	{
		return;
	}

	TArray<FChessMove> AllLegalMoves;
	GenerateLegalMoves(Piece.Color, AllLegalMoves);

	for (const FChessMove& Move : AllLegalMoves)
	{
		if (Move.From == Coord)
		{
			OutMoves.Add(Move);
		}
	}
}

bool FChessBoard::IsMoveLegal(const FChessMove& Move) const
{
	TArray<FChessMove> LegalMoves;
	GenerateLegalMoves(State.ActiveColor, LegalMoves);

	for (const FChessMove& Legal : LegalMoves)
	{
		if (Legal.From == Move.From && Legal.To == Move.To)
		{
			if (Legal.SpecialType == ESpecialMoveType::Promotion)
			{
				if (Legal.PromotedPieceType == Move.PromotedPieceType || Move.PromotedPieceType == EChessPieceType::None)
				{
					return true;
				}
			}
			else
			{
				return true;
			}
		}
	}

	return false;
}

bool FChessBoard::MakeMove(const FChessMove& InMove, FChessMove& OutExecutedMove)
{
	TArray<FChessMove> LegalMoves;
	GenerateLegalMoves(State.ActiveColor, LegalMoves);

	const FChessMove* MatchedMove = nullptr;
	for (const FChessMove& Legal : LegalMoves)
	{
		if (Legal.From == InMove.From && Legal.To == InMove.To)
		{
			if (Legal.SpecialType == ESpecialMoveType::Promotion)
			{
				if (Legal.PromotedPieceType == InMove.PromotedPieceType ||
				    (InMove.PromotedPieceType == EChessPieceType::None && Legal.PromotedPieceType == EChessPieceType::Queen))
				{
					MatchedMove = &Legal;
					break;
				}
			}
			else
			{
				MatchedMove = &Legal;
				break;
			}
		}
	}

	if (!MatchedMove)
	{
		return false;
	}

	OutExecutedMove = *MatchedMove;

	// Сохраняем состояние в историю для возможного Undo
	StateHistory.Push(State);

	const EChessColor MovingColor = State.ActiveColor;
	const EChessColor EnemyColor = (MovingColor == EChessColor::White) ? EChessColor::Black : EChessColor::White;

	// Применяем ход на доске
	ApplyMoveInternal(OutExecutedMove);

	// Обновление прав на рокировку
	if (OutExecutedMove.PieceMoved.Type == EChessPieceType::King)
	{
		if (MovingColor == EChessColor::White)
		{
			State.bWhiteCanCastleKingside = false;
			State.bWhiteCanCastleQueenside = false;
		}
		else
		{
			State.bBlackCanCastleKingside = false;
			State.bBlackCanCastleQueenside = false;
		}
	}
	else if (OutExecutedMove.PieceMoved.Type == EChessPieceType::Rook)
	{
		if (OutExecutedMove.From == FChessCoordinate(0, 0)) State.bWhiteCanCastleQueenside = false;
		else if (OutExecutedMove.From == FChessCoordinate(7, 0)) State.bWhiteCanCastleKingside = false;
		else if (OutExecutedMove.From == FChessCoordinate(0, 7)) State.bBlackCanCastleQueenside = false;
		else if (OutExecutedMove.From == FChessCoordinate(7, 7)) State.bBlackCanCastleKingside = false;
	}

	// Если ладья соперника была взята на её исходной позиции
	if (OutExecutedMove.PieceCaptured.Type == EChessPieceType::Rook)
	{
		if (OutExecutedMove.To == FChessCoordinate(0, 0)) State.bWhiteCanCastleQueenside = false;
		else if (OutExecutedMove.To == FChessCoordinate(7, 0)) State.bWhiteCanCastleKingside = false;
		else if (OutExecutedMove.To == FChessCoordinate(0, 7)) State.bBlackCanCastleQueenside = false;
		else if (OutExecutedMove.To == FChessCoordinate(7, 7)) State.bBlackCanCastleKingside = false;
	}

	// Обновление En Passant
	if (OutExecutedMove.PieceMoved.Type == EChessPieceType::Pawn &&
	    FMath::Abs(OutExecutedMove.To.Row - OutExecutedMove.From.Row) == 2)
	{
		State.EnPassantTarget = FChessCoordinate(OutExecutedMove.From.Col, (OutExecutedMove.From.Row + OutExecutedMove.To.Row) / 2);
	}
	else
	{
		State.EnPassantTarget = FChessCoordinate(-1, -1);
	}

	// Обновление 50-move clock
	if (OutExecutedMove.PieceMoved.Type == EChessPieceType::Pawn || OutExecutedMove.IsCapture())
	{
		State.HalfmoveClock = 0;
	}
	else
	{
		State.HalfmoveClock++;
	}

	// Обновление номера хода
	if (MovingColor == EChessColor::Black)
	{
		State.FullmoveNumber++;
	}

	// Переключение цвета
	State.ActiveColor = EnemyColor;

	// Проверка шаха и мата для следующего игрока
	OutExecutedMove.bIsCheck = IsInCheck(EnemyColor);
	TArray<FChessMove> EnemyLegalMoves;
	GenerateLegalMoves(EnemyColor, EnemyLegalMoves);
	OutExecutedMove.bIsCheckmate = OutExecutedMove.bIsCheck && (EnemyLegalMoves.Num() == 0);

	MoveHistory.Push(OutExecutedMove);
	return true;
}

bool FChessBoard::UndoLastMove()
{
	if (StateHistory.Num() == 0 || MoveHistory.Num() == 0)
	{
		return false;
	}

	State = StateHistory.Pop();
	MoveHistory.Pop();
	return true;
}

EChessGameState FChessBoard::EvaluateGameState(EChessColor Color) const
{
	TArray<FChessMove> LegalMoves;
	GenerateLegalMoves(Color, LegalMoves);

	const bool bCheck = IsInCheck(Color);

	if (LegalMoves.Num() == 0)
	{
		if (bCheck)
		{
			return EChessGameState::Checkmate;
		}
		else
		{
			return EChessGameState::Stalemate;
		}
	}

	if (bCheck)
	{
		return EChessGameState::Check;
	}

	// Правило 50 ходов (100 полуходов)
	if (State.HalfmoveClock >= 100)
	{
		return EChessGameState::Draw;
	}

	return EChessGameState::Active;
}

bool FChessBoard::LoadFromFEN(const FString& FEN)
{
	TArray<FString> Parts;
	FEN.TrimStartAndEnd().ParseIntoArray(Parts, TEXT(" "), true);
	if (Parts.Num() < 4)
	{
		return false;
	}

	Clear();

	// 1. Расстановка фигур
	const FString& RowsString = Parts[0];
	TArray<FString> FenRows;
	RowsString.ParseIntoArray(FenRows, TEXT("/"), true);
	if (FenRows.Num() != 8)
	{
		return false;
	}

	for (int32 RowIdx = 0; RowIdx < 8; ++RowIdx)
	{
		const int32 BoardRow = 7 - RowIdx; // FEN начинается с 8-го ряда (индекс 7)
		const FString& RowStr = FenRows[RowIdx];
		int32 ColIdx = 0;

		for (int32 CharIdx = 0; CharIdx < RowStr.Len(); ++CharIdx)
		{
			const TCHAR Ch = RowStr[CharIdx];
			if (FChar::IsDigit(Ch))
			{
				ColIdx += (Ch - TEXT('0'));
			}
			else
			{
				if (ColIdx >= 8) break;
				const EChessColor PieceColor = FChar::IsUpper(Ch) ? EChessColor::White : EChessColor::Black;
				const TCHAR Lower = FChar::ToLower(Ch);
				EChessPieceType PieceType = EChessPieceType::None;

				switch (Lower)
				{
					case TEXT('p'): PieceType = EChessPieceType::Pawn; break;
					case TEXT('n'): PieceType = EChessPieceType::Knight; break;
					case TEXT('b'): PieceType = EChessPieceType::Bishop; break;
					case TEXT('r'): PieceType = EChessPieceType::Rook; break;
					case TEXT('q'): PieceType = EChessPieceType::Queen; break;
					case TEXT('k'): PieceType = EChessPieceType::King; break;
					default: break;
				}

				if (PieceType != EChessPieceType::None)
				{
					SetPiece(FChessCoordinate(ColIdx, BoardRow), FChessPiece(PieceType, PieceColor, true));
				}
				ColIdx++;
			}
		}
	}

	// 2. Чей ход
	State.ActiveColor = (Parts[1].ToLower() == TEXT("b")) ? EChessColor::Black : EChessColor::White;

	// 3. Рокировки
	const FString& CastlingStr = Parts[2];
	State.bWhiteCanCastleKingside = CastlingStr.Contains(TEXT("K"));
	State.bWhiteCanCastleQueenside = CastlingStr.Contains(TEXT("Q"));
	State.bBlackCanCastleKingside = CastlingStr.Contains(TEXT("k"));
	State.bBlackCanCastleQueenside = CastlingStr.Contains(TEXT("q"));

	// 4. Взятие на проходе
	const FString& EpStr = Parts[3];
	if (EpStr != TEXT("-"))
	{
		State.EnPassantTarget = FChessCoordinate::FromAlgebraic(EpStr);
	}
	else
	{
		State.EnPassantTarget = FChessCoordinate(-1, -1);
	}

	// 5. Halfmove clock
	if (Parts.Num() > 4)
	{
		State.HalfmoveClock = FCString::Atoi(*Parts[4]);
	}

	// 6. Fullmove number
	if (Parts.Num() > 5)
	{
		State.FullmoveNumber = FCString::Atoi(*Parts[5]);
	}

	return true;
}

FString FChessBoard::ExportToFEN() const
{
	FString Result = TEXT("");

	// 1. Позиция фигур
	for (int32 Row = 7; Row >= 0; --Row)
	{
		int32 EmptyCount = 0;
		for (int32 Col = 0; Col < 8; ++Col)
		{
			const FChessPiece Piece = GetPiece(FChessCoordinate(Col, Row));
			if (Piece.IsEmpty())
			{
				EmptyCount++;
			}
			else
			{
				if (EmptyCount > 0)
				{
					Result.AppendInt(EmptyCount);
					EmptyCount = 0;
				}

				TCHAR PieceChar = TEXT('?');
				switch (Piece.Type)
				{
					case EChessPieceType::Pawn:   PieceChar = TEXT('p'); break;
					case EChessPieceType::Knight: PieceChar = TEXT('n'); break;
					case EChessPieceType::Bishop: PieceChar = TEXT('b'); break;
					case EChessPieceType::Rook:   PieceChar = TEXT('r'); break;
					case EChessPieceType::Queen:  PieceChar = TEXT('q'); break;
					case EChessPieceType::King:   PieceChar = TEXT('k'); break;
					default: break;
				}

				if (Piece.Color == EChessColor::White)
				{
					PieceChar = FChar::ToUpper(PieceChar);
				}
				Result.AppendChar(PieceChar);
			}
		}

		if (EmptyCount > 0)
		{
			Result.AppendInt(EmptyCount);
		}

		if (Row > 0)
		{
			Result.AppendChar(TEXT('/'));
		}
	}

	// 2. Чей ход
	Result.AppendChar(TEXT(' '));
	Result.AppendChar((State.ActiveColor == EChessColor::White) ? TEXT('w') : TEXT('b'));

	// 3. Рокировки
	Result.AppendChar(TEXT(' '));
	FString Castling = TEXT("");
	if (State.bWhiteCanCastleKingside) Castling.AppendChar(TEXT('K'));
	if (State.bWhiteCanCastleQueenside) Castling.AppendChar(TEXT('Q'));
	if (State.bBlackCanCastleKingside) Castling.AppendChar(TEXT('k'));
	if (State.bBlackCanCastleQueenside) Castling.AppendChar(TEXT('q'));
	if (Castling.IsEmpty()) Castling = TEXT("-");
	Result.Append(Castling);

	// 4. En Passant
	Result.AppendChar(TEXT(' '));
	Result.Append(State.EnPassantTarget.IsValid() ? State.EnPassantTarget.ToAlgebraic() : TEXT("-"));

	// 5. Halfmove и Fullmove
	Result.Append(FString::Printf(TEXT(" %d %d"), State.HalfmoveClock, State.FullmoveNumber));

	return Result;
}
