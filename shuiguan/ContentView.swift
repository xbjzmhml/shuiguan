//
//  ContentView.swift
//  shuiguan
//
//  Created by xblogo on 2026/2/25.
//

import SwiftUI

private struct Pipe {
    let id: Int
    let inletIndex: Int
    let isCorrect: Bool
    let drawOrder: Int
    let points: [CGPoint]
    let wrongOutlet: CGPoint?
}

private struct MazeLevel {
    let pipes: [Pipe]
    let correctPipeID: Int
}

private struct RNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let v = CGFloat(next() & 0xFFFF_FFFF) / CGFloat(UInt32.max)
        return range.lowerBound + (range.upperBound - range.lowerBound) * v
    }

    mutating func shuffle<T>(_ values: inout [T]) {
        guard values.count > 1 else { return }
        for i in stride(from: values.count - 1, through: 1, by: -1) {
            let j = nextInt(i + 1)
            if i != j {
                values.swapAt(i, j)
            }
        }
    }
}

struct ContentView: View {
    @State private var activePipeID: Int? = nil
    @State private var waterProgress: CGFloat = 0
    @State private var lastResultCorrect: Bool = false
    @State private var levelSeed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)

    private let animationDuration: Double = 3.2
    private let inletCount = 6

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let inlets = inletPositions(count: inletCount)
            let level = buildLevel(inlets: inlets, seed: levelSeed)
            let pipes = level.pipes
            let pipeWidth = min(size.width, size.height) * 0.045

            ZStack {
                background(size: size)

                pipesLayer(pipes: pipes, size: size, pipeWidth: pipeWidth)
                waterLayer(pipes: pipes, size: size, pipeWidth: pipeWidth)

                outletMarkers(pipes: pipes, size: size)
                outletGlow(size: size, isActive: lastResultCorrect && waterProgress > 0.97)

                funnelsRow(inlets: inlets, size: size, activePipeID: activePipeID, pipes: pipes) { pipeID in
                    if activePipeID != pipeID {
                        activePipeID = pipeID
                        waterProgress = 0
                        lastResultCorrect = (pipeID == level.correctPipeID)
                        withAnimation(.linear(duration: animationDuration)) {
                            waterProgress = 1
                        }
                    }
                }

                Text("MAZE v16")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.25), in: Capsule())
                    .position(x: size.width * 0.15, y: size.height * 0.12)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if activePipeID != nil {
                    if lastResultCorrect {
                        levelSeed = nextSeed(from: levelSeed)
                    }
                    activePipeID = nil
                    waterProgress = 0
                    lastResultCorrect = false
                }
            }
        }
    }
}

private extension ContentView {
    func inletPositions(count: Int) -> [CGPoint] {
        let left: CGFloat = 0.08
        let right: CGFloat = 0.92
        let y: CGFloat = 0.09
        let step = (right - left) / CGFloat(max(count - 1, 1))
        return (0..<count).map { idx in
            CGPoint(x: left + CGFloat(idx) * step, y: y)
        }
    }

    func nextSeed(from old: UInt64) -> UInt64 {
        var x = old ^ UInt64(Date().timeIntervalSince1970 * 1000)
        x = x &* 2862933555777941757 &+ 3037000493
        return max(x, 1)
    }

