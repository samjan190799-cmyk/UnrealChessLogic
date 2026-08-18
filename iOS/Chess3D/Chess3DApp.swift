import SwiftUI
import SceneKit
import UIKit

// MARK: - Модели шахматной логики

enum PieceColor: String, Sendable {
    case white, black
    
    var opposite: PieceColor {
        self == .white ? .black : .white
    }
}

enum PieceType: String, Sendable {
    case pawn, knight, bishop, rook, queen, king
    
    var symbol: String {
        switch self {
        case .pawn: return "♟"
        case .knight: return "♞"
        case .bishop: return "♝"
        case .rook: return "♜"
        case .queen: return "♛"
        case .king: return "♚"
        }
    }
}

struct ChessCoord: Hashable, Equatable, Sendable {
    let file: Int // 0..7 (A..H)
    let rank: Int // 0..7 (1..8)
    
    var notation: String {
        let fileChar = String(UnicodeScalar(97 + file)!)
        return "\(fileChar)\(rank + 1)"
    }
    
    var isValid: Bool {
        file >= 0 && file < 8 && rank >= 0 && rank < 8
    }
}

struct Piece: Identifiable, Equatable, Sendable {
    let id: UUID
    let type: PieceType
    let color: PieceColor
    var coord: ChessCoord
    
    init(type: PieceType, color: PieceColor, coord: ChessCoord) {
        self.id = UUID()
        self.type = type
        self.color = color
        self.coord = coord
    }
}

// MARK: - Игровой движок (Game Engine)

@MainActor
class ChessGameEngine: ObservableObject {
    @Published var pieces: [Piece] = []
    @Published var selectedPiece: Piece? = nil
    @Published var legalMoves: [ChessCoord] = []
    @Published var currentTurn: PieceColor = .white
    @Published var whiteTime: Int = 270 // 04:30
    @Published var blackTime: Int = 300 // 05:00
    @Published var isTimerRunning: Bool = true
    @Published var moveHistory: [String] = []
    @Published var capturedWhite: [PieceType] = []
    @Published var capturedBlack: [PieceType] = []
    @Published var gameStatusMessage: String = "Ход Белых"
    
    var onPieceMoved: ((Piece, ChessCoord, Piece?) -> Void)?
    var onBoardReset: (() -> Void)?
    
    private var timer: Timer?
    
    init() {
        setupInitialBoard()
        startTimer()
    }
    
    func setupInitialBoard() {
        pieces.removeAll()
        moveHistory.removeAll()
        capturedWhite.removeAll()
        capturedBlack.removeAll()
        currentTurn = .white
        whiteTime = 270
        blackTime = 300
        gameStatusMessage = "Ход Белых"
        selectedPiece = nil
        legalMoves.removeAll()
        
        // Пешки (Воины-пехотинцы)
        for file in 0..<8 {
            pieces.append(Piece(type: .pawn, color: .white, coord: ChessCoord(file: file, rank: 1)))
            pieces.append(Piece(type: .pawn, color: .black, coord: ChessCoord(file: file, rank: 6)))
        }
        
        // Фигуры 1-й и 8-й горизонталей
        let layout: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for (file, type) in layout.enumerated() {
            pieces.append(Piece(type: type, color: .white, coord: ChessCoord(file: file, rank: 0)))
            pieces.append(Piece(type: type, color: .black, coord: ChessCoord(file: file, rank: 7)))
        }
        
        onBoardReset?()
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isTimerRunning else { return }
                if self.currentTurn == .white {
                    if self.whiteTime > 0 { self.whiteTime -= 1 }
                } else {
                    if self.blackTime > 0 { self.blackTime -= 1 }
                }
            }
        }
    }
    
    func pieceAt(_ coord: ChessCoord) -> Piece? {
        pieces.first { $0.coord == coord }
    }
    
    func selectCoord(_ coord: ChessCoord) {
        if let selected = selectedPiece {
            if legalMoves.contains(coord) {
                executeMove(piece: selected, to: coord)
                selectedPiece = nil
                legalMoves.removeAll()
                return
            }
        }
        
        if let piece = pieceAt(coord), piece.color == currentTurn {
            selectedPiece = piece
            legalMoves = calculateLegalMoves(for: piece)
            triggerHaptic(.light)
        } else {
            selectedPiece = nil
            legalMoves.removeAll()
        }
    }
    
    func calculateLegalMoves(for piece: Piece) -> [ChessCoord] {
        var moves: [ChessCoord] = []
        let f = piece.coord.file
        let r = piece.coord.rank
        let forward = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 1 : 6
        
        switch piece.type {
        case .pawn:
            let oneStep = ChessCoord(file: f, rank: r + forward)
            if oneStep.isValid && pieceAt(oneStep) == nil {
                moves.append(oneStep)
                let twoStep = ChessCoord(file: f, rank: r + 2 * forward)
                if r == startRank && pieceAt(twoStep) == nil {
                    moves.append(twoStep)
                }
            }
            for df in [-1, 1] {
                let diag = ChessCoord(file: f + df, rank: r + forward)
                if diag.isValid, let target = pieceAt(diag), target.color != piece.color {
                    moves.append(diag)
                }
            }
            
        case .knight:
            let deltas = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
            for (df, dr) in deltas {
                let dest = ChessCoord(file: f + df, rank: r + dr)
                if dest.isValid {
                    if let target = pieceAt(dest) {
                        if target.color != piece.color { moves.append(dest) }
                    } else {
                        moves.append(dest)
                    }
                }
            }
            
        case .bishop:
            moves += traceRays(from: piece.coord, directions: [(-1, -1), (-1, 1), (1, -1), (1, 1)], color: piece.color)
            
        case .rook:
            moves += traceRays(from: piece.coord, directions: [(-1, 0), (1, 0), (0, -1), (0, 1)], color: piece.color)
            
        case .queen:
            moves += traceRays(from: piece.coord, directions: [(-1, -1), (-1, 1), (1, -1), (1, 1), (-1, 0), (1, 0), (0, -1), (0, 1)], color: piece.color)
            
        case .king:
            for df in -1...1 {
                for dr in -1...1 {
                    if df == 0 && dr == 0 { continue }
                    let dest = ChessCoord(file: f + df, rank: r + dr)
                    if dest.isValid {
                        if let target = pieceAt(dest) {
                            if target.color != piece.color { moves.append(dest) }
                        } else {
                            moves.append(dest)
                        }
                    }
                }
            }
        }
        return moves
    }
    
    private func traceRays(from start: ChessCoord, directions: [(Int, Int)], color: PieceColor) -> [ChessCoord] {
        var results: [ChessCoord] = []
        for (df, dr) in directions {
            var curr = ChessCoord(file: start.file + df, rank: start.rank + dr)
            while curr.isValid {
                if let target = pieceAt(curr) {
                    if target.color != color { results.append(curr) }
                    break
                }
                results.append(curr)
                curr = ChessCoord(file: curr.file + df, rank: curr.rank + dr)
            }
        }
        return results
    }
    
    func executeMove(piece: Piece, to targetCoord: ChessCoord) {
        guard let idx = pieces.firstIndex(where: { $0.id == piece.id }) else { return }
        let captured = pieceAt(targetCoord)
        
        if let captured = captured {
            if let capIdx = pieces.firstIndex(where: { $0.id == captured.id }) {
                pieces.remove(at: capIdx)
                if captured.color == .white {
                    capturedWhite.append(captured.type)
                } else {
                    capturedBlack.append(captured.type)
                }
            }
            triggerHaptic(.heavy)
        } else {
            triggerHaptic(.medium)
        }
        
        var updatedPiece = piece
        updatedPiece.coord = targetCoord
        let newIdx = pieces.firstIndex(where: { $0.id == piece.id }) ?? idx
        pieces[newIdx] = updatedPiece
        
        let moveNotation = "\(piece.type.symbol) \(piece.coord.notation) → \(targetCoord.notation)"
        moveHistory.append(moveNotation)
        
        currentTurn = currentTurn.opposite
        gameStatusMessage = currentTurn == .white ? "Ход Белых" : "Ход Черных"
        
        onPieceMoved?(piece, targetCoord, captured)
    }
    
    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - 3D Сцена Персонажей-Воинов (SceneKit & Metal) — Строго по визуальному эталону

@MainActor
struct ChessSceneView: UIViewRepresentable {
    @ObservedObject var engine: ChessGameEngine
    @Binding var cameraPerspective: CameraPerspective
    
