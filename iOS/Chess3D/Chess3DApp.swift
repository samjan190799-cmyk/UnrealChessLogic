import SwiftUI
import SceneKit
import UIKit

// MARK: - Модели шахматной логики

enum PieceColor: String {
    case white, black
    
    var opposite: PieceColor {
        self == .white ? .black : .white
    }
}

enum PieceType: String {
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

struct ChessCoord: Hashable, Equatable {
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

struct Piece: Identifiable, Equatable {
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

// MARK: - Состояние игры (Game Engine)

@MainActor
class ChessGameEngine: ObservableObject {
    @Published var pieces: [Piece] = []
    @Published var selectedPiece: Piece? = nil
    @Published var legalMoves: [ChessCoord] = []
    @Published var currentTurn: PieceColor = .white
    @Published var whiteTime: Int = 300 // 5 минут
    @Published var blackTime: Int = 300
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
        whiteTime = 300
        blackTime = 300
        gameStatusMessage = "Ход Белых"
        selectedPiece = nil
        legalMoves.removeAll()
        
        // Расстановка пешек
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
            // Атаки по диагонали
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

// MARK: - 3D SceneKit Шахматная сцена

struct ChessSceneView: UIViewRepresentable {
    @ObservedObject var engine: ChessGameEngine
    @Binding var cameraPerspective: CameraPerspective
    
    enum CameraPerspective: String, CaseIterable {
        case player = "Игрок"
        case topDown = "Сверху"
        case dynamic3D = "3D Кинематограф"
    }
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
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
            
            // Камера
            let camera = SCNCamera()
            camera.zNear = 0.5
            camera.zFar = 100
            camera.fieldOfView = 50
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(x: 3.5, y: 10.5, z: 10.0)
            cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 4.2, y: 0, z: 0)
            scene.rootNode.addChildNode(cameraNode)
            
            // Освещение (Cinematic Lighting)
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.color = UIColor(white: 0.35, alpha: 1.0)
            let ambientNode = SCNNode()
            ambientNode.light = ambientLight
            scene.rootNode.addChildNode(ambientNode)
            
            let mainLight = SCNLight()
            mainLight.type = .directional
            mainLight.castsShadow = true
            mainLight.shadowMode = .deferred
            mainLight.shadowSampleCount = 8
            mainLight.color = UIColor(white: 0.85, alpha: 1.0)
            let mainLightNode = SCNNode()
            mainLightNode.light = mainLight
            mainLightNode.position = SCNVector3(x: 8, y: 16, z: 10)
            mainLightNode.eulerAngles = SCNVector3(x: -Float.pi / 3, y: Float.pi / 6, z: 0)
            scene.rootNode.addChildNode(mainLightNode)
            
            // Доска
            buildChessBoard(scene: scene)
            rebuildPieces()
        }
        
        func buildChessBoard(scene: SCNScene) {
            // Основание доски (Frame)
            let baseBox = SCNBox(width: 9.2, height: 0.5, length: 9.2, chamferRadius: 0.2)
            let baseMat = SCNMaterial()
            baseMat.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1.0)
            baseMat.roughness.contents = 0.4
            baseBox.materials = [baseMat]
            let baseNode = SCNNode(geometry: baseBox)
            baseNode.position = SCNVector3(x: 3.5, y: -0.3, z: 3.5)
            scene.rootNode.addChildNode(baseNode)
            
            // Клетки 8x8
            for f in 0..<8 {
                for r in 0..<8 {
                    let coord = ChessCoord(file: f, rank: r)
                    let tileBox = SCNBox(width: 0.96, height: 0.1, length: 0.96, chamferRadius: 0.04)
                    let isLight = (f + r) % 2 != 0
                    
                    let tileMat = SCNMaterial()
                    if isLight {
                        tileMat.diffuse.contents = UIColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1.0)
                        tileMat.roughness.contents = 0.2
                    } else {
                        tileMat.diffuse.contents = UIColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
                        tileMat.roughness.contents = 0.3
                    }
                    tileBox.materials = [tileMat]
                    
                    let tileNode = SCNNode(geometry: tileBox)
                    tileNode.position = SCNVector3(x: Float(f), y: 0, z: Float(r))
                    tileNode.name = "tile_\(f)_\(r)"
                    scene.rootNode.addChildNode(tileNode)
                    tileNodes[coord] = tileNode
                }
            }
        }
        
        func rebuildPieces() {
            guard let scene = scene else { return }
            for (_, node) in pieceNodes {
                node.removeFromParentNode()
            }
            pieceNodes.removeAll()
            
            for piece in engine.pieces {
                let pieceNode = createPieceNode(piece: piece)
                pieceNode.position = SCNVector3(x: Float(piece.coord.file), y: 0.1, z: Float(piece.coord.rank))
                scene.rootNode.addChildNode(pieceNode)
                pieceNodes[piece.id] = pieceNode
            }
        }
        