    func buildLevel(inlets: [CGPoint], seed: UInt64) -> MazeLevel {
        var rng = RNG(state: max(seed, 1))

        let mazeTop: CGFloat = 0.24
        let mazeBottom: CGFloat = 0.81
        let outletY: CGFloat = 0.93
        let rows = 9
        let cols = 8

        var rowY = (0..<rows).map { i in
            mazeTop + CGFloat(i) * (mazeBottom - mazeTop) / CGFloat(rows - 1)
        }
        for i in 1..<(rows - 1) {
            rowY[i] += rng.nextCGFloat(in: -0.011...0.011)
        }

        var colX = (0..<cols).map { i in
            0.08 + CGFloat(i) * 0.84 / CGFloat(cols - 1)
        }
        let warpPhase = rng.nextCGFloat(in: 0...(2 * .pi))
        for i in 0..<cols {
            let t = CGFloat(i) / CGFloat(cols - 1)
            colX[i] += sin(t * .pi * 1.6 + warpPhase) * 0.012
        }

        let templates: [[(Int, Int)]] = [
            [(0, 0), (2, 2), (1, 4), (3, 6), (5, 4), (4, 2), (6, 1), (8, 2)],
            [(0, 1), (1, 3), (3, 1), (2, 4), (4, 6), (6, 5), (5, 3), (7, 1), (8, 0)],
            [(0, 2), (2, 5), (4, 3), (3, 6), (5, 7), (7, 5), (6, 3), (8, 4)],
            [(0, 3), (1, 6), (3, 4), (2, 1), (4, 2), (6, 4), (5, 6), (7, 7), (8, 6)],
            [(0, 4), (2, 6), (1, 3), (3, 2), (5, 0), (4, 2), (6, 4), (7, 5), (8, 5)],
            [(0, 5), (1, 7), (3, 5), (2, 2), (4, 1), (6, 3), (5, 5), (7, 6), (8, 7)],
            [(0, 6), (2, 4), (1, 2), (3, 0), (4, 2), (6, 1), (5, 3), (7, 4), (8, 3)],
            [(0, 7), (1, 5), (3, 7), (2, 4), (4, 3), (6, 6), (5, 4), (7, 2), (8, 1)]
        ]

        var templateOrder = Array(0..<templates.count)
        rng.shuffle(&templateOrder)
        let chosenTemplates = Array(templateOrder.prefix(inlets.count))

        let correctIndex = rng.nextInt(inlets.count)

        var wrongOutlets: [CGPoint] = [
            CGPoint(x: 0.07, y: 0.86),
            CGPoint(x: 0.18, y: 0.90),
            CGPoint(x: 0.31, y: 0.88),
            CGPoint(x: 0.69, y: 0.89),
            CGPoint(x: 0.82, y: 0.90),
            CGPoint(x: 0.93, y: 0.86),
            CGPoint(x: 0.05, y: 0.82),
            CGPoint(x: 0.95, y: 0.82)
        ]
        rng.shuffle(&wrongOutlets)
        var wrongOutletCursor = 0

        var pipes: [Pipe] = []
        pipes.reserveCapacity(inlets.count)

        for i in 0..<inlets.count {
            let template = templates[chosenTemplates[i]]
            let inlet = inlets[i]
            var points: [CGPoint] = []

            points.append(inlet)
            points.append(CGPoint(x: inlet.x, y: 0.16))
            points.append(CGPoint(x: inlet.x, y: 0.205))

            let firstNode = template[0]
            let firstX = colX[firstNode.1]
            points.append(CGPoint(x: mix(inlet.x, firstX, t: 0.42), y: 0.225))

            for (row, col) in template {
                var x = colX[col]
                var y = rowY[row]

                let wave = sin(CGFloat(row) * 0.95 + CGFloat(i) * 1.18 + CGFloat(seed % 997) * 0.001)
                x += wave * 0.017
                x += rng.nextCGFloat(in: -0.012...0.012)
                y += rng.nextCGFloat(in: -0.008...0.008)

                x = min(max(x, 0.06), 0.94)
                y = min(max(y, mazeTop + 0.005), mazeBottom)

                points.append(CGPoint(x: x, y: y))
            }

            points = removeCloseNeighbors(points: points, minDistance: 0.028)
            points = softenSharpTurns(points: points)
            points = removeCloseNeighbors(points: points, minDistance: 0.02)

            let isCorrect = (i == correctIndex)
            var wrongOutlet: CGPoint? = nil

            if isCorrect {
                let joinX = 0.5 + rng.nextCGFloat(in: -0.03...0.03)
                points.append(CGPoint(x: joinX, y: 0.835))
                points.append(CGPoint(x: 0.5, y: 0.865))
                points.append(CGPoint(x: 0.5, y: outletY))
            } else {
                let outlet = wrongOutlets[wrongOutletCursor % wrongOutlets.count]
                wrongOutletCursor += 1

                if let last = points.last {
                    let bridgeY = min(max(last.y + 0.05, 0.82), 0.89)
                    let bridgeX = mix(last.x, outlet.x, t: 0.6) + rng.nextCGFloat(in: -0.03...0.03)
                    points.append(CGPoint(x: min(max(bridgeX, 0.04), 0.96), y: bridgeY))
                }
                points.append(outlet)
                wrongOutlet = outlet
            }

            let drawOrder = rng.nextInt(1000)
            pipes.append(
                Pipe(
                    id: i,
                    inletIndex: i,
                    isCorrect: isCorrect,
                    drawOrder: drawOrder,
                    points: points,
                    wrongOutlet: wrongOutlet
                )
            )
        }

        return MazeLevel(pipes: pipes, correctPipeID: correctIndex)
    }

    func removeCloseNeighbors(points: [CGPoint], minDistance: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        var filtered: [CGPoint] = [points[0]]
        for point in points.dropFirst() {
            guard let last = filtered.last else { continue }
            let d = hypot(point.x - last.x, point.y - last.y)
            if d > minDistance {
                filtered.append(point)
            }
        }
        if filtered.count == 1, let last = points.last {
            filtered.append(last)
        }
        return filtered
    }

