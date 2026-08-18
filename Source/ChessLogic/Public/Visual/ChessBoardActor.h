// Copyright (c) 2026. Все права защищены.
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "ChessTypes.h"
#include "ChessBoardActor.generated.h"

class UChessGameManager;
class AChessPieceActor;
class AChessFracturedPiece;
class AChessCameraActor;
class UInstancedStaticMeshComponent;
class UStaticMeshComponent;
class USceneComponent;

/**
 * 3D-актер шахматной доски в Unreal Engine 5.
 * Отвечает за генерацию геометрии доски, спавн и синхронизацию 3D-моделей фигур,
 * визуальную подсветку доступных ходов, спавн разрушаемых фигур Chaos Physics при взятии.
 */
UCLASS(BlueprintType, Blueprintable)
class CHESSLOGIC_API AChessBoardActor : public AActor
{
	GENERATED_BODY()

public:
	AChessBoardActor();

	virtual void BeginPlay() override;

	/** Привязка к игровому менеджеру шахматной логики */
	UFUNCTION(BlueprintCallable, Category = "Chess|Board")
	void InitializeWithManager(UChessGameManager* InGameManager);

	/** Получение мировой 3D-позиции центра клетки по координате */
	UFUNCTION(BlueprintPure, Category = "Chess|Board")
	FVector GetTileWorldLocation(const FChessCoordinate& Coord) const;

	/** Определение координаты клетки по 3D-позиции в мире */
	UFUNCTION(BlueprintPure, Category = "Chess|Board")
	FChessCoordinate GetCoordinateFromWorldLocation(const FVector& WorldLocation) const;

	/** Получение 3D-актера фигуры на заданной клетке */
	UFUNCTION(BlueprintPure, Category = "Chess|Board")
	AChessPieceActor* GetPieceActorAt(const FChessCoordinate& Coord) const;

	// ----------------------------------------------------------------------
	// ВИЗУАЛЬНАЯ ПОДСВЕТКА КЛЕТОК
	// ----------------------------------------------------------------------

	/** Подсветка выбранной клетки */
	UFUNCTION(BlueprintCallable, Category = "Chess|Visual")
	void HighlightSelectedTile(const FChessCoordinate& Coord);

	/** Подсветка доступных легальных ходов для выбранной фигуры */
	UFUNCTION(BlueprintCallable, Category = "Chess|Visual")
	void HighlightLegalMoves(const TArray<FChessMove>& LegalMoves);

	/** Подсветка шаха (опасность под королем) */
	UFUNCTION(BlueprintCallable, Category = "Chess|Visual")
	void HighlightCheck(const FChessCoordinate& KingCoord);

	/** Полная очистка всех подсветок на доске */
	UFUNCTION(BlueprintCallable, Category = "Chess|Visual")
	void ClearAllHighlights();

	/** Полное обновление и переспавн 3D-фигур в соответствии с логикой */
	UFUNCTION(BlueprintCallable, Category = "Chess|Board")
	void RefreshBoardPieces();

	// ----------------------------------------------------------------------
	// НАСТРОЙКИ ДОСКИ И ФИЗИКИ
	// ----------------------------------------------------------------------

	/** Размер одной клетки в единицах Unreal (см) */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Config")
	float TileSize = 100.0f;

	/** Высота плоскости доски */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Config")
	float BoardHeightOffset = 10.0f;

	/** Базовый класс для спавна 3D-фигур */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Config")
	TSubclassOf<AChessPieceActor> PieceActorClass;

	/** Класс разрушаемой фигуры Chaos Physics для спавна при взятии */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Chess|Physics")
	TSubclassOf<AChessFracturedPiece> FracturedPieceClass;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	USceneComponent* SceneRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UStaticMeshComponent* BoardFrameMesh;

	/** Инстансированные маркеры подсветки ходов (оптимизировано под мобильные GPU) */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UInstancedStaticMeshComponent* MoveIndicatorMesh;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Chess|Components")
	UInstancedStaticMeshComponent* CaptureIndicatorMesh;

protected:
	UPROPERTY(Transient, BlueprintReadOnly, Category = "Chess|Manager")
	UChessGameManager* GameManager = nullptr;

	UPROPERTY(Transient)
	TMap<FChessCoordinate, AChessPieceActor*> SpawnedPieceActors;

	// Обработчики событий шахматного движка
	UFUNCTION()
	void HandleMoveExecuted(const FChessMove& Move);

	UFUNCTION()
	void HandlePieceCaptured(const FChessPiece& CapturedPiece, const FChessCoordinate& CapturedAt);

	UFUNCTION()
	void HandleCheckStatus(EChessColor CheckedPlayer, const FChessCoordinate& KingCoordinate);

	UFUNCTION()
	void HandleBoardReset();
};