        func createPieceNode(piece: Piece) -> SCNNode {
            let container = SCNNode()
            container.name = "piece_\(piece.id.uuidString)"
            
            let (height, radius, geomType) = geometryParams(for: piece.type)
            var geom: SCNGeometry
            
            switch geomType {
            case .cylinder:
                geom = SCNCylinder(radius: radius, height: height)
            case .cone:
                geom = SCNCone(topRadius: radius * 0.4, bottomRadius: radius, height: height)
            case .capsule:
                geom = SCNCapsule(capRadius: radius * 0.7, height: height)
            case .pyramid:
                geom = SCNPyramid(width: radius * 2, length: radius * 2, height: height)
            }
            
            let mat = SCNMaterial()
            if piece.color == .white {
                mat.diffuse.contents = UIColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1.0)
                mat.roughness.contents = 0.15
                mat.metalness.contents = 0.1
            } else {
                mat.diffuse.contents = UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1.0)
                mat.roughness.contents = 0.25
                mat.metalness.contents = 0.3
            }
            geom.materials = [mat]
            
            let meshNode = SCNNode(geometry: geom)
            meshNode.position = SCNVector3(x: 0, y: Float(height / 2), z: 0)
            meshNode.castsShadow = true
            container.addChildNode(meshNode)
            
            // Корона / символ
            let crownGeom = SCNSphere(radius: radius * 0.45)
            crownGeom.firstMaterial?.diffuse.contents = piece.color == .white ? UIColor.white : UIColor.black
            let crownNode = SCNNode(geometry: crownGeom)
            crownNode.position = SCNVector3(x: 0, y: Float(height + 0.1), z: 0)
            container.addChildNode(crownNode)
            
            return container
        }
        
        enum GeomType { case cylinder, cone, capsule, pyramid }
        
        func geometryParams(for type: PieceType) -> (CGFloat, CGFloat, GeomType) {
            switch type {
            case .pawn: return (0.7, 0.24, .cone)
            case .knight: return (0.9, 0.28, .pyramid)
            case .bishop: return (1.0, 0.28, .cone)
            case .rook: return (0.85, 0.30, .cylinder)
            case .queen: return (1.2, 0.32, .capsule)
            case .king: return (1.35, 0.34, .capsule)
            }
        }
        
        func syncBoardHighlights(legalMoves: [ChessCoord], selectedPiece: Piece?) {
            // Удаляем старые индикаторы
            highlightNodes.forEach { $0.removeFromParentNode() }
            highlightNodes.removeAll()
            
            guard let scene = scene else { return }
            
            // Подсветка выбранной фигуры
            if let selected = selectedPiece, let pieceNode = pieceNodes[selected.id] {
                let ringGeom = SCNTorus(ringRadius: 0.45, pipeRadius: 0.04)
                let ringMat = SCNMaterial()
                ringMat.diffuse.contents = UIColor.systemCyan
                ringMat.emission.contents = UIColor.systemCyan
                ringGeom.materials = [ringMat]
                let ringNode = SCNNode(geometry: ringGeom)
                ringNode.position = SCNVector3(x: 0, y: 0.05, z: 0)
                pieceNode.addChildNode(ringNode)
                highlightNodes.append(ringNode)
            }
            
            // Подсветка возможных ходов
            for move in legalMoves {
                let markerGeom = SCNCylinder(radius: 0.18, height: 0.06)
                let markerMat = SCNMaterial()
                let isCapture = engine.pieceAt(move) != nil
                markerMat.diffuse.contents = isCapture ? UIColor.systemRed : UIColor.systemGreen
                markerMat.emission.contents = isCapture ? UIColor.systemRed.withAlphaComponent(0.6) : UIColor.systemGreen.withAlphaComponent(0.6)
                markerGeom.materials = [markerMat]
                
                let markerNode = SCNNode(geometry: markerGeom)
                markerNode.position = SCNVector3(x: Float(move.file), y: 0.06, z: Float(move.rank))
                scene.rootNode.addChildNode(markerNode)
                highlightNodes.append(markerNode)
            }
        }
        
        func animateMove(piece: Piece, to targetCoord: ChessCoord, captured: Piece?) {
            guard let node = pieceNodes[piece.id] else { return }
            
            // Эффект разрушения при взятии (Chaos Destruction Particles)
            if let captured = captured, let capNode = pieceNodes[captured.id] {
                spawnDestructionExplosion(at: capNode.position)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.25
                capNode.opacity = 0.0
                capNode.scale = SCNVector3(0.01, 0.01, 0.01)
                SCNTransaction.commit()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    capNode.removeFromParentNode()
                    self.pieceNodes.removeValue(forKey: captured.id)
                }
                punchCamera()
            }
            
            // Параболическая плавная анимация перемещения (EaseInOut)
            let targetPos = SCNVector3(x: Float(targetCoord.file), y: 0.1, z: Float(targetCoord.rank))
            let liftPos = SCNVector3(x: (node.position.x + targetPos.x) / 2, y: 1.2, z: (node.position.z + targetPos.z) / 2)
            
            let moveUp = SCNAction.move(to: liftPos, duration: 0.18)
            moveUp.timingMode = .easeOut
            let moveDown = SCNAction.move(to: targetPos, duration: 0.18)
            moveDown.timingMode = .easeIn
            
            node.runAction(SCNAction.sequence([moveUp, moveDown]))
        }
        
        func spawnDestructionExplosion(at pos: SCNVector3) {
            guard let scene = scene else { return }
            for _ in 0..<14 {
                let shardGeom = SCNBox(width: 0.12, height: 0.12, length: 0.12, chamferRadius: 0.02)
                let shardMat = SCNMaterial()
                shardMat.diffuse.contents = UIColor(white: 0.8, alpha: 1.0)
                shardGeom.materials = [shardMat]
                let shardNode = SCNNode(geometry: shardGeom)
                shardNode.position = pos
                scene.rootNode.addChildNode(shardNode)
                
                let rx = Float.random(in: -1.2...1.2)
                let ry = Float.random(in: 1.0...2.2)
                let rz = Float.random(in: -1.2...1.2)
                let launchPos = SCNVector3(x: pos.x + rx, y: pos.y + ry, z: pos.z + rz)
                let groundPos = SCNVector3(x: launchPos.x, y: 0.05, z: launchPos.z)
                
                let fly = SCNAction.move(to: launchPos, duration: 0.22)
                let fall = SCNAction.move(to: groundPos, duration: 0.3)
                let fade = SCNAction.fadeOut(duration: 0.4)
                let remove = SCNAction.removeFromParentNode()
                
                shardNode.runAction(SCNAction.sequence([fly, fall, fade, remove]))
            }
        }
        
        func punchCamera() {
            let originalPos = cameraNode.position
            let punchPos = SCNVector3(originalPos.x, originalPos.y - 0.4, originalPos.z - 0.4)
            let punch = SCNAction.move(to: punchPos, duration: 0.08)
            let back = SCNAction.move(to: originalPos, duration: 0.18)
            cameraNode.runAction(SCNAction.sequence([punch, back]))
        }
        
        func updateCamera(perspective: CameraPerspective) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            switch perspective {
            case .player:
                cameraNode.position = SCNVector3(x: 3.5, y: 10.5, z: 10.0)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 4.2, y: 0, z: 0)
            case .topDown:
                cameraNode.position = SCNVector3(x: 3.5, y: 14.0, z: 3.5)
                cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
            case .dynamic3D:
                cameraNode.position = SCNVector3(x: 8.5, y: 7.5, z: 8.5)
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
                
                // Клик по фигуре
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