    func softenSharpTurns(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var result: [CGPoint] = [points[0]]

        for i in 1..<(points.count - 1) {
            guard let prev = result.last else { continue }
            let curr = points[i]
            let next = points[i + 1]

            let v1 = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
            let v2 = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
            let len1 = hypot(v1.dx, v1.dy)
            let len2 = hypot(v2.dx, v2.dy)

            if len1 < 0.001 || len2 < 0.001 {
                continue
            }

            let u1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
            let u2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
            let dotValue = min(max(u1.dx * u2.dx + u1.dy * u2.dy, -1), 1)
            let turn = acos(dotValue)

            // Replace >90deg turns with a wider two-step bend.
            if turn > (.pi / 2 + 0.08) {
                let cut = min(0.055, min(len1, len2) * 0.33)
                if cut > 0.008 {
                    let pin = CGPoint(x: curr.x - u1.dx * cut, y: curr.y - u1.dy * cut)
                    let pout = CGPoint(x: curr.x + u2.dx * cut, y: curr.y + u2.dy * cut)

                    let cross = u1.dx * u2.dy - u1.dy * u2.dx
                    let side: CGFloat = cross >= 0 ? 1 : -1
                    let perp = CGVector(dx: -u1.dy * side, dy: u1.dx * side)
                    let bridge = min(0.075, max(0.04, cut * 1.4))

                    let bend1 = clampMazePoint(
                        CGPoint(x: pin.x + perp.dx * bridge, y: pin.y + perp.dy * bridge)
                    )
                    let bend2 = clampMazePoint(
                        CGPoint(x: pout.x + perp.dx * bridge, y: pout.y + perp.dy * bridge)
                    )

                    result.append(pin)
                    result.append(bend1)
                    result.append(bend2)
                    result.append(pout)
                    continue
                }
            }

            // Near 90deg: widen the corner entrance/exit.
            if turn > (.pi / 2 - 0.05) {
                let cut = min(0.045, min(len1, len2) * 0.28)
                if cut > 0.008 {
                    let pin = CGPoint(x: curr.x - u1.dx * cut, y: curr.y - u1.dy * cut)
                    let pout = CGPoint(x: curr.x + u2.dx * cut, y: curr.y + u2.dy * cut)
                    result.append(pin)
                    result.append(pout)
                    continue
                }
            }

            result.append(curr)
        }

        result.append(points.last!)
        return result
    }

