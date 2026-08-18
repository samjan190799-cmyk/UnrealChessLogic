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

// MARK: - 3D Сцена Персонажей-Воинов и Доски (SceneKit & Metal)

@MainActor
struct ChessSceneView: UIViewRepresentable {
    @ObservedObject var engine: ChessGameEngine
    @Binding var cameraPerspective: CameraPerspective
    
    enum CameraPerspective: String, CaseIterable, Sendable {
        case isometric = "Игрок"
        case topDown = "Сверху"
        case dynamic3D = "3D Кинематограф"
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0)
        scnView.antialiasingMode = .multisampling4X
        
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
        
        func setupScene(scene: SCNScene, scnView: SCNView) {
            self.scene = scene
            self.scnView = scnView
            
            // Камера Top-Down Isometric (точно как на эталонном скриншоте)
            let camera = SCNCamera()
            camera.zNear = 0.5
            camera.zFar = 100
            camera.fieldOfView = 45
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(x: 3.5, y: 11.2, z: 9.8)
            cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 3.7, y: 0, z: 0)
            scene.rootNode.addChildNode(cameraNode)
            
            // Атмосферное и драматическое студийное освещение
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = UIColor(white: 0.32, alpha: 1.0)
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)
            
            let keyLight = SCNLight()
            keyLight.type = .directional
            keyLight.castsShadow = true
            keyLight.shadowMode = .deferred
            keyLight.shadowSampleCount = 16
            keyLight.shadowRadius = 4.0
            keyLight.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
            let keyLightNode = SCNNode()
            keyLightNode.light = keyLight
            keyLightNode.position = SCNVector3(x: 6.0, y: 15.0, z: 8.0)
            keyLightNode.eulerAngles = SCNVector3(x: -Float.pi / 3.0, y: Float.pi / 7.0, z: 0)
            scene.rootNode.addChildNode(keyLightNode)
            
            let fillLight = SCNLight()
            fillLight.type = .directional
            fillLight.color = UIColor(red: 0.4, green: 0.5, blue: 0.7, alpha: 0.4)
            let fillLightNode = SCNNode()
            fillLightNode.light = fillLight
            fillLightNode.position = SCNVector3(x: -6.0, y: 10.0, z: -4.0)
            fillLightNode.eulerAngles = SCNVector3(x: -Float.pi / 4.0, y: -Float.pi / 4.0, z: 0)
            scene.rootNode.addChildNode(fillLightNode)
            
            // Построение мраморной доски с координатами
            buildMarbleChessBoard(scene: scene)
            rebuildPieces()
        }
        
        func buildMarbleChessBoard(scene: SCNScene) {
            // Рама доски из темного полированного гранита
            let frameBox = SCNBox(width: 9.6, height: 0.45, length: 9.6, chamferRadius: 0.15)
            let frameMat = SCNMaterial()
            frameMat.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
            frameMat.roughness.contents = 0.25
            frameMat.metalness.contents = 0.2
            frameBox.materials = [frameMat]
            let frameNode = SCNNode(geometry: frameBox)
            frameNode.position = SCNVector3(x: 3.5, y: -0.25, z: 3.5)
            scene.rootNode.addChildNode(frameNode)
            
            // Мраморные плитки 8x8
            for f in 0..<8 {
                for r in 0..<8 {
                    let coord = ChessCoord(file: f, rank: r)
                    let tileBox = SCNBox(width: 0.98, height: 0.08, length: 0.98, chamferRadius: 0.02)
                    let isLight = (f + r) % 2 != 0
                    
                    let tileMat = SCNMaterial()
                    if isLight {
                        // Бежево-белый мрамор
                        tileMat.diffuse.contents = UIColor(red: 0.86, green: 0.83, blue: 0.78, alpha: 1.0)
                        tileMat.roughness.contents = 0.18
                    } else {
                        // Темный прожилковый мрамор
                        tileMat.diffuse.contents = UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1.0)
                        tileMat.roughness.contents = 0.22
                    }
                    tileBox.materials = [tileMat]
                    
                    let tileNode = SCNNode(geometry: tileBox)
                    tileNode.position = SCNVector3(x: Float(f), y: 0, z: Float(r))
                    tileNode.name = "tile_\(f)_\(r)"
                    scene.rootNode.addChildNode(tileNode)
                    tileNodes[coord] = tileNode
                }
            }
            
            // Нанесение координат a-h и 1-8 золотым тиснением
            let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
            for (idx, letter) in files.enumerated() {
                let textGeom = SCNText(string: letter, extrusionDepth: 0.02)
                textGeom.font = UIFont.systemFont(ofSize: 0.35, weight: .bold)
                textGeom.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.62, blue: 0.45, alpha: 1.0)
                let textNode = SCNNode(geometry: textGeom)
                textNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
                textNode.position = SCNVector3(x: Float(idx) - 0.1, y: 0.02, z: -0.7)
                scene.rootNode.addChildNode(textNode)
            }
            
            for rank in 1...8 {
                let textGeom = SCNText(string: "\(rank)", extrusionDepth: 0.02)
                textGeom.font = UIFont.systemFont(ofSize: 0.35, weight: .bold)
                textGeom.firstMaterial?.diffuse.contents = UIColor(red: 0.75, green: 0.62, blue: 0.45, alpha: 1.0)
                let textNode = SCNNode(geometry: textGeom)
                textNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: Float.pi / 2)
                textNode.position = SCNVector3(x: -0.7, y: 0.02, z: Float(rank - 1) + 0.1)
                scene.rootNode.addChildNode(textNode)
            }
        }
        
        func rebuildPieces() {
            guard let scene = scene else { return }
            for (_, node) in pieceNodes {
                node.removeFromParentNode()
            }
            pieceNodes.removeAll()
            
            for piece in engine.pieces {
                let pieceNode = createWarriorCharacterNode(piece: piece)
                pieceNode.position = SCNVector3(x: Float(piece.coord.file), y: 0.05, z: Float(piece.coord.rank))
                scene.rootNode.addChildNode(pieceNode)
                pieceNodes[piece.id] = pieceNode
            }
        }
        
        // MARK: - Генерация 3D Персонажей (Паладины / Темные Големы)
        
        func createWarriorCharacterNode(piece: Piece) -> SCNNode {
            let root = SCNNode()
            root.name = "piece_\(piece.id.uuidString)"
            
            let isWhite = piece.color == .white
            
            // Базовые материалы
            let stoneMat = SCNMaterial()
            let armorMat = SCNMaterial()
            let glowMat = SCNMaterial()
            
            if isWhite {
                // Светлый мрамор/камень с полированной золотой/бронзовой броней
                stoneMat.diffuse.contents = UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1.0)
                stoneMat.roughness.contents = 0.25
                
                armorMat.diffuse.contents = UIColor(red: 0.88, green: 0.68, blue: 0.38, alpha: 1.0) // Бронза/Золото
                armorMat.metalness.contents = 0.85
                armorMat.roughness.contents = 0.2
                
                glowMat.diffuse.contents = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
                glowMat.emission.contents = UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
            } else {
                // Черный обсидиан с раскаленным алым свечением
                stoneMat.diffuse.contents = UIColor(red: 0.10, green: 0.09, blue: 0.11, alpha: 1.0)
                stoneMat.roughness.contents = 0.3
                
                armorMat.diffuse.contents = UIColor(red: 0.18, green: 0.15, blue: 0.16, alpha: 1.0)
                armorMat.metalness.contents = 0.7
                armorMat.roughness.contents = 0.3
                
                glowMat.diffuse.contents = UIColor(red: 1.0, green: 0.15, blue: 0.05, alpha: 1.0)
                glowMat.emission.contents = UIColor(red: 1.0, green: 0.1, blue: 0.0, alpha: 1.0)
            }
            
            // Основание фигуры (Подставка)
            let baseCyl = SCNCylinder(radius: 0.36, height: 0.08)
            baseCyl.materials = [stoneMat]
            let baseNode = SCNNode(geometry: baseCyl)
            baseNode.position = SCNVector3(x: 0, y: 0.04, z: 0)
            root.addChildNode(baseNode)
            
            switch piece.type {
            case .pawn:
                buildPawnWarrior(into: root, isWhite: isWhite, stone: stoneMat, armor: armorMat, glow: glowMat)
            case .rook:
                buildRookGolem(into: root, isWhite: isWhite, stone: stoneMat, armor: armorMat, glow: glowMat)
            case .knight:
                buildKnightCavalry(into: root, isWhite: isWhite, stone: stoneMat, armor: armorMat, glow: glowMat)
            case .bishop:
                buildBishopCleric(into: root, isWhite: isWhite, stone: stoneMat, armor: armorMat, glow: glowMat)
            case .queen:
                buildQueenSorceress(into: root, isWhite: isWhite, stone: stoneMat, armor: armorMat, glow: glowMat)
            case .king:
                buildKingLord(into: root, isWhite: isWhite, stone: stoneMat, armor: armorMat, glow: glowMat)
            }
            
            return root
        }
        
        // 1. Пешка — воин с круглым щитом и копьем/мечом
        func buildPawnWarrior(into root: SCNNode, isWhite: Bool, stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial) {
            // Тело
            let body = SCNCapsule(capRadius: 0.16, height: 0.6)
            body.materials = [stone]
            let bodyNode = SCNNode(geometry: body)
            bodyNode.position = SCNVector3(x: 0, y: 0.38, z: 0)
            root.addChildNode(bodyNode)
            
            // Нагрудник/кираса
            let chest = SCNCylinder(radius: 0.19, height: 0.28)
            chest.materials = [armor]
            let chestNode = SCNNode(geometry: chest)
            chestNode.position = SCNVector3(x: 0, y: 0.36, z: 0)
            root.addChildNode(chestNode)
            
            // Шлем
            let helm = SCNSphere(radius: 0.14)
            helm.materials = [armor]
            let helmNode = SCNNode(geometry: helm)
            helmNode.position = SCNVector3(x: 0, y: 0.68, z: 0)
            root.addChildNode(helmNode)
            
            // Круглый щит в руке
            let shield = SCNCylinder(radius: 0.18, height: 0.04)
            shield.materials = [armor]
            let shieldNode = SCNNode(geometry: shield)
            shieldNode.eulerAngles = SCNVector3(x: Float.pi / 2, y: 0, z: -Float.pi / 5)
            shieldNode.position = SCNVector3(x: isWhite ? 0.22 : -0.22, y: 0.40, z: 0.12)
            root.addChildNode(shieldNode)
            
            // Оружие (Копье с навершием)
            let spear = SCNCylinder(radius: 0.025, height: 0.85)
            spear.materials = [stone]
            let spearNode = SCNNode(geometry: spear)
            spearNode.eulerAngles = SCNVector3(x: 0.1, y: 0, z: isWhite ? -0.2 : 0.2)
            spearNode.position = SCNVector3(x: isWhite ? -0.22 : 0.22, y: 0.48, z: 0.12)
            root.addChildNode(spearNode)
        }
        
        // 2. Ладья — Могучий Каменный Голем
        // Белый: щит-башня и молот (как на a1, h1). Черный: шипастые цепы/булавы на руках (как на a8, h8).
        func buildRookGolem(into root: SCNNode, isWhite: Bool, stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial) {
            // Массивный торс Голема
            let torso = SCNBox(width: 0.48, height: 0.55, length: 0.38, chamferRadius: 0.08)
            torso.materials = [stone]
            let torsoNode = SCNNode(geometry: torso)
            torsoNode.position = SCNVector3(x: 0, y: 0.42, z: 0)
            root.addChildNode(torsoNode)
            
            // Мощные наплечники
            for dx in [-0.28, 0.28] {
                let shoulder = SCNBox(width: 0.22, height: 0.22, length: 0.22, chamferRadius: 0.04)
                shoulder.materials = [armor]
                let shoulderNode = SCNNode(geometry: shoulder)
                shoulderNode.position = SCNVector3(x: Float(dx), y: 0.62, z: 0)
                root.addChildNode(shoulderNode)
            }
            
            // Каменная голова-монолит
            let head = SCNBox(width: 0.22, height: 0.20, length: 0.22, chamferRadius: 0.04)
            head.materials = [armor]
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(x: 0, y: 0.76, z: 0.04)
            root.addChildNode(headNode)
            
            // Светящиеся глаза
            let eye = SCNBox(width: 0.14, height: 0.04, length: 0.04, chamferRadius: 0.01)
            eye.materials = [glow]
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.position = SCNVector3(x: 0, y: 0.76, z: 0.16)
            root.addChildNode(eyeNode)
            
            if isWhite {
                // Башенный щит
                let towerShield = SCNBox(width: 0.32, height: 0.65, length: 0.06, chamferRadius: 0.02)
                towerShield.materials = [armor]
                let shieldNode = SCNNode(geometry: towerShield)
                shieldNode.position = SCNVector3(x: 0.30, y: 0.42, z: 0.18)
                root.addChildNode(shieldNode)
                
                // Боевой Молот
                let handle = SCNCylinder(radius: 0.03, height: 0.65)
                handle.materials = [stone]
                let hammerHead = SCNBox(width: 0.18, height: 0.18, length: 0.28, chamferRadius: 0.02)
                hammerHead.materials = [armor]
                let hNode = SCNNode(geometry: handle)
                let hhNode = SCNNode(geometry: hammerHead)
                hhNode.position = SCNVector3(x: 0, y: 0.28, z: 0)
                hNode.addChildNode(hhNode)
                hNode.position = SCNVector3(x: -0.30, y: 0.40, z: 0.15)
                root.addChildNode(hNode)
            } else {
                // Черный Голем с шипастыми цепами/булавами на цепях
                for dx in [-0.34, 0.34] {
                    let chain = SCNCylinder(radius: 0.02, height: 0.35)
                    chain.materials = [armor]
                    let flail = SCNSphere(radius: 0.12)
                    flail.materials = [armor]
                    
                    let cNode = SCNNode(geometry: chain)
                    let fNode = SCNNode(geometry: flail)
                    fNode.position = SCNVector3(x: 0, y: -0.22, z: 0.08)
                    cNode.addChildNode(fNode)
                    cNode.position = SCNVector3(x: Float(dx), y: 0.45, z: 0.22)
                    root.addChildNode(cNode)
                }
            }
        }
        
        // 3. Конь — Бронированный всадник / кентавр
        func buildKnightCavalry(into root: SCNNode, isWhite: Bool, stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial) {
            // Тело скакуна
            let horseBody = SCNCapsule(capRadius: 0.18, height: 0.55)
            horseBody.materials = [stone]
            let hbNode = SCNNode(geometry: horseBody)
            hbNode.eulerAngles = SCNVector3(x: Float.pi / 2.8, y: 0, z: 0)
            hbNode.position = SCNVector3(x: 0, y: 0.40, z: 0)
            root.addChildNode(hbNode)
            
            // Голова коня
            let horseHead = SCNCone(topRadius: 0.08, bottomRadius: 0.16, height: 0.35)
            horseHead.materials = [armor]
            let hhNode = SCNNode(geometry: horseHead)
            hhNode.eulerAngles = SCNVector3(x: -Float.pi / 3.5, y: 0, z: 0)
            hhNode.position = SCNVector3(x: 0, y: 0.68, z: 0.18)
            root.addChildNode(hhNode)
            
            // Всадник с мечом
            let rider = SCNCapsule(capRadius: 0.12, height: 0.38)
            rider.materials = [armor]
            let rNode = SCNNode(geometry: rider)
            rNode.position = SCNVector3(x: 0, y: 0.68, z: -0.06)
            root.addChildNode(rNode)
        }
        
        // 4. Слон — Боевой Маг/Клерик с пылающим факелом/посохом
        func buildBishopCleric(into root: SCNNode, isWhite: Bool, stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial) {
            // Мантия
            let robe = SCNCone(topRadius: 0.12, bottomRadius: 0.28, height: 0.75)
            robe.materials = [stone]
            let robeNode = SCNNode(geometry: robe)
            robeNode.position = SCNVector3(x: 0, y: 0.42, z: 0)
            root.addChildNode(robeNode)
            
            // Наплечники и капюшон/митра
            let hood = SCNCapsule(capRadius: 0.13, height: 0.28)
            hood.materials = [armor]
            let hoodNode = SCNNode(geometry: hood)
            hoodNode.position = SCNVector3(x: 0, y: 0.85, z: 0)
            root.addChildNode(hoodNode)
            
            // Посох с горящим факелом (Bishop Torchlight)
            let staff = SCNCylinder(radius: 0.025, height: 0.95)
            staff.materials = [armor]
            let staffNode = SCNNode(geometry: staff)
            staffNode.position = SCNVector3(x: isWhite ? -0.24 : 0.24, y: 0.52, z: 0.12)
            root.addChildNode(staffNode)
            
            // Пламя факела
            let flame = SCNSphere(radius: 0.08)
            flame.materials = [glow]
            let flameNode = SCNNode(geometry: flame)
            flameNode.position = SCNVector3(x: 0, y: 0.48, z: 0)
            staffNode.addChildNode(flameNode)
            
            // Локальный источник света от факела белого слона
            if isWhite {
                let torchLight = SCNLight()
                torchLight.type = .omni
                torchLight.color = UIColor(red: 1.0, green: 0.75, blue: 0.35, alpha: 1.0)
                torchLight.intensity = 400
                torchLight.attenuationEndDistance = 3.5
                flameNode.light = torchLight
            }
        }
        
        // 5. Королева — Боевая Чародейка/Дева в доспехах
        func buildQueenSorceress(into root: SCNNode, isWhite: Bool, stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial) {
            let gown = SCNCone(topRadius: 0.14, bottomRadius: 0.30, height: 0.85)
            gown.materials = [stone]
            let gownNode = SCNNode(geometry: gown)
            gownNode.position = SCNVector3(x: 0, y: 0.48, z: 0)
            root.addChildNode(gownNode)
            
            let crown = SCNCylinder(radius: 0.15, height: 0.12)
            crown.materials = [armor]
            let crownNode = SCNNode(geometry: crown)
            crownNode.position = SCNVector3(x: 0, y: 0.96, z: 0)
            root.addChildNode(crownNode)
            
            let gem = SCNSphere(radius: 0.06)
            gem.materials = [glow]
            let gemNode = SCNNode(geometry: gem)
            gemNode.position = SCNVector3(x: 0, y: 1.04, z: 0)
            root.addChildNode(gemNode)
        }
        
        // 6. Король — Верховный Повелитель в полных латах с великим мечом
        func buildKingLord(into root: SCNNode, isWhite: Bool, stone: SCNMaterial, armor: SCNMaterial, glow: SCNMaterial) {
            let torso = SCNBox(width: 0.42, height: 0.65, length: 0.32, chamferRadius: 0.06)
            torso.materials = [armor]
            let torsoNode = SCNNode(geometry: torso)
            torsoNode.position = SCNVector3(x: 0, y: 0.50, z: 0)
            root.addChildNode(torsoNode)
            
            // Накидка/плащ
            let cape = SCNBox(width: 0.44, height: 0.70, length: 0.06, chamferRadius: 0.02)
            cape.materials = [stone]
            let capeNode = SCNNode(geometry: cape)
            capeNode.position = SCNVector3(x: 0, y: 0.48, z: -0.18)
            root.addChildNode(capeNode)
            
            // Великий меч в руках (Broadsword)
            let swordBlade = SCNBox(width: 0.07, height: 0.88, length: 0.02, chamferRadius: 0.005)
            swordBlade.materials = [stone]
            let bladeNode = SCNNode(geometry: swordBlade)
            bladeNode.position = SCNVector3(x: 0.22, y: 0.58, z: 0.20)
            bladeNode.eulerAngles = SCNVector3(x: 0.1, y: 0, z: -0.15)
            root.addChildNode(bladeNode)
            
            // Корона Владыки
            let crown = SCNCylinder(radius: 0.16, height: 0.14)
            crown.materials = [armor]
            let crownNode = SCNNode(geometry: crown)
            crownNode.position = SCNVector3(x: 0, y: 1.02, z: 0)
            root.addChildNode(crownNode)
        }
        
        // MARK: - Подсветка ходов
        
        func syncBoardHighlights(legalMoves: [ChessCoord], selectedPiece: Piece?) {
            highlightNodes.forEach { $0.removeFromParentNode() }
            highlightNodes.removeAll()
            
            guard let scene = scene else { return }
            
            if let selected = selectedPiece, let pieceNode = pieceNodes[selected.id] {
                let ringGeom = SCNTorus(ringRadius: 0.44, pipeRadius: 0.035)
                let ringMat = SCNMaterial()
                ringMat.diffuse.contents = UIColor.systemCyan
                ringMat.emission.contents = UIColor.systemCyan
                ringGeom.materials = [ringMat]
                let ringNode = SCNNode(geometry: ringGeom)
                ringNode.position = SCNVector3(x: 0, y: 0.04, z: 0)
                pieceNode.addChildNode(ringNode)
                highlightNodes.append(ringNode)
            }
            
            for move in legalMoves {
                let markerGeom = SCNCylinder(radius: 0.18, height: 0.04)
                let markerMat = SCNMaterial()
                let isCapture = engine.pieceAt(move) != nil
                markerMat.diffuse.contents = isCapture ? UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.9) : UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 0.8)
                markerMat.emission.contents = isCapture ? UIColor.systemRed.withAlphaComponent(0.7) : UIColor.systemGreen.withAlphaComponent(0.7)
                markerGeom.materials = [markerMat]
                
                let markerNode = SCNNode(geometry: markerGeom)
                markerNode.position = SCNVector3(x: Float(move.file), y: 0.05, z: Float(move.rank))
                scene.rootNode.addChildNode(markerNode)
                highlightNodes.append(markerNode)
            }
        }
        
        // MARK: - Chaos Physics Разрушение (Белые: Кости/Золото, Черные: Лава/Обсидиан)
        
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
            
            // Параболическое перемещение фигуры
            let targetPos = SCNVector3(x: Float(targetCoord.file), y: 0.05, z: Float(targetCoord.rank))
            let liftPos = SCNVector3(x: (node.position.x + targetPos.x) / 2, y: 1.3, z: (node.position.z + targetPos.z) / 2)
            
            let moveUp = SCNAction.move(to: liftPos, duration: 0.18)
            moveUp.timingMode = .easeOut
            let moveDown = SCNAction.move(to: targetPos, duration: 0.18)
            moveDown.timingMode = .easeIn
            
            node.runAction(SCNAction.sequence([moveUp, moveDown]))
        }
        
        // 💥 Разрушение Белой фигуры (Древние кости, золотые пластины, искры)
        func spawnWhiteDestructionExplosion(at pos: SCNVector3) {
            guard let scene = scene else { return }
            for _ in 0..<18 {
                let shardGeom = SCNBox(width: 0.11, height: 0.11, length: 0.11, chamferRadius: 0.02)
                let shardMat = SCNMaterial()
                shardMat.diffuse.contents = UIColor(red: 0.92, green: 0.80, blue: 0.55, alpha: 1.0) // Золотисто-костяной
                shardMat.metalness.contents = 0.6
                shardGeom.materials = [shardMat]
                let shardNode = SCNNode(geometry: shardGeom)
                shardNode.position = pos
                scene.rootNode.addChildNode(shardNode)
                
                let rx = Float.random(in: -1.3...1.3)
                let ry = Float.random(in: 1.1...2.4)
                let rz = Float.random(in: -1.3...1.3)
                let launchPos = SCNVector3(x: pos.x + rx, y: pos.y + ry, z: pos.z + rz)
                let groundPos = SCNVector3(x: launchPos.x, y: 0.05, z: launchPos.z)
                
                let fly = SCNAction.move(to: launchPos, duration: 0.22)
                let fall = SCNAction.move(to: groundPos, duration: 0.32)
                let fade = SCNAction.fadeOut(duration: 0.5)
                let remove = SCNAction.removeFromParentNode()
                
                shardNode.runAction(SCNAction.sequence([fly, fall, fade, remove]))
            }
        }
        
        // 🔥 Разрушение Черной фигуры (Раскаленный обсидиан, лава, дым)
        func spawnBlackDestructionExplosion(at pos: SCNVector3) {
            guard let scene = scene else { return }
            for _ in 0..<20 {
                let shardGeom = SCNBox(width: 0.12, height: 0.12, length: 0.12, chamferRadius: 0.02)
                let shardMat = SCNMaterial()
                shardMat.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0) // Обсидиан
                shardMat.emission.contents = UIColor(red: 1.0, green: 0.25, blue: 0.0, alpha: 0.9) // Лава
                shardGeom.materials = [shardMat]
                let shardNode = SCNNode(geometry: shardGeom)
                shardNode.position = pos
                scene.rootNode.addChildNode(shardNode)
                
                let rx = Float.random(in: -1.4...1.4)
                let ry = Float.random(in: 1.2...2.6)
                let rz = Float.random(in: -1.4...1.4)
                let launchPos = SCNVector3(x: pos.x + rx, y: pos.y + ry, z: pos.z + rz)
                let groundPos = SCNVector3(x: launchPos.x, y: 0.05, z: launchPos.z)
                
                let fly = SCNAction.move(to: launchPos, duration: 0.22)
                let fall = SCNAction.move(to: groundPos, duration: 0.35)
                let fade = SCNAction.fadeOut(duration: 0.5)
                let remove = SCNAction.removeFromParentNode()
                
                shardNode.runAction(SCNAction.sequence([fly, fall, fade, remove]))
            }
        }
        
        func punchCamera() {
            let originalPos = cameraNode.position
            let punchPos = SCNVector3(originalPos.x, originalPos.y - 0.4, originalPos.z - 0.4)
            let punch = SCNAction.move(to: punchPos, duration: 0.07)
            let back = SCNAction.move(to: originalPos, duration: 0.18)
            cameraNode.runAction(SCNAction.sequence([punch, back]))
        }
        
        func updateCamera(perspective: CameraPerspective) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            switch perspective {
            case .isometric:
                cameraNode.position = SCNVector3(x: 3.5, y: 11.2, z: 9.8)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 3.7, y: 0, z: 0)
            case .topDown:
                cameraNode.position = SCNVector3(x: 3.5, y: 13.8, z: 3.5)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
            case .dynamic3D:
                cameraNode.position = SCNVector3(x: 8.5, y: 7.8, z: 8.5)
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