// MARK: - Главный экран (Glassmorphic UI)

struct ChessRootView: View {
    @StateObject private var engine = ChessGameEngine()
    @State private var cameraPerspective: ChessSceneView.CameraPerspective = .player
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 3D Metal Сцена
            ChessSceneView(engine: engine, cameraPerspective: $cameraPerspective)
                .ignoresSafeArea()
            
            // UI Оверлей
            VStack {
                // Верхняя панель (Таймеры и статус)
                HStack {
                    TimerCard(title: "Белые", timeSeconds: engine.whiteTime, isActive: engine.currentTurn == .white)
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("♚ CHESS 3D")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(engine.gameStatusMessage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(engine.currentTurn == .white ? .cyan : .yellow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    TimerCard(title: "Черные", timeSeconds: engine.blackTime, isActive: engine.currentTurn == .black)
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                
                Spacer()
                
                // Нижняя панель управления
                VStack(spacing: 12) {
                    // Переключатель камеры
                    Picker("Камера", selection: $cameraPerspective) {
                        ForEach(ChessSceneView.CameraPerspective.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
                    
                    // Кнопки действий
                    HStack(spacing: 16) {
                        Button(action: {
                            engine.triggerHaptic(.medium)
                            engine.setupInitialBoard()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Новая игра")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.35))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.6), lineWidth: 1))
                        }
                        
                        Button(action: {
                            engine.triggerHaptic(.light)
                            engine.isTimerRunning.toggle()
                        }) {
                            HStack {
                                Image(systemName: engine.isTimerRunning ? "pause.fill" : "play.fill")
                                Text(engine.isTimerRunning ? "Пауза" : "Продолжить")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
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
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            Text(timeString)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .white : .gray.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? Color.blue.opacity(0.35) : Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.cyan.opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
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