    func clampMazePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0.04), 0.96),
            y: min(max(point.y, 0.2), 0.9)
        )
    }

    func mix(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    func pipesLayer(pipes: [Pipe], size: CGSize, pipeWidth: CGFloat) -> some View {
        let ordered = pipes.sorted { lhs, rhs in
            if lhs.drawOrder == rhs.drawOrder {
                return lhs.id < rhs.id
            }
            return lhs.drawOrder < rhs.drawOrder
        }

        return ZStack {
            ForEach(ordered, id: \.id) { pipe in
                let path = pipePath(points: pipe.points, size: size)

                path
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.56, green: 0.72, blue: 0.88, opacity: 0.44),
                                Color(red: 0.28, green: 0.4, blue: 0.54, opacity: 0.38)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: pipeWidth, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 7, x: 0, y: 4)

                path
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: pipeWidth * 0.34, lineCap: .round, lineJoin: .round))
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }

    func waterLayer(pipes: [Pipe], size: CGSize, pipeWidth: CGFloat) -> some View {
        ZStack {
            if let activeID = activePipeID,
               let pipe = pipes.first(where: { $0.id == activeID }) {
                let path = pipePath(points: pipe.points, size: size)
                path
                    .trim(from: 0, to: waterProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.86, blue: 1.0),
                                Color(red: 0.72, green: 0.98, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: pipeWidth * 0.55, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color(red: 0.33, green: 0.92, blue: 1.0, opacity: 0.65), radius: 12, x: 0, y: 0)
                    .animation(.linear(duration: animationDuration), value: waterProgress)
            }
        }
        .allowsHitTesting(false)
    }

    func pipePath(points: [CGPoint], size: CGSize) -> Path {
        var path = Path()
        let scaled = points.map { scale($0, size: size) }

        guard scaled.count > 1 else { return path }
        if scaled.count == 2 {
            path.move(to: scaled[0])
            path.addLine(to: scaled[1])
            return path
        }

        path.move(to: scaled[0])

        let tension: CGFloat = 0.62

        for i in 0..<(scaled.count - 1) {
            let p0 = i == 0 ? scaled[0] : scaled[i - 1]
            let p1 = scaled[i]
            let p2 = scaled[i + 1]
            let p3 = (i + 2 < scaled.count) ? scaled[i + 2] : scaled[i + 1]

            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * tension / 6,
                y: p1.y + (p2.y - p0.y) * tension / 6
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * tension / 6,
                y: p2.y - (p3.y - p1.y) * tension / 6
            )

            path.addCurve(to: p2, control1: c1, control2: c2)
        }

        return path
    }

    func scale(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    func funnelsRow(
        inlets: [CGPoint],
        size: CGSize,
        activePipeID: Int?,
        pipes: [Pipe],
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        let funnelWidth = size.width * 0.07
        let funnelHeight = size.height * 0.08

        return ZStack {
            ForEach(Array(inlets.enumerated()), id: \.offset) { index, inlet in
                let pipeID = pipes.first { $0.inletIndex == index }?.id
                let isActive = (pipeID == activePipeID)
                let p = scale(inlet, size: size)

                FunnelView(isActive: isActive)
                    .frame(width: funnelWidth, height: funnelHeight)
                    .position(x: p.x, y: p.y)
                    .onTapGesture {
                        guard let pipeID else { return }
                        onSelect(pipeID)
                    }
            }
        }
    }

    func outletGlow(size: CGSize, isActive: Bool) -> some View {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.93)

        return ZStack {
            Circle()
                .fill(Color(red: 0.48, green: 1.0, blue: 0.75, opacity: isActive ? 0.82 : 0.34))
                .frame(width: size.width * 0.08, height: size.width * 0.08)
                .position(center)
                .shadow(color: Color(red: 0.4, green: 1.0, blue: 0.8, opacity: isActive ? 0.82 : 0.32),
                        radius: isActive ? 30 : 15,
                        x: 0,
                        y: 0)

            Circle()
                .stroke(Color.white.opacity(0.62), lineWidth: 2)
                .frame(width: size.width * 0.1, height: size.width * 0.1)
                .position(center)
        }
        .allowsHitTesting(false)
    }

    func outletMarkers(pipes: [Pipe], size: CGSize) -> some View {
        ZStack {
            ForEach(pipes.filter { !$0.isCorrect }, id: \.id) { pipe in
                if let outlet = pipe.wrongOutlet {
                    let p = scale(outlet, size: size)
                    Circle()
                        .fill(Color.white.opacity(0.34))
                        .frame(width: size.width * 0.035, height: size.width * 0.035)
                        .overlay(Circle().stroke(Color.white.opacity(0.58), lineWidth: 1))
                        .position(p)
                }
            }
        }
        .allowsHitTesting(false)
    }

    func background(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.1, green: 0.14, blue: 0.2),
                    Color(red: 0.13, green: 0.18, blue: 0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.45, opacity: 0.35),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 60,
                endRadius: min(size.width, size.height) * 0.6
            )

            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: size.width * 0.7, height: size.height * 0.25)
                .blur(radius: 40)
                .offset(x: -size.width * 0.1, y: -size.height * 0.25)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct FunnelView: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let topWidth = size.width * 0.8
            let bottomWidth = size.width * 0.45
            let height = size.height * 0.75
            let centerX = size.width * 0.5
            let topY: CGFloat = 0
            let bottomY = height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: centerX - topWidth * 0.5, y: topY))
                    path.addLine(to: CGPoint(x: centerX + topWidth * 0.5, y: topY))
                    path.addLine(to: CGPoint(x: centerX + bottomWidth * 0.5, y: bottomY))
                    path.addLine(to: CGPoint(x: centerX - bottomWidth * 0.5, y: bottomY))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.82, blue: 1.0, opacity: 0.7),
                            Color(red: 0.3, green: 0.45, blue: 0.62, opacity: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: centerX - topWidth * 0.5, y: topY))
                        path.addLine(to: CGPoint(x: centerX + topWidth * 0.5, y: topY))
                        path.addLine(to: CGPoint(x: centerX + bottomWidth * 0.5, y: bottomY))
                        path.addLine(to: CGPoint(x: centerX - bottomWidth * 0.5, y: bottomY))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )

                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: size.width * 0.28, height: size.width * 0.28)
                    .offset(y: size.height * 0.75)

                Circle()
                    .fill(Color(red: 0.35, green: 0.9, blue: 1.0, opacity: isActive ? 0.8 : 0.3))
                    .frame(width: size.width * 0.2, height: size.width * 0.2)
                    .offset(y: size.height * 0.75)
                    .shadow(color: Color(red: 0.3, green: 0.9, blue: 1.0, opacity: isActive ? 0.8 : 0.3),
                            radius: isActive ? 12 : 4,
                            x: 0,
                            y: 0)
            }
        }
    }
}