    enum CameraPerspective: String, CaseIterable, Sendable {
        case isometric = "Игрок"
        case topDown = "Сверху"
        case dynamic3D = "3D Кинемат..."
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0)
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        
        context.coordinator.setupScene(scene: scene, scnView: scnView)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateCamera(perspective: cameraPerspective)
        context.coordinator.syncBoardHighlights(legalMoves: engine.legalMoves, selectedPiece: engine.selectedPiece)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }
    
    @MainActor
    class Coordinator: NSObject {
        var engine: ChessGameEngine
        weak var scnView: SCNView?
        var scene: SCNScene?
        var cameraNode = SCNNode()
        var pieceNodes: [UUID: SCNNode] = [:]
        var tileNodes: [ChessCoord: SCNNode] = [:]
        var highlightNodes: [SCNNode] = []
        
        // Размеры и масштаб доски
        let tileSize: Float = 1.0
        let boardOrigin: Float = 0.0
        
        init(engine: ChessGameEngine) {
            self.engine = engine
            super.init()
            self.engine.onPieceMoved = { [weak self] piece, targetCoord, captured in
                self?.animateMove(piece: piece, to: targetCoord, captured: captured)
            }
            self.engine.onBoardReset = { [weak self] in
                self?.rebuildPieces()
            }
        }
        
        // MARK: - Настройка сцены (Освещение, Камера, Доска)
        
        func setupScene(scene: SCNScene, scnView: SCNView) {
            self.scene = scene
            self.scnView = scnView
            
            // ──────────────────────────────────────────────
            // Камера — Изометрический ракурс сверху-спереди
            // ──────────────────────────────────────────────
            let camera = SCNCamera()
            camera.zNear = 0.3
            camera.zFar = 120
            camera.fieldOfView = 42
            camera.wantsHDR = true
            camera.bloomThreshold = 0.8
            camera.bloomIntensity = 0.3
            camera.motionBlurIntensity = 0.0
            camera.wantsExposureAdaptation = false
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(x: 3.5, y: 12.5, z: 11.2)
            cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 3.4, y: 0, z: 0)
            scene.rootNode.addChildNode(cameraNode)
            
            // ──────────────────────────────────────────────
            // Атмосферное кинематографическое освещение
            // ──────────────────────────────────────────────
            
            // 1. Ambient — мягкий общий свет
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = UIColor(white: 0.22, alpha: 1.0)
            ambientLight.intensity = 300
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)
            
            // 2. Key Light — главный направленный свет с тенями (сверху-справа)
            let keyLight = SCNLight()
            keyLight.type = .directional
            keyLight.castsShadow = true
            keyLight.shadowMode = .deferred
            keyLight.shadowSampleCount = 24
            keyLight.shadowRadius = 5.0
            keyLight.shadowMapSize = CGSize(width: 4096, height: 4096)
            keyLight.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.65)
            keyLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1.0)
            keyLight.intensity = 1100
            let keyLightNode = SCNNode()
            keyLightNode.light = keyLight
            keyLightNode.position = SCNVector3(x: 8.0, y: 18.0, z: 10.0)
            keyLightNode.eulerAngles = SCNVector3(x: -Float.pi / 2.8, y: Float.pi / 6.0, z: 0)
            scene.rootNode.addChildNode(keyLightNode)
            
            // 3. Fill Light — заполняющий свет (сверху-слева, холодный)
            let fillLight = SCNLight()
            fillLight.type = .directional
            fillLight.color = UIColor(red: 0.55, green: 0.65, blue: 0.85, alpha: 1.0)
            fillLight.intensity = 350
            fillLight.castsShadow = false
            let fillLightNode = SCNNode()
            fillLightNode.light = fillLight
            fillLightNode.position = SCNVector3(x: -5.0, y: 12.0, z: -3.0)
            fillLightNode.eulerAngles = SCNVector3(x: -Float.pi / 3.5, y: -Float.pi / 5.0, z: 0)
            scene.rootNode.addChildNode(fillLightNode)
            
            // 4. Rim Light — контровой свет (подсветка контуров сзади)
            let rimLight = SCNLight()
            rimLight.type = .directional
            rimLight.color = UIColor(red: 0.9, green: 0.85, blue: 0.95, alpha: 1.0)
            rimLight.intensity = 250
            rimLight.castsShadow = false
            let rimLightNode = SCNNode()
            rimLightNode.light = rimLight
            rimLightNode.position = SCNVector3(x: 3.5, y: 10.0, z: -6.0)
            rimLightNode.eulerAngles = SCNVector3(x: -Float.pi / 4.0, y: Float.pi, z: 0)
            scene.rootNode.addChildNode(rimLightNode)
            
            // Строительство доски и фигур
            buildMarbleChessBoard(scene: scene)
            rebuildPieces()
        }
        
        // MARK: - Мраморная доска с координатами (Точно по эталону)
        
        func buildMarbleChessBoard(scene: SCNScene) {
            // ──────────────────────────────────────────────
            // Рама — тёмный мрамор с серебристыми прожилками
            // ──────────────────────────────────────────────
            let frameWidth: Float = 10.4
            let frameBox = SCNBox(width: CGFloat(frameWidth), height: 0.5, length: CGFloat(frameWidth), chamferRadius: 0.12)
            let frameMat = SCNMaterial()
            frameMat.diffuse.contents = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
            frameMat.roughness.contents = 0.30
            frameMat.metalness.contents = 0.15
            frameMat.normal.contents = generateMarbleNormalMap(width: 512, height: 512, dark: true)
            frameBox.materials = [frameMat]
            let frameNode = SCNNode(geometry: frameBox)
            frameNode.position = SCNVector3(x: 3.5, y: -0.27, z: 3.5)
            scene.rootNode.addChildNode(frameNode)
            
            // Тонкая золотая окантовка по краю рамы
            let borderBox = SCNBox(width: CGFloat(frameWidth + 0.08), height: 0.06, length: CGFloat(frameWidth + 0.08), chamferRadius: 0.14)
            let borderMat = SCNMaterial()
            borderMat.diffuse.contents = UIColor(red: 0.72, green: 0.58, blue: 0.35, alpha: 1.0)
            borderMat.metalness.contents = 0.9
            borderMat.roughness.contents = 0.15
            borderBox.materials = [borderMat]
            let borderNode = SCNNode(geometry: borderBox)
            borderNode.position = SCNVector3(x: 3.5, y: 0.01, z: 3.5)
            scene.rootNode.addChildNode(borderNode)
            
            // ──────────────────────────────────────────────
            // Мраморные клетки 8x8
            // ──────────────────────────────────────────────
            for f in 0..<8 {
                for r in 0..<8 {
                    let coord = ChessCoord(file: f, rank: r)
                    let tileBox = SCNBox(width: 0.97, height: 0.1, length: 0.97, chamferRadius: 0.015)
                    let isLight = (f + r) % 2 != 0
                    
                    let tileMat = SCNMaterial()
                    if isLight {
                        // Светлый бежево-кремовый мрамор с лёгкими прожилками
                        tileMat.diffuse.contents = UIColor(red: 0.88, green: 0.84, blue: 0.78, alpha: 1.0)
                        tileMat.roughness.contents = 0.20
                        tileMat.metalness.contents = 0.05
                        tileMat.normal.contents = generateMarbleNormalMap(width: 128, height: 128, dark: false)
                    } else {
                        // Тёмная клетка — глубокий тёмно-серый мрамор
                        tileMat.diffuse.contents = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
                        tileMat.roughness.contents = 0.24
                        tileMat.metalness.contents = 0.08
                        tileMat.normal.contents = generateMarbleNormalMap(width: 128, height: 128, dark: true)
                    }
                    tileBox.materials = [tileMat]
                    
                    let tileNode = SCNNode(geometry: tileBox)
                    tileNode.position = SCNVector3(x: Float(f), y: 0, z: Float(7 - r))
                    tileNode.name = "tile_\(f)_\(r)"
                    scene.rootNode.addChildNode(tileNode)
                    tileNodes[coord] = tileNode
                }
            }
            
            // ──────────────────────────────────────────────
            // Золотые координаты: a-h снизу, 1-8 слева
            // ──────────────────────────────────────────────
            let goldColor = UIColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1.0)
            let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
            
            // Буквы a-h — вдоль нижнего и верхнего краев
            for (idx, letter) in files.enumerated() {
                // Нижний ряд (перед белыми)
                let textGeom = SCNText(string: letter, extrusionDepth: 0.02)
                textGeom.font = UIFont.systemFont(ofSize: 0.32, weight: .bold)
                textGeom.flatness = 0.1
                let mat = SCNMaterial()
                mat.diffuse.contents = goldColor
                mat.metalness.contents = 0.8
                textGeom.materials = [mat]
                let textNode = SCNNode(geometry: textGeom)
                textNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
                textNode.position = SCNVector3(x: Float(idx) - 0.08, y: 0.06, z: 7.9)
                textNode.scale = SCNVector3(1, 1, 1)
                scene.rootNode.addChildNode(textNode)
                
                // Верхний ряд
                let textGeom2 = SCNText(string: letter, extrusionDepth: 0.02)
                textGeom2.font = UIFont.systemFont(ofSize: 0.32, weight: .bold)
                textGeom2.flatness = 0.1
                textGeom2.materials = [mat]
                let textNode2 = SCNNode(geometry: textGeom2)
                textNode2.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
                textNode2.position = SCNVector3(x: Float(idx) - 0.08, y: 0.06, z: -0.85)
                scene.rootNode.addChildNode(textNode2)
            }
            
            // Цифры 1-8 — вдоль левого и правого краев
            for rank in 1...8 {
                // Левая колонка
                let textGeom = SCNText(string: "\(rank)", extrusionDepth: 0.02)
                textGeom.font = UIFont.systemFont(ofSize: 0.32, weight: .bold)
                textGeom.flatness = 0.1
                let mat = SCNMaterial()
                mat.diffuse.contents = goldColor
                mat.metalness.contents = 0.8
                textGeom.materials = [mat]
                let textNode = SCNNode(geometry: textGeom)
                textNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
                textNode.position = SCNVector3(x: -0.9, y: 0.06, z: Float(8 - rank) - 0.1)
                scene.rootNode.addChildNode(textNode)
                
                // Правая колонка
                let textGeom2 = SCNText(string: "\(rank)", extrusionDepth: 0.02)
                textGeom2.font = UIFont.systemFont(ofSize: 0.32, weight: .bold)
                textGeom2.flatness = 0.1
                textGeom2.materials = [mat]
                let textNode2 = SCNNode(geometry: textGeom2)
                textNode2.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
                textNode2.position = SCNVector3(x: 7.65, y: 0.06, z: Float(8 - rank) - 0.1)
                scene.rootNode.addChildNode(textNode2)
            }
        }
        
        /// Генерация простой нормал-мап текстуры мрамора программно
        func generateMarbleNormalMap(width: Int, height: Int, dark: Bool) -> UIImage {
            let size = CGSize(width: width, height: height)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                // Базовый цвет нормали (нейтральный — (128, 128, 255))
                UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                
                // Добавляем прожилки мрамора как лёгкие вариации нормали
                let lineCount = dark ? 12 : 8
                for _ in 0..<lineCount {
                    let path = UIBezierPath()
                    let startX = CGFloat.random(in: 0...size.width)
                    let startY = CGFloat.random(in: 0...size.height)
                    path.move(to: CGPoint(x: startX, y: startY))
                    
                    let segments = Int.random(in: 3...6)
                    for _ in 0..<segments {
                        let endX = path.currentPoint.x + CGFloat.random(in: -size.width * 0.4...size.width * 0.4)
                        let endY = path.currentPoint.y + CGFloat.random(in: -size.height * 0.4...size.height * 0.4)
                        let cpX = (path.currentPoint.x + endX) / 2 + CGFloat.random(in: -30...30)
                        let cpY = (path.currentPoint.y + endY) / 2 + CGFloat.random(in: -30...30)
                        path.addQuadCurve(to: CGPoint(x: endX, y: endY), controlPoint: CGPoint(x: cpX, y: cpY))
                    }
                    
                    path.lineWidth = CGFloat.random(in: 1.0...3.0)
                    let normalVariation = dark
                        ? UIColor(red: 0.52, green: 0.48, blue: 1.0, alpha: 0.3)
                        : UIColor(red: 0.48, green: 0.52, blue: 1.0, alpha: 0.2)
                    normalVariation.setStroke()
                    path.stroke()
                }
            }
        }
        
        // MARK: - Генерация фигур
        
        func rebuildPieces() {
            guard let scene = scene else { return }
            for (_, node) in pieceNodes {
                node.removeFromParentNode()
            }
            pieceNodes.removeAll()
            
            for piece in engine.pieces {
                let pieceNode = createWarriorCharacterNode(piece: piece)
                pieceNode.position = SCNVector3(
                    x: Float(piece.coord.file),
                    y: 0.06,
                    z: Float(7 - piece.coord.rank)
                )
                scene.rootNode.addChildNode(pieceNode)
                pieceNodes[piece.id] = pieceNode
            }
        }
        
        // MARK: - Материалы по визуальному эталону
        
        /// Создание набора материалов строго по эталону:
        /// - Белые: тёплый кремово-бежевый камень + бронзово-золотая броня
        /// - Чёрные: тёмный бордово-коричневый + тёмное железо с красным свечением
        func createMaterials(isWhite: Bool) -> (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial) {
            let stone = SCNMaterial()
            let armor = SCNMaterial()
            let glow = SCNMaterial()
            let weapon = SCNMaterial()
            
            if isWhite {
                // Кремово-бежевый камень (как на эталоне — тёплый ivory/bone)
                stone.diffuse.contents = UIColor(red: 0.82, green: 0.76, blue: 0.68, alpha: 1.0)
                stone.roughness.contents = 0.35
                stone.metalness.contents = 0.05
                
                // Бронзово-золотая полированная броня
                armor.diffuse.contents = UIColor(red: 0.80, green: 0.62, blue: 0.32, alpha: 1.0)
                armor.metalness.contents = 0.88
                armor.roughness.contents = 0.18
                
                // Золотое свечение (факел, самоцветы)
                glow.diffuse.contents = UIColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1.0)
                glow.emission.contents = UIColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 0.9)
                
                // Оружие — светлое дерево/кость
                weapon.diffuse.contents = UIColor(red: 0.70, green: 0.60, blue: 0.48, alpha: 1.0)
                weapon.roughness.contents = 0.45
            } else {
                // Тёмный бордово-коричневый камень (как на эталоне — не чисто чёрный!)
                stone.diffuse.contents = UIColor(red: 0.22, green: 0.12, blue: 0.12, alpha: 1.0)
                stone.roughness.contents = 0.38
                stone.metalness.contents = 0.08
                
                // Тёмная кованая броня с красноватым оттенком
                armor.diffuse.contents = UIColor(red: 0.16, green: 0.10, blue: 0.10, alpha: 1.0)
                armor.metalness.contents = 0.75
                armor.roughness.contents = 0.28
                
                // Раскалённое алое свечение (глаза, руны)
                glow.diffuse.contents = UIColor(red: 1.0, green: 0.12, blue: 0.0, alpha: 1.0)
                glow.emission.contents = UIColor(red: 1.0, green: 0.08, blue: 0.0, alpha: 1.0)
                
                // Оружие — тёмная сталь
                weapon.diffuse.contents = UIColor(red: 0.15, green: 0.12, blue: 0.12, alpha: 1.0)
                weapon.metalness.contents = 0.8
                weapon.roughness.contents = 0.25
            }
            
            return (stone, armor, glow, weapon)
        }
        
        // MARK: - Загрузка High-Poly 3D моделей воинов (Blender USDZ / OBJ)
        
        private var highPolyModelCache: [String: SCNNode] = [:]
        
        func loadHighPolyModel(pieceType: PieceType, color: PieceColor) -> SCNNode? {
            let baseName = "\(pieceType.rawValue)_\(color.rawValue)"
            if let cached = highPolyModelCache[baseName] {
                return cached.clone()
            }
            
            var modelScene: SCNScene?
            
            let searchPaths: [(String, String)] = [
                ("Models/\(baseName)", "usdz"),
                (baseName, "usdz"),
                ("Models/\(baseName)", "obj"),
                (baseName, "obj")
            ]
            
            for (name, ext) in searchPaths {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) ??
                             Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "Models") {
                    if let scene = try? SCNScene(url: url, options: [
                        SCNSceneSource.LoadingOption.convertToYUp: true,
                        SCNSceneSource.LoadingOption.checkConsistency: false
                    ]) {
                        modelScene = scene
                        break
                    }
                }
                if let scene = SCNScene(named: "\(name).\(ext)") ?? SCNScene(named: name) {
                    modelScene = scene
                    break
                }
            }
            
            guard let loadedScene = modelScene else {
                return nil
            }
            
            let container = SCNNode()
            for child in loadedScene.rootNode.childNodes {
                container.addChildNode(child.clone())
            }
            
            // Нормализация масштаба и центрирование модели
            normalizeModelNode(container, pieceType: pieceType)
            
            highPolyModelCache[baseName] = container
            return container.clone()
        }
        
        func normalizeModelNode(_ node: SCNNode, pieceType: PieceType) {
            let (minB, maxB) = node.boundingBox
            let h = maxB.y - minB.y
            let targetH: Float
            switch pieceType {
            case .king, .queen: targetH = 1.15
            case .bishop, .knight, .rook: targetH = 1.00
            case .pawn: targetH = 0.82
            }
            
            if h > 0.05 {
                let s = targetH / h
                node.scale = SCNVector3(s, s, s)
                
                let cx = (minB.x + maxB.x) / 2.0 * s
                let cz = (minB.z + maxB.z) / 2.0 * s
                let minY = minB.y * s
                node.pivot = SCNMatrix4MakeTranslation(cx, minY, cz)
            }
        }
        
        // MARK: - Построитель 3D воинов
        
        func createWarriorCharacterNode(piece: Piece) -> SCNNode {
            // 1. Попытка загрузки High-Poly модели из Blender ассетов
            if let highPolyNode = loadHighPolyModel(pieceType: piece.type, color: piece.color) {
                let root = SCNNode()
                root.name = "piece_\(piece.id.uuidString)"
                highPolyNode.position = SCNVector3(0, 0, 0)
                root.addChildNode(highPolyNode)
                
                // Для белого слона добавляем динамический свет от факела
                if piece.type == .bishop && piece.color == .white {
                    let torchLight = SCNLight()
                    torchLight.type = .omni
                    torchLight.color = UIColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1.0)
                    torchLight.intensity = 500
                    torchLight.attenuationEndDistance = 4.0
                    torchLight.castsShadow = false
                    let lightNode = SCNNode()
                    lightNode.light = torchLight
                    lightNode.position = SCNVector3(-0.26, 1.25, 0.06)
                    root.addChildNode(lightNode)
                }
                return root
            }
            
            // 2. Процедурный fallback
            let root = SCNNode()
            root.name = "piece_\(piece.id.uuidString)"
            
            let isWhite = piece.color == .white
            let mats = createMaterials(isWhite: isWhite)
            
            // Круглая подставка-пьедестал (чётко видна на эталоне)
            let pedestal = SCNCylinder(radius: 0.38, height: 0.1)
            pedestal.radialSegmentCount = 32
            pedestal.materials = [mats.stone]
            let pedestalNode = SCNNode(geometry: pedestal)
            pedestalNode.position = SCNVector3(x: 0, y: 0.05, z: 0)
            root.addChildNode(pedestalNode)
            
            // Тонкое кольцо вокруг подставки
            let ring = SCNTorus(ringRadius: 0.38, pipeRadius: 0.015)
            ring.materials = [mats.armor]
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(x: 0, y: 0.1, z: 0)
            root.addChildNode(ringNode)
            
            switch piece.type {
            case .pawn:
                buildPawnWarrior(into: root, isWhite: isWhite, mats: mats)
            case .rook:
                buildRookGolem(into: root, isWhite: isWhite, mats: mats)
            case .knight:
                buildKnightCavalry(into: root, isWhite: isWhite, mats: mats)
            case .bishop:
                buildBishopCleric(into: root, isWhite: isWhite, mats: mats)
            case .queen:
                buildQueenSorceress(into: root, isWhite: isWhite, mats: mats)
            case .king:
                buildKingLord(into: root, isWhite: isWhite, mats: mats)
            }
            
            return root
        }
        
        // ═══════════════════════════════════════════════════
        // 1. ПЕШКА — Воин-пехотинец с щитом и копьём
        // ═══════════════════════════════════════════════════
        func buildPawnWarrior(into root: SCNNode, isWhite: Bool, mats: (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial)) {
            // Ноги (два цилиндра)
            for dx: Float in [-0.08, 0.08] {
                let leg = SCNCylinder(radius: 0.06, height: 0.22)
                leg.materials = [mats.stone]
                let legNode = SCNNode(geometry: leg)
                legNode.position = SCNVector3(x: dx, y: 0.21, z: 0)
                root.addChildNode(legNode)
            }
            
            // Юбка доспеха / поддоспешник
            let skirt = SCNCone(topRadius: 0.14, bottomRadius: 0.22, height: 0.18)
            skirt.materials = [mats.armor]
            let skirtNode = SCNNode(geometry: skirt)
            skirtNode.position = SCNVector3(x: 0, y: 0.30, z: 0)
            root.addChildNode(skirtNode)
            
            // Торс (кираса)
            let torso = SCNCapsule(capRadius: 0.14, height: 0.30)
            torso.materials = [mats.armor]
            let torsoNode = SCNNode(geometry: torso)
            torsoNode.position = SCNVector3(x: 0, y: 0.48, z: 0)
            root.addChildNode(torsoNode)
            
            // Наплечники
            for dx: Float in [-0.18, 0.18] {
                let shoulder = SCNSphere(radius: 0.07)
                shoulder.materials = [mats.armor]
                let shNode = SCNNode(geometry: shoulder)
                shNode.position = SCNVector3(x: dx, y: 0.58, z: 0)
                root.addChildNode(shNode)
            }
            
            // Руки
            for dx: Float in [-0.20, 0.20] {
                let arm = SCNCylinder(radius: 0.04, height: 0.24)
                arm.materials = [mats.stone]
                let armNode = SCNNode(geometry: arm)
                armNode.position = SCNVector3(x: dx, y: 0.44, z: 0)
                armNode.eulerAngles = SCNVector3(x: 0, y: 0, z: dx > 0 ? 0.2 : -0.2)
                root.addChildNode(armNode)
            }
            
            // Голова
            let head = SCNSphere(radius: 0.10)
            head.materials = [mats.stone]
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(x: 0, y: 0.70, z: 0)
            root.addChildNode(headNode)
            
            // Шлем
            let helmet = SCNCylinder(radius: 0.11, height: 0.08)
            helmet.materials = [mats.armor]
            let helmetNode = SCNNode(geometry: helmet)
            helmetNode.position = SCNVector3(x: 0, y: 0.77, z: 0)
            root.addChildNode(helmetNode)
            
            // Круглый щит (в левой руке)
            let shield = SCNCylinder(radius: 0.16, height: 0.035)
            shield.radialSegmentCount = 24
            shield.materials = [mats.armor]
            let shieldNode = SCNNode(geometry: shield)
            shieldNode.position = SCNVector3(x: isWhite ? -0.28 : 0.28, y: 0.46, z: 0.06)
            shieldNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 2.2)
            root.addChildNode(shieldNode)
            
            // Умбон на щите
            let umbo = SCNSphere(radius: 0.04)
            umbo.materials = [mats.glow]
            let umboNode = SCNNode(geometry: umbo)
            umboNode.position = SCNVector3(x: 0, y: 0.018, z: 0)
            shieldNode.addChildNode(umboNode)
            
            // Копьё (в правой руке)
            let spear = SCNCylinder(radius: 0.02, height: 0.95)
            spear.materials = [mats.weapon]
            let spearNode = SCNNode(geometry: spear)
            spearNode.position = SCNVector3(x: isWhite ? 0.24 : -0.24, y: 0.56, z: 0.04)
            spearNode.eulerAngles = SCNVector3(x: 0.08, y: 0, z: isWhite ? -0.12 : 0.12)
            root.addChildNode(spearNode)
            
            // Наконечник копья
            let tip = SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.12)
            tip.materials = [mats.armor]
            let tipNode = SCNNode(geometry: tip)
            tipNode.position = SCNVector3(x: 0, y: 0.50, z: 0)
            spearNode.addChildNode(tipNode)
        }
        
        // ═══════════════════════════════════════════════════
        // 2. ЛАДЬЯ — Могучий Каменный Голем
        // Белый: щит-башня + боевой молот
        // Чёрный: шипастые цепи-булавы
        // ═══════════════════════════════════════════════════
        func buildRookGolem(into root: SCNNode, isWhite: Bool, mats: (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial)) {
            // Массивные ноги
            for dx: Float in [-0.10, 0.10] {
                let leg = SCNBox(width: 0.14, height: 0.28, length: 0.14, chamferRadius: 0.02)
                leg.materials = [mats.stone]
                let legNode = SCNNode(geometry: leg)
                legNode.position = SCNVector3(x: dx, y: 0.24, z: 0)
                root.addChildNode(legNode)
            }
            
            // Массивный торс Голема
            let torso = SCNBox(width: 0.50, height: 0.45, length: 0.36, chamferRadius: 0.06)
            torso.materials = [mats.stone]
            let torsoNode = SCNNode(geometry: torso)
            torsoNode.position = SCNVector3(x: 0, y: 0.52, z: 0)
            root.addChildNode(torsoNode)
            
            // Нагрудная пластина
            let chestPlate = SCNBox(width: 0.42, height: 0.30, length: 0.04, chamferRadius: 0.03)
            chestPlate.materials = [mats.armor]
            let chestNode = SCNNode(geometry: chestPlate)
            chestNode.position = SCNVector3(x: 0, y: 0.52, z: 0.19)
            root.addChildNode(chestNode)
            
            // Мощные наплечники
            for dx: Float in [-0.32, 0.32] {
                let shoulder = SCNBox(width: 0.22, height: 0.18, length: 0.22, chamferRadius: 0.04)
                shoulder.materials = [mats.armor]
                let shoulderNode = SCNNode(geometry: shoulder)
                shoulderNode.position = SCNVector3(x: dx, y: 0.68, z: 0)
                root.addChildNode(shoulderNode)
            }
            
            // Руки (из каменных блоков)
            for dx: Float in [-0.34, 0.34] {
                let arm = SCNCylinder(radius: 0.07, height: 0.32)
                arm.materials = [mats.stone]
                let armNode = SCNNode(geometry: arm)
                armNode.position = SCNVector3(x: dx, y: 0.46, z: 0)
                armNode.eulerAngles = SCNVector3(x: 0, y: 0, z: dx > 0 ? 0.25 : -0.25)
                root.addChildNode(armNode)
            }
            
            // Каменная голова-монолит
            let head = SCNBox(width: 0.22, height: 0.22, length: 0.22, chamferRadius: 0.05)
            head.materials = [mats.armor]
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(x: 0, y: 0.84, z: 0.02)
            root.addChildNode(headNode)
            
            // Светящиеся глаза
            let eyeGeo = SCNBox(width: 0.12, height: 0.03, length: 0.03, chamferRadius: 0.01)
            eyeGeo.materials = [mats.glow]
            let eyeNode = SCNNode(geometry: eyeGeo)
            eyeNode.position = SCNVector3(x: 0, y: 0.86, z: 0.14)
            root.addChildNode(eyeNode)
            
            if isWhite {
                // Щит-башня (в правой руке)
                let towerShield = SCNBox(width: 0.28, height: 0.52, length: 0.06, chamferRadius: 0.02)
                towerShield.materials = [mats.armor]
                let shieldNode = SCNNode(geometry: towerShield)
                shieldNode.position = SCNVector3(x: 0.38, y: 0.48, z: 0.16)
                root.addChildNode(shieldNode)
                
                // Боевой Молот (в левой руке)
                let handle = SCNCylinder(radius: 0.03, height: 0.72)
                handle.materials = [mats.weapon]
                let hammerHead = SCNBox(width: 0.16, height: 0.14, length: 0.22, chamferRadius: 0.02)
                hammerHead.materials = [mats.armor]
                let hNode = SCNNode(geometry: handle)
                let hhNode = SCNNode(geometry: hammerHead)
                hhNode.position = SCNVector3(x: 0, y: 0.34, z: 0)
                hNode.addChildNode(hhNode)
                hNode.position = SCNVector3(x: -0.36, y: 0.44, z: 0.12)
                hNode.eulerAngles = SCNVector3(x: 0.1, y: 0, z: -0.15)
                root.addChildNode(hNode)
            } else {
                // Чёрный Голем: шипастые цепи-булавы на обеих руках
                for dx: Float in [-0.38, 0.38] {
                    // Цепь
                    let chain = SCNCylinder(radius: 0.018, height: 0.38)
                    chain.materials = [mats.weapon]
                    let cNode = SCNNode(geometry: chain)
                    cNode.position = SCNVector3(x: dx, y: 0.38, z: 0.18)
                    cNode.eulerAngles = SCNVector3(x: -0.3, y: 0, z: dx > 0 ? 0.3 : -0.3)
                    root.addChildNode(cNode)
                    
                    // Булава (шипастый шар)
                    let flailBall = SCNSphere(radius: 0.10)
                    flailBall.materials = [mats.armor]
                    let fNode = SCNNode(geometry: flailBall)
                    fNode.position = SCNVector3(x: 0, y: -0.22, z: 0)
                    cNode.addChildNode(fNode)
                    
                    // Шипы на булаве
                    for i in 0..<6 {
                        let spike = SCNCone(topRadius: 0, bottomRadius: 0.02, height: 0.06)
                        spike.materials = [mats.weapon]
                        let spikeNode = SCNNode(geometry: spike)
                        let angle = Float(i) * Float.pi * 2.0 / 6.0
                        spikeNode.position = SCNVector3(
                            x: 0.08 * cos(angle),
                            y: 0.04 * sin(angle),
                            z: 0.08 * sin(angle)
                        )
                        spikeNode.eulerAngles = SCNVector3(x: 0, y: 0, z: angle)
                        fNode.addChildNode(spikeNode)
                    }
                }
            }
        }
        
        // ═══════════════════════════════════════════════════
        // 3. КОНЬ — Бронированный всадник на коне
        // ═══════════════════════════════════════════════════
        func buildKnightCavalry(into root: SCNNode, isWhite: Bool, mats: (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial)) {
            // Тело лошади (горизонтальная капсула)
            let horseBody = SCNCapsule(capRadius: 0.14, height: 0.42)
            horseBody.materials = [mats.stone]
            let hbNode = SCNNode(geometry: horseBody)
            hbNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 2)
            hbNode.position = SCNVector3(x: 0, y: 0.32, z: 0)
            root.addChildNode(hbNode)
            
            // Ноги лошади (4 штуки)
            let legPositions: [(Float, Float)] = [(-0.14, 0.10), (0.14, 0.10), (-0.14, -0.10), (0.14, -0.10)]
            for (lx, lz) in legPositions {
                let leg = SCNCylinder(radius: 0.035, height: 0.2)
                leg.materials = [mats.stone]
                let legNode = SCNNode(geometry: leg)
                legNode.position = SCNVector3(x: lx, y: 0.18, z: lz)
                root.addChildNode(legNode)
            }
            
            // Шея лошади (наклонённая вверх)
            let neck = SCNCapsule(capRadius: 0.09, height: 0.28)
            neck.materials = [mats.stone]
            let neckNode = SCNNode(geometry: neck)
            neckNode.position = SCNVector3(x: 0.14, y: 0.52, z: 0)
            neckNode.eulerAngles = SCNVector3(x: 0, y: 0, z: 0.35)
            root.addChildNode(neckNode)
            
            // Голова коня (конусообразная морда)
            let horseHead = SCNCone(topRadius: 0.05, bottomRadius: 0.10, height: 0.22)
            horseHead.materials = [mats.armor]
            let hhNode = SCNNode(geometry: horseHead)
            hhNode.position = SCNVector3(x: 0.20, y: 0.70, z: 0.10)
            hhNode.eulerAngles = SCNVector3(x: -Float.pi / 3.0, y: 0, z: 0.2)
            root.addChildNode(hhNode)
            
            // Уши коня
            for dz: Float in [-0.05, 0.05] {
                let ear = SCNCone(topRadius: 0, bottomRadius: 0.025, height: 0.08)
                ear.materials = [mats.stone]
                let earNode = SCNNode(geometry: ear)
                earNode.position = SCNVector3(x: 0.16, y: 0.74, z: dz)
                root.addChildNode(earNode)
            }
            
            // Бронированный бок лошади
            let horsePlate = SCNBox(width: 0.35, height: 0.22, length: 0.04, chamferRadius: 0.02)
            horsePlate.materials = [mats.armor]
            let plateNode = SCNNode(geometry: horsePlate)
            plateNode.position = SCNVector3(x: 0, y: 0.34, z: 0.16)
            root.addChildNode(plateNode)
            let plateNode2 = SCNNode(geometry: horsePlate)
            plateNode2.position = SCNVector3(x: 0, y: 0.34, z: -0.16)
            root.addChildNode(plateNode2)
            
            // Всадник (сидит на спине лошади)
            let riderTorso = SCNCapsule(capRadius: 0.09, height: 0.22)
            riderTorso.materials = [mats.armor]
            let rNode = SCNNode(geometry: riderTorso)
            rNode.position = SCNVector3(x: -0.02, y: 0.58, z: 0)
            root.addChildNode(rNode)
            
            // Голова всадника
            let riderHead = SCNSphere(radius: 0.07)
            riderHead.materials = [mats.stone]
            let rhNode = SCNNode(geometry: riderHead)
            rhNode.position = SCNVector3(x: -0.02, y: 0.74, z: 0)
            root.addChildNode(rhNode)
            
            // Шлем всадника
            let riderHelm = SCNCylinder(radius: 0.08, height: 0.06)
            riderHelm.materials = [mats.armor]
            let helmNode = SCNNode(geometry: riderHelm)
            helmNode.position = SCNVector3(x: -0.02, y: 0.80, z: 0)
            root.addChildNode(helmNode)
            
            // Меч в руке всадника
            let sword = SCNBox(width: 0.03, height: 0.48, length: 0.015, chamferRadius: 0.003)
            sword.materials = [mats.weapon]
            let swordNode = SCNNode(geometry: sword)
            swordNode.position = SCNVector3(x: -0.14, y: 0.68, z: 0.14)
            swordNode.eulerAngles = SCNVector3(x: -0.3, y: 0.2, z: -0.5)
            root.addChildNode(swordNode)
        }
        
        // ═══════════════════════════════════════════════════
        // 4. СЛОН — Боевой Маг/Клерик с пылающим посохом
        // ═══════════════════════════════════════════════════
        func buildBishopCleric(into root: SCNNode, isWhite: Bool, mats: (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial)) {
            // Длинная мантия (конус)
            let robe = SCNCone(topRadius: 0.10, bottomRadius: 0.28, height: 0.72)
            robe.materials = [mats.stone]
            let robeNode = SCNNode(geometry: robe)
            robeNode.position = SCNVector3(x: 0, y: 0.46, z: 0)
            root.addChildNode(robeNode)
            
            // Пояс
            let belt = SCNCylinder(radius: 0.18, height: 0.05)
            belt.materials = [mats.armor]
            let beltNode = SCNNode(geometry: belt)
            beltNode.position = SCNVector3(x: 0, y: 0.42, z: 0)
            root.addChildNode(beltNode)
            
            // Руки
            for dx: Float in [-0.18, 0.18] {
                let arm = SCNCylinder(radius: 0.04, height: 0.28)
                arm.materials = [mats.stone]
                let armNode = SCNNode(geometry: arm)
                armNode.position = SCNVector3(x: dx, y: 0.56, z: 0)
                armNode.eulerAngles = SCNVector3(x: 0, y: 0, z: dx > 0 ? 0.3 : -0.3)
                root.addChildNode(armNode)
            }
            
            // Наплечники и капюшон/митра
            let hood = SCNCapsule(capRadius: 0.11, height: 0.22)
            hood.materials = [mats.armor]
            let hoodNode = SCNNode(geometry: hood)
            hoodNode.position = SCNVector3(x: 0, y: 0.88, z: 0)
            root.addChildNode(hoodNode)
            
            // Лицо
            let face = SCNSphere(radius: 0.08)
            face.materials = [mats.stone]
            let faceNode = SCNNode(geometry: face)
            faceNode.position = SCNVector3(x: 0, y: 0.84, z: 0.06)
            root.addChildNode(faceNode)
            
            // Посох с навершием
            let staff = SCNCylinder(radius: 0.022, height: 1.10)
            staff.materials = [mats.weapon]
            let staffNode = SCNNode(geometry: staff)
            staffNode.position = SCNVector3(x: isWhite ? -0.26 : 0.26, y: 0.62, z: 0.08)
            staffNode.eulerAngles = SCNVector3(x: 0.06, y: 0, z: isWhite ? -0.08 : 0.08)
            root.addChildNode(staffNode)
            
            // Набалдашник посоха (кристалл / навершие)
            let orb = SCNSphere(radius: 0.06)
            orb.materials = [mats.glow]
            let orbNode = SCNNode(geometry: orb)
            orbNode.position = SCNVector3(x: 0, y: 0.56, z: 0)
            staffNode.addChildNode(orbNode)
            
            // Пламя факела (большая светящаяся сфера)
            let flame = SCNSphere(radius: 0.10)
            let flameMat = SCNMaterial()
            if isWhite {
                flameMat.diffuse.contents = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 0.85)
                flameMat.emission.contents = UIColor(red: 1.0, green: 0.60, blue: 0.10, alpha: 1.0)
            } else {
                flameMat.diffuse.contents = UIColor(red: 1.0, green: 0.15, blue: 0.0, alpha: 0.85)
                flameMat.emission.contents = UIColor(red: 0.9, green: 0.08, blue: 0.0, alpha: 1.0)
            }
            flameMat.isDoubleSided = true
            flame.materials = [flameMat]
            let flameNode = SCNNode(geometry: flame)
            flameNode.position = SCNVector3(x: 0, y: 0.60, z: 0)
            staffNode.addChildNode(flameNode)
            
            // Динамический источник света от пламени
            let torchLight = SCNLight()
            torchLight.type = .omni
            torchLight.color = isWhite
                ? UIColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1.0)
                : UIColor(red: 1.0, green: 0.25, blue: 0.0, alpha: 1.0)
            torchLight.intensity = 500
            torchLight.attenuationStartDistance = 0.5
            torchLight.attenuationEndDistance = 4.0
            torchLight.castsShadow = false
            flameNode.light = torchLight
            
            // Анимация мерцания пламени
            let flicker = SCNAction.sequence([
                SCNAction.scale(to: 1.15, duration: 0.3),
                SCNAction.scale(to: 0.90, duration: 0.25),
                SCNAction.scale(to: 1.05, duration: 0.28),
                SCNAction.scale(to: 0.95, duration: 0.22)
            ])
            flameNode.runAction(SCNAction.repeatForever(flicker))
        }
        
        // ═══════════════════════════════════════════════════
        // 5. КОРОЛЕВА — Чародейка / Тёмная Леди
        // ═══════════════════════════════════════════════════
        func buildQueenSorceress(into root: SCNNode, isWhite: Bool, mats: (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial)) {
            // Длинное платье/доспех (плавный конус)
            let gown = SCNCone(topRadius: 0.12, bottomRadius: 0.30, height: 0.82)
            gown.materials = [mats.stone]
            let gownNode = SCNNode(geometry: gown)
            gownNode.position = SCNVector3(x: 0, y: 0.52, z: 0)
            root.addChildNode(gownNode)
            
            // Корсет / броня
            let corset = SCNCylinder(radius: 0.14, height: 0.24)
            corset.materials = [mats.armor]
            let corsetNode = SCNNode(geometry: corset)
            corsetNode.position = SCNVector3(x: 0, y: 0.68, z: 0)
            root.addChildNode(corsetNode)
            
            // Плечи
            for dx: Float in [-0.18, 0.18] {
                let shoulder = SCNSphere(radius: 0.06)
                shoulder.materials = [mats.armor]
                let shNode = SCNNode(geometry: shoulder)
                shNode.position = SCNVector3(x: dx, y: 0.76, z: 0)
                root.addChildNode(shNode)
            }
            
            // Руки (изящные)
            for dx: Float in [-0.20, 0.20] {
                let arm = SCNCylinder(radius: 0.032, height: 0.28)
                arm.materials = [mats.stone]
                let armNode = SCNNode(geometry: arm)
                armNode.position = SCNVector3(x: dx, y: 0.60, z: 0)
                armNode.eulerAngles = SCNVector3(x: 0.15, y: 0, z: dx > 0 ? 0.35 : -0.35)
                root.addChildNode(armNode)
            }
            
            // Голова
            let head = SCNSphere(radius: 0.09)
            head.materials = [mats.stone]
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(x: 0, y: 0.92, z: 0)
            root.addChildNode(headNode)
            
            // Корона (тиара)
            let crown = SCNCylinder(radius: 0.12, height: 0.08)
            crown.materials = [mats.armor]
            let crownNode = SCNNode(geometry: crown)
            crownNode.position = SCNVector3(x: 0, y: 1.00, z: 0)
            root.addChildNode(crownNode)
            
            // Зубцы короны
            for i in 0..<5 {
                let spike = SCNCone(topRadius: 0, bottomRadius: 0.02, height: 0.08)
                spike.materials = [mats.armor]
                let spikeNode = SCNNode(geometry: spike)
                let angle = Float(i) * Float.pi * 2.0 / 5.0
                spikeNode.position = SCNVector3(
                    x: 0.10 * cos(angle),
                    y: 1.06,
                    z: 0.10 * sin(angle)
                )
                root.addChildNode(spikeNode)
            }
            
            // Светящийся самоцвет на короне
            let gem = SCNSphere(radius: 0.045)
            gem.materials = [mats.glow]
            let gemNode = SCNNode(geometry: gem)
            gemNode.position = SCNVector3(x: 0, y: 1.08, z: 0)
            root.addChildNode(gemNode)
            
            // Магический посох/жезл (в правой руке)
            let scepter = SCNCylinder(radius: 0.018, height: 0.65)
            scepter.materials = [mats.weapon]
            let scepterNode = SCNNode(geometry: scepter)
            scepterNode.position = SCNVector3(x: isWhite ? 0.26 : -0.26, y: 0.58, z: 0.10)
            scepterNode.eulerAngles = SCNVector3(x: 0.1, y: 0, z: isWhite ? -0.2 : 0.2)
            root.addChildNode(scepterNode)
            
            // Магическая сфера на конце жезла
            let magicOrb = SCNSphere(radius: 0.055)
            magicOrb.materials = [mats.glow]
            let magicOrbNode = SCNNode(geometry: magicOrb)
            magicOrbNode.position = SCNVector3(x: 0, y: 0.34, z: 0)
            scepterNode.addChildNode(magicOrbNode)
        }
        
        // ═══════════════════════════════════════════════════
        // 6. КОРОЛЬ — Верховный Паладин / Тёмный Владыка
        // ═══════════════════════════════════════════════════
        func buildKingLord(into root: SCNNode, isWhite: Bool, mats: (stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial, weapon: SCNMaterial)) {
            // Ноги (массивные)
            for dx: Float in [-0.09, 0.09] {
                let leg = SCNCylinder(radius: 0.065, height: 0.26)
                leg.materials = [mats.stone]
                let legNode = SCNNode(geometry: leg)
                legNode.position = SCNVector3(x: dx, y: 0.23, z: 0)
                root.addChildNode(legNode)
            }
            
            // Поножи (бронированные)
            for dx: Float in [-0.09, 0.09] {
                let greave = SCNCylinder(radius: 0.075, height: 0.12)
                greave.materials = [mats.armor]
                let greaveNode = SCNNode(geometry: greave)
                greaveNode.position = SCNVector3(x: dx, y: 0.18, z: 0)
                root.addChildNode(greaveNode)
            }
            
            // Юбка доспеха
            let skirt = SCNCone(topRadius: 0.16, bottomRadius: 0.24, height: 0.18)
            skirt.materials = [mats.armor]
            let skirtNode = SCNNode(geometry: skirt)
            skirtNode.position = SCNVector3(x: 0, y: 0.36, z: 0)
            root.addChildNode(skirtNode)
            
            // Массивный торс в полных латах
            let torso = SCNBox(width: 0.40, height: 0.38, length: 0.28, chamferRadius: 0.05)
            torso.materials = [mats.armor]
            let torsoNode = SCNNode(geometry: torso)
            torsoNode.position = SCNVector3(x: 0, y: 0.58, z: 0)
            root.addChildNode(torsoNode)
            
            // Нагрудная эмблема
            let emblem = SCNCylinder(radius: 0.06, height: 0.02)
            emblem.materials = [mats.glow]
            let emblemNode = SCNNode(geometry: emblem)
            emblemNode.position = SCNVector3(x: 0, y: 0.62, z: 0.15)
            emblemNode.eulerAngles = SCNVector3(x: Float.pi / 2, y: 0, z: 0)
            root.addChildNode(emblemNode)
            
            // Мощные наплечники
            for dx: Float in [-0.26, 0.26] {
                let shoulder = SCNBox(width: 0.18, height: 0.12, length: 0.16, chamferRadius: 0.03)
                shoulder.materials = [mats.armor]
                let shoulderNode = SCNNode(geometry: shoulder)
                shoulderNode.position = SCNVector3(x: dx, y: 0.72, z: 0)
                root.addChildNode(shoulderNode)
            }
            
            // Руки
            for dx: Float in [-0.28, 0.28] {
                let arm = SCNCylinder(radius: 0.045, height: 0.28)
                arm.materials = [mats.stone]
                let armNode = SCNNode(geometry: arm)
                armNode.position = SCNVector3(x: dx, y: 0.52, z: 0)
                armNode.eulerAngles = SCNVector3(x: 0, y: 0, z: dx > 0 ? 0.2 : -0.2)
                root.addChildNode(armNode)
            }
            
            // Накидка/плащ (за спиной)
            let cape = SCNBox(width: 0.38, height: 0.58, length: 0.04, chamferRadius: 0.02)
            cape.materials = [mats.stone]
            let capeNode = SCNNode(geometry: cape)
            capeNode.position = SCNVector3(x: 0, y: 0.52, z: -0.16)
            root.addChildNode(capeNode)
            
            // Голова
            let head = SCNSphere(radius: 0.10)
            head.materials = [mats.stone]
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(x: 0, y: 0.84, z: 0)
            root.addChildNode(headNode)
            
            // Великий двуручный меч (Greatsword)
            let blade = SCNBox(width: 0.06, height: 0.95, length: 0.015, chamferRadius: 0.003)
            blade.materials = [mats.weapon]
            let bladeNode = SCNNode(geometry: blade)
            bladeNode.position = SCNVector3(x: isWhite ? 0.30 : -0.30, y: 0.62, z: 0.16)
            bladeNode.eulerAngles = SCNVector3(x: 0.12, y: 0, z: isWhite ? -0.12 : 0.12)
            root.addChildNode(bladeNode)
            
            // Гарда меча
            let guard_ = SCNBox(width: 0.18, height: 0.035, length: 0.035, chamferRadius: 0.005)
            guard_.materials = [mats.armor]
            let guardNode = SCNNode(geometry: guard_)
            guardNode.position = SCNVector3(x: 0, y: -0.22, z: 0)
            bladeNode.addChildNode(guardNode)
            
            // Корона Владыки (более массивная, чем у Королевы)
            let crown = SCNCylinder(radius: 0.14, height: 0.10)
            crown.materials = [mats.armor]
            let crownNode = SCNNode(geometry: crown)
            crownNode.position = SCNVector3(x: 0, y: 0.96, z: 0)
            root.addChildNode(crownNode)
            
            // Зубцы короны
            for i in 0..<6 {
                let prong = SCNBox(width: 0.03, height: 0.06, length: 0.02, chamferRadius: 0.005)
                prong.materials = [mats.armor]
                let prongNode = SCNNode(geometry: prong)
                let angle = Float(i) * Float.pi * 2.0 / 6.0
                prongNode.position = SCNVector3(
                    x: 0.12 * cos(angle),
                    y: 1.04,
                    z: 0.12 * sin(angle)
                )
                root.addChildNode(prongNode)
            }
            
            // Крестовина на вершине короны
            let cross1 = SCNBox(width: 0.10, height: 0.025, length: 0.025, chamferRadius: 0.005)
            cross1.materials = [mats.glow]
            let cross1Node = SCNNode(geometry: cross1)
            cross1Node.position = SCNVector3(x: 0, y: 1.08, z: 0)
            root.addChildNode(cross1Node)
            let cross2 = SCNBox(width: 0.025, height: 0.025, length: 0.10, chamferRadius: 0.005)
            cross2.materials = [mats.glow]
            let cross2Node = SCNNode(geometry: cross2)
            cross2Node.position = SCNVector3(x: 0, y: 1.08, z: 0)
            root.addChildNode(cross2Node)
        }
        
        // MARK: - Подсветка допустимых ходов
        
        func syncBoardHighlights(legalMoves: [ChessCoord], selectedPiece: Piece?) {
            highlightNodes.forEach { $0.removeFromParentNode() }
            highlightNodes.removeAll()
            
            guard let scene = scene else { return }
            
            // Свечение под выбранной фигурой
            if let selected = selectedPiece, let pieceNode = pieceNodes[selected.id] {
                let ringGeom = SCNTorus(ringRadius: 0.42, pipeRadius: 0.025)
                let ringMat = SCNMaterial()
                ringMat.diffuse.contents = UIColor.systemCyan.withAlphaComponent(0.8)
                ringMat.emission.contents = UIColor.systemCyan
                ringGeom.materials = [ringMat]
                let ringNode = SCNNode(geometry: ringGeom)
                ringNode.position = SCNVector3(x: 0, y: 0.03, z: 0)
                pieceNode.addChildNode(ringNode)
                highlightNodes.append(ringNode)
                
                // Пульсирующая анимация
                let pulse = SCNAction.sequence([
                    SCNAction.scale(to: 1.12, duration: 0.5),
                    SCNAction.scale(to: 0.92, duration: 0.5)
                ])
                ringNode.runAction(SCNAction.repeatForever(pulse))
            }
            
            // Точки допустимых ходов
            for move in legalMoves {
                let isCapture = engine.pieceAt(move) != nil
                let markerGeom: SCNGeometry
                let markerMat = SCNMaterial()
                
                if isCapture {
                    // Кольцо-предупреждение для взятия
                    let torusGeom = SCNTorus(ringRadius: 0.35, pipeRadius: 0.03)
                    markerMat.diffuse.contents = UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 0.85)
                    markerMat.emission.contents = UIColor(red: 0.8, green: 0.1, blue: 0.0, alpha: 0.6)
                    torusGeom.materials = [markerMat]
                    markerGeom = torusGeom
                } else {
                    // Маленькая точка-индикатор для обычного хода
                    let dotGeom = SCNCylinder(radius: 0.10, height: 0.04)
                    markerMat.diffuse.contents = UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 0.7)
                    markerMat.emission.contents = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.4)
                    dotGeom.materials = [markerMat]
                    markerGeom = dotGeom
                }
                
                let markerNode = SCNNode(geometry: markerGeom)
                markerNode.position = SCNVector3(
                    x: Float(move.file),
                    y: 0.07,
                    z: Float(7 - move.rank)
                )
                scene.rootNode.addChildNode(markerNode)
                highlightNodes.append(markerNode)
            }
        }
        
        // MARK: - Chaos Physics: Эффекты разрушения
        
        func animateMove(piece: Piece, to targetCoord: ChessCoord, captured: Piece?) {
            guard let node = pieceNodes[piece.id] else { return }
            
            if let captured = captured, let capNode = pieceNodes[captured.id] {
                if captured.color == .white {
                    spawnWhiteDestructionExplosion(at: capNode.position)
                } else {
                    spawnBlackDestructionExplosion(at: capNode.position)
                }
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.22
                capNode.opacity = 0.0
                capNode.scale = SCNVector3(0.01, 0.01, 0.01)
                SCNTransaction.commit()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    capNode.removeFromParentNode()
                    self.pieceNodes.removeValue(forKey: captured.id)
                }
                punchCamera()
            }
            
            // Параболическое перемещение фигуры с вращением
            let targetPos = SCNVector3(
                x: Float(targetCoord.file),
                y: 0.06,
                z: Float(7 - targetCoord.rank)
            )
            let midY: Float = 1.5
            let liftPos = SCNVector3(
                x: (node.position.x + targetPos.x) / 2,
                y: midY,
                z: (node.position.z + targetPos.z) / 2
            )
            
            let moveUp = SCNAction.move(to: liftPos, duration: 0.20)
            moveUp.timingMode = .easeOut
            let moveDown = SCNAction.move(to: targetPos, duration: 0.20)
            moveDown.timingMode = .easeIn
            
            node.runAction(SCNAction.sequence([moveUp, moveDown]))
        }
        
        // 💥 Белые: Золотисто-костяные осколки, золотая пыль
        func spawnWhiteDestructionExplosion(at pos: SCNVector3) {
            guard let scene = scene else { return }
            
            // Крупные костяные осколки
            for _ in 0..<14 {
                let sizes: [CGFloat] = [0.06, 0.08, 0.10, 0.12]
                let s = sizes.randomElement()!
                let shardGeom = SCNBox(width: s, height: s * 1.3, length: s * 0.6, chamferRadius: 0.01)
                let shardMat = SCNMaterial()
                let brightness = CGFloat.random(in: 0.72...0.92)
                shardMat.diffuse.contents = UIColor(red: brightness, green: brightness * 0.88, blue: brightness * 0.68, alpha: 1.0)
                shardMat.metalness.contents = 0.5
                shardMat.roughness.contents = 0.3
                shardGeom.materials = [shardMat]
                let shardNode = SCNNode(geometry: shardGeom)
                shardNode.position = pos
                shardNode.eulerAngles = SCNVector3(
                    x: Float.random(in: 0...Float.pi),
                    y: Float.random(in: 0...Float.pi),
                    z: Float.random(in: 0...Float.pi)
                )
                scene.rootNode.addChildNode(shardNode)
                
                let rx = Float.random(in: -1.5...1.5)
                let ry = Float.random(in: 1.2...2.8)
                let rz = Float.random(in: -1.5...1.5)
                let launchPos = SCNVector3(x: pos.x + rx, y: pos.y + ry, z: pos.z + rz)
                let groundPos = SCNVector3(x: launchPos.x, y: 0.05, z: launchPos.z)
                
                let spin = SCNAction.rotateBy(
                    x: CGFloat(Float.random(in: -6...6)),
                    y: CGFloat(Float.random(in: -6...6)),
                    z: CGFloat(Float.random(in: -6...6)),
                    duration: 0.6
                )
                let fly = SCNAction.move(to: launchPos, duration: 0.20)
                fly.timingMode = .easeOut
                let fall = SCNAction.move(to: groundPos, duration: 0.35)
                fall.timingMode = .easeIn
                let fade = SCNAction.fadeOut(duration: 0.55)
                let remove = SCNAction.removeFromParentNode()
                
                shardNode.runAction(SCNAction.group([spin, SCNAction.sequence([fly, fall, fade, remove])]))
            }
            
            // Мелкие золотые искры
            for _ in 0..<10 {
                let sparkGeom = SCNSphere(radius: CGFloat.random(in: 0.015...0.035))
                let sparkMat = SCNMaterial()
                sparkMat.diffuse.contents = UIColor(red: 1.0, green: 0.80, blue: 0.30, alpha: 1.0)
                sparkMat.emission.contents = UIColor(red: 1.0, green: 0.65, blue: 0.10, alpha: 0.8)
                sparkGeom.materials = [sparkMat]
                let sparkNode = SCNNode(geometry: sparkGeom)
                sparkNode.position = pos
                scene.rootNode.addChildNode(sparkNode)
                
                let target = SCNVector3(
                    x: pos.x + Float.random(in: -2.0...2.0),
                    y: pos.y + Float.random(in: 0.5...3.0),
                    z: pos.z + Float.random(in: -2.0...2.0)
                )
                let sparkFly = SCNAction.move(to: target, duration: TimeInterval.random(in: 0.3...0.7))
                let sparkFade = SCNAction.fadeOut(duration: 0.3)
                let sparkRemove = SCNAction.removeFromParentNode()
                sparkNode.runAction(SCNAction.sequence([sparkFly, sparkFade, sparkRemove]))
            }
        }
        
        // 🔥 Чёрные: Раскалённый обсидиан, лава, дым
        func spawnBlackDestructionExplosion(at pos: SCNVector3) {
            guard let scene = scene else { return }
            
            // Раскалённые обсидиановые глыбы
            for _ in 0..<16 {
                let sizes: [CGFloat] = [0.07, 0.09, 0.11, 0.13]
                let s = sizes.randomElement()!
                let shardGeom = SCNBox(width: s, height: s * 1.2, length: s * 0.7, chamferRadius: 0.01)
                let shardMat = SCNMaterial()
                shardMat.diffuse.contents = UIColor(red: 0.06, green: 0.04, blue: 0.04, alpha: 1.0)
                let emissionBrightness = CGFloat.random(in: 0.4...1.0)
                shardMat.emission.contents = UIColor(red: emissionBrightness, green: emissionBrightness * 0.2, blue: 0.0, alpha: 0.9)
                shardMat.metalness.contents = 0.3
                shardGeom.materials = [shardMat]
                let shardNode = SCNNode(geometry: shardGeom)
                shardNode.position = pos
                shardNode.eulerAngles = SCNVector3(
                    x: Float.random(in: 0...Float.pi),
                    y: Float.random(in: 0...Float.pi),
                    z: Float.random(in: 0...Float.pi)
                )
                scene.rootNode.addChildNode(shardNode)
                
                let rx = Float.random(in: -1.6...1.6)
                let ry = Float.random(in: 1.0...2.6)
                let rz = Float.random(in: -1.6...1.6)
                let launchPos = SCNVector3(x: pos.x + rx, y: pos.y + ry, z: pos.z + rz)
                let groundPos = SCNVector3(x: launchPos.x, y: 0.05, z: launchPos.z)
                
                let spin = SCNAction.rotateBy(
                    x: CGFloat(Float.random(in: -5...5)),
                    y: CGFloat(Float.random(in: -5...5)),
                    z: CGFloat(Float.random(in: -5...5)),
                    duration: 0.7
                )
                let fly = SCNAction.move(to: launchPos, duration: 0.22)
                fly.timingMode = .easeOut
                let fall = SCNAction.move(to: groundPos, duration: 0.38)
                fall.timingMode = .easeIn
                let fade = SCNAction.fadeOut(duration: 0.5)
                let remove = SCNAction.removeFromParentNode()
                
                shardNode.runAction(SCNAction.group([spin, SCNAction.sequence([fly, fall, fade, remove])]))
            }
            
            // Огненные частицы лавы
            for _ in 0..<12 {
                let emb = SCNSphere(radius: CGFloat.random(in: 0.02...0.045))
                let embMat = SCNMaterial()
                embMat.diffuse.contents = UIColor(red: 1.0, green: 0.35, blue: 0.0, alpha: 1.0)
                embMat.emission.contents = UIColor(red: 1.0, green: 0.2, blue: 0.0, alpha: 1.0)
                emb.materials = [embMat]
                let embNode = SCNNode(geometry: emb)
                embNode.position = pos
                scene.rootNode.addChildNode(embNode)
                
                let target = SCNVector3(
                    x: pos.x + Float.random(in: -1.8...1.8),
                    y: pos.y + Float.random(in: 0.8...3.5),
                    z: pos.z + Float.random(in: -1.8...1.8)
                )
                let embFly = SCNAction.move(to: target, duration: TimeInterval.random(in: 0.35...0.75))
                let embFade = SCNAction.fadeOut(duration: 0.4)
                let embRemove = SCNAction.removeFromParentNode()
                embNode.runAction(SCNAction.sequence([embFly, embFade, embRemove]))
            }
        }
        
        func punchCamera() {
            let originalPos = cameraNode.position
            let punchPos = SCNVector3(originalPos.x, originalPos.y - 0.35, originalPos.z - 0.35)
            let punch = SCNAction.move(to: punchPos, duration: 0.06)
            punch.timingMode = .easeOut
            let back = SCNAction.move(to: originalPos, duration: 0.22)
            back.timingMode = .easeInEaseOut
            cameraNode.runAction(SCNAction.sequence([punch, back]))
        }
        
        func updateCamera(perspective: ChessSceneView.CameraPerspective) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            switch perspective {
            case .isometric:
                cameraNode.position = SCNVector3(x: 3.5, y: 12.5, z: 11.2)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 3.4, y: 0, z: 0)
            case .topDown:
                cameraNode.position = SCNVector3(x: 3.5, y: 15.0, z: 3.5)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
            case .dynamic3D:
                cameraNode.position = SCNVector3(x: 9.5, y: 8.5, z: 9.5)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 5.5, y: Float.pi / 4, z: 0)
            }
            SCNTransaction.commit()
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            
            for hit in hitResults {
                if let name = hit.node.name, name.hasPrefix("tile_") {
                    let parts = name.split(separator: "_")
                    if parts.count == 3, let f = Int(parts[1]), let r = Int(parts[2]) {
                        engine.selectCoord(ChessCoord(file: f, rank: r))
                        return
                    }
                }
                
                var currNode: SCNNode? = hit.node
                while currNode != nil {
                    if let name = currNode?.name, name.hasPrefix("piece_") {
                        let uuidStr = String(name.dropFirst(6))
                        if let uuid = UUID(uuidString: uuidStr), let piece = engine.pieces.first(where: { $0.id == uuid }) {
                            engine.selectCoord(piece.coord)
                            return
                        }
                    }
                    currNode = currNode?.parent
                }
            }
        }
    }
}

