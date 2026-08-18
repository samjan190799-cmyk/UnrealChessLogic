// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "ChessTypes.h"
#include "ChessDelegates.generated.h"

/**
 * Делегат: Выполнен ход на доске.
 * Передает полную информацию о ходе для визуализации перемещения фигуры и проигрывания звуков.
 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnChessMoveExecuted, const FChessMove&, ExecutedMove);

/**
 * Делегат: Фигура взята и покидает доску.
 * Используется для анимации уничтожения/ухода фигуры, пополнения кладбища фигур и спавна VFX.
 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnChessPieceCaptured, const FChessPiece&, CapturedPiece, const FChessCoordinate&, CapturedAt);

/**
 * Делегат: Изменилось общее состояние партии (Ход продолжается, Шах, Мат, Пат, Ничья).
 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnChessGameStateChanged, EChessGameState, NewState, EChessColor, CurrentTurnColor);

/**
 * Делегат: Статус шаха (король игрока под боем).
 * Передает цвет игрока и координаты атакованного короля для подсветки опасности на доске.
 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnChessCheckStatus, EChessColor, CheckedPlayer, const FChessCoordinate&, KingCoordinate);

/**
 * Делегат: Требуется выбор фигуры для превращения пешки.
 * Вызывается, когда пешка достигла противоположного края, для открытия диалогового окна выбора (Ферзь, Ладья, Слон, Конь).
 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnPawnPromotionRequired, const FChessCoordinate&, PawnCoordinate, EChessColor, Color);

/**
 * Делегат: Доска была сброшена в начальное состояние или загружена из FEN.
 */
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnChessBoardReset);
