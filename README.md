# ChessLogic — 3D Шахматы с Chaos Physics, Touch-контроллером и iOS оптимизацией (UE5)

Высокопроизводительный C++ плагин для **Unreal Engine 5** с полной реализацией правил FIDE, 3D-сцены доски, физического разрушения фигур (**Chaos Destruction**), сенсорного управления под **iOS**, кинематографичной камеры и мобильного UMG интерфейса с таймерами.

---

## 📱 Конфигурация мобильного рендеринга и билда под iOS (60 FPS)

В каталог `Config/` добавлены оптимизированные конфигурационные файлы:
1. **`DefaultEngine.ini`**:
   - **Forward Shading + Metal API**: `r.ForwardShading=True` с аппаратным сглаживанием `r.MobileMSAA=4` обеспечивает кристальную четкость геометрии доски и фигур без мыла TAA на экранах Retina / Super Retina.
   - **Динамические тени**: каскадные тени `r.Shadow.CSM.MaxCascades=2` и `r.Shadow.MaxResolution=1024`.
   - **Отключение тяжелых десктопных подсистем**: отключены Lumen, Nanite, Motion Blur, Auto Exposure для мгновенной стабильной частоты кадров 60 FPS и минимального нагрева устройства.
   - **iOS Runtime Settings**: `MinimumiOSVersion=IOS_16`, `BundleIdentifier=com.Antigravity.Chess3D`, поддержка ориентаций Portrait и Landscape.
2. **`DefaultDeviceProfiles.ini`**:
   - Настроены профили `[IOS DeviceProfile]`, `[iPhone DeviceProfile]`, `[iPad DeviceProfile]` с ограничением `t.MaxFPS=60` и масштабированием содержимого `r.MobileContentScaleFactor=2.0`.
3. **`DefaultScalability.ini`** & **`DefaultGame.ini`**:
   - Профили масштабируемости под мобильные GPU Apple и параметры упаковки Shipping IPA.

---

## 🖥️ Минималистичный UMG интерфейс матча (`UChessMainWidget`)

- **Шахматные часы**: раздельные таймеры белых и черных в формате `ММ:СС`, автоматически переключающиеся при ходе.
- **Индикатор хода**: текстовый статус и цветовая подсветка рамки активного игрока.
- **Баннер статуса**: отображение предупреждений `⚠️ ШАХ!`, `🏆 МАТ! Победа Белых/Черных`, `🤝 ПАТ — Ничья`.
- **Кнопки управления**: «Новая игра» (`RestartButton`) и «Отмена хода» (`UndoButton`).

---

## 📂 Полная структура файлов проекта

```
UnrealChessLogic/
├── ChessLogic.uplugin                   # Дескриптор плагина для UE5
├── Config/
│   ├── DefaultEngine.ini                # Рендерер Forward/Metal, 4x MSAA, настройки iOS
│   ├── DefaultDeviceProfiles.ini        # Профили iPhone/iPad для 60 FPS
│   ├── DefaultGame.ini                  # Метаданные игры и параметры упаковки
│   └── DefaultScalability.ini           # Масштабируемость графики под мобильные GPU
├── Source/
│   └── ChessLogic/
│       ├── ChessLogic.Build.cs          # Зависимости: Chaos, GeometryCollection, Niagara, UMG, Slate
│       ├── Public/
│       │   ├── ChessTypes.h             # FChessCoordinate, FChessPiece, FChessMove, энумы
│       │   ├── ChessDelegates.h         # Мультивещательные делегаты для Blueprints / UI
│       │   ├── ChessBoard.h             # Низкоуровневая логика правил FIDE
│       │   ├── ChessGameManager.h       # UChessGameManager (контроллер матча)
│       │   ├── Visual/
│       │   │   ├── ChessPieceActor.h    # 3D-актер фигуры с интерполяцией EaseInOut
│       │   │   ├── ChessBoardActor.h    # 3D-актер доски и маркеры клеток
│       │   │   └── ChessFracturedPiece.h# Разрушаемая фигура Chaos Physics
│       │   ├── Camera/
│       │   │   ├── ChessCameraActor.h   # Кинематографичная камера с динамическим зумом
│       │   │   └── ChessCameraShake.h   # Шейк камеры при ударе и разрушении
│       │   ├── Input/
│       │   │   └── ChessPlayerController.h # Сенсорный PlayerController для iOS
│       │   └── UI/
│       │       └── ChessMainWidget.h    # C++ базовый класс UMG UI (часы, статус, кнопки)
│       └── Private/
│           ├── ChessLogicModule.cpp
│           ├── ChessTypes.cpp
│           ├── ChessBoard.cpp
│           ├── ChessGameManager.cpp
│           ├── Visual/
│           │   ├── ChessPieceActor.cpp
│           │   ├── ChessBoardActor.cpp
│           │   └── ChessFracturedPiece.cpp
│           ├── Camera/
│           │   ├── ChessCameraActor.cpp
│           │   └── ChessCameraShake.cpp
│           ├── Input/
│           │   └── ChessPlayerController.cpp
│           ├── UI/
│           │   └── ChessMainWidget.cpp
│           └── ChessLogicTests.cpp      # Набор модульных тестов
└── README.md
```