// MARK: - Премиальный Glassmorphic UI (Точно по эталону)

struct ChessRootView: View {
    @StateObject private var engine = ChessGameEngine()
    @State private var cameraPerspective: ChessSceneView.CameraPerspective = .isometric
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 3D Metal Сцена (на весь экран)
            ChessSceneView(engine: engine, cameraPerspective: $cameraPerspective)
                .ignoresSafeArea()
            
            // UI Оверлей
            VStack {
                // ──────────────────────────────────────────
                // Верхняя панель: Таймеры + статус
                // ──────────────────────────────────────────
                HStack {
                    TimerCard(
                        title: "Белые",
                        timeSeconds: engine.whiteTime,
                        isActive: engine.currentTurn == .white
                    )
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("♚ CHESS 3D")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(engine.gameStatusMessage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(engine.currentTurn == .white ? .white : .yellow)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    TimerCard(
                        title: "Черные",
                        timeSeconds: engine.blackTime,
                        isActive: engine.currentTurn == .black
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                
                Spacer()
                
                // ──────────────────────────────────────────
                // Нижняя панель управления
                // ──────────────────────────────────────────
                VStack(spacing: 14) {
                    // Переключатель ракурса камеры
                    Picker("Камера", selection: $cameraPerspective) {
                        ForEach(ChessSceneView.CameraPerspective.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(8)
                    
                    // Кнопки: «Новая игра» и «Пауза»
                    HStack(spacing: 16) {
                        Button(action: {
                            engine.triggerHaptic(.medium)
                            engine.setupInitialBoard()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Новая игра")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(red: 0.62, green: 0.22, blue: 0.25).opacity(0.88))
                            )
                        }
                        
                        Button(action: {
                            engine.triggerHaptic(.light)
                            engine.isTimerRunning.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: engine.isTimerRunning ? "pause.fill" : "play.fill")
                                Text(engine.isTimerRunning ? "Пауза" : "Продолжить")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.16))
                            )
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }
}

// MARK: - Карточка таймера

struct TimerCard: View {
    let title: String
    let timeSeconds: Int
    let isActive: Bool
    
    var timeString: String {
        let m = timeSeconds / 60
        let s = timeSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? .white.opacity(0.8) : .gray)
            Text(timeString)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .white : .gray.opacity(0.55))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive
                      ? Color(red: 0.10, green: 0.32, blue: 0.55).opacity(0.88)
                      : Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.88)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? Color.cyan.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Точка входа в приложение

@main
struct Chess3DApp: App {
    var body: some Scene {
        WindowGroup {
            ChessRootView()
        }
    }
}