// MARK: - Премиальный Glassmorphic UI (В точности по эталону)

struct ChessRootView: View {
    @StateObject private var engine = ChessGameEngine()
    @State private var cameraPerspective: ChessSceneView.CameraPerspective = .isometric
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 3D Metal Сцена
            ChessSceneView(engine: engine, cameraPerspective: $cameraPerspective)
                .ignoresSafeArea()
            
            // UI Оверлей
            VStack {
                // Верхняя панель (Таймеры и статус в стиле скриншота)
                HStack {
                    TimerCard(title: "Белые", timeSeconds: engine.whiteTime, isActive: engine.currentTurn == .white)
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("♚ CHESS 3D")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(engine.gameStatusMessage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(engine.currentTurn == .white ? Color(red: 0.3, green: 0.8, blue: 0.9) : .yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    TimerCard(title: "Черные", timeSeconds: engine.blackTime, isActive: engine.currentTurn == .black)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                
                Spacer()
                
                // Нижняя панель управления
                VStack(spacing: 14) {
                    // Переключатель ракурса
                    Picker("Камера", selection: $cameraPerspective) {
                        ForEach(ChessSceneView.CameraPerspective.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
                    
                    // Кнопки действий (Новая игра / Пауза)
                    HStack(spacing: 16) {
                        Button(action: {
                            engine.triggerHaptic(.medium)
                            engine.setupInitialBoard()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Новая игра")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.65, green: 0.25, blue: 0.28).opacity(0.85))
                            .cornerRadius(14)
                        }
                        
                        Button(action: {
                            engine.triggerHaptic(.light)
                            engine.isTimerRunning.toggle()
                        }) {
                            HStack {
                                Image(systemName: engine.isTimerRunning ? "pause.fill" : "play.fill")
                                Text(engine.isTimerRunning ? "Пауза" : "Продолжить")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.16, green: 0.16, blue: 0.18).opacity(0.92))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }
}

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
                .foregroundColor(.gray)
            Text(timeString)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .white : .gray.opacity(0.65))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isActive ? Color(red: 0.12, green: 0.35, blue: 0.60).opacity(0.85) : Color(red: 0.18, green: 0.18, blue: 0.20).opacity(0.85))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.cyan.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
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
