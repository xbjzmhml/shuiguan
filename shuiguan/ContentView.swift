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

                Text("MAZE v23")
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

        let outletY: CGFloat = 0.93

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

        var upperRows: [CGFloat] = [0.30, 0.33, 0.36, 0.39, 0.42, 0.45]
        var middleRows: [CGFloat] = [0.50, 0.53, 0.56, 0.59, 0.62, 0.65]
        var lowerRows: [CGFloat] = [0.68, 0.71, 0.74, 0.77, 0.79, 0.81]
        var turnCols: [CGFloat] = [0.14, 0.24, 0.34, 0.66, 0.76, 0.86]
        var crossCols: [CGFloat] = [0.18, 0.29, 0.40, 0.60, 0.71, 0.82]
        var loopCols: [CGFloat] = [0.12, 0.26, 0.38, 0.62, 0.74, 0.88]
        var bottomRows: [CGFloat] = [0.83, 0.845, 0.86, 0.875, 0.89, 0.84]

        rng.shuffle(&upperRows)
        rng.shuffle(&middleRows)
        rng.shuffle(&lowerRows)
        rng.shuffle(&turnCols)
        rng.shuffle(&crossCols)
        rng.shuffle(&loopCols)
        rng.shuffle(&bottomRows)

        var pipes: [Pipe] = []
        pipes.reserveCapacity(inlets.count)

        func pushAway(_ value: CGFloat, from anchor: CGFloat, amount: CGFloat) -> CGFloat {
            if abs(value - anchor) >= amount { return value }
            let shifted = value + (value < anchor ? -amount : amount)
            return min(max(shifted, 0.08), 0.92)
        }

        for i in 0..<inlets.count {
            let inlet = inlets[i]
            var points: [CGPoint] = []
            // Align pipe start with funnel outlet so the top looks physically connected.
            let funnelBottomY = inlet.y + 0.02
            let pipeStartY = clampY(funnelBottomY - 0.004)
            let pipeNeckY = clampY(funnelBottomY + 0.048)

            let yUpper = clampY(upperRows[i % upperRows.count] + rng.nextCGFloat(in: -0.004...0.004))
            let yMiddle = clampY(max(yUpper + 0.12, middleRows[i % middleRows.count] + rng.nextCGFloat(in: -0.004...0.004)))
            let yLower = clampY(max(yMiddle + 0.11, lowerRows[i % lowerRows.count] + rng.nextCGFloat(in: -0.004...0.004)))

            var xTurn = turnCols[i % turnCols.count]
            var xCross = crossCols[i % crossCols.count]
            var xLoop = loopCols[i % loopCols.count]

            xTurn = pushAway(xTurn, from: inlet.x, amount: 0.11)
            xCross = pushAway(xCross, from: xTurn, amount: 0.12)
            xLoop = pushAway(xLoop, from: xCross, amount: 0.11)

            points.append(CGPoint(x: inlet.x, y: pipeStartY))
            points.append(CGPoint(x: inlet.x, y: pipeNeckY))
            points.append(CGPoint(x: inlet.x, y: 0.205))
            points.append(CGPoint(x: inlet.x, y: yUpper))
            points.append(CGPoint(x: xTurn, y: yUpper))
            points.append(CGPoint(x: xTurn, y: yMiddle))
            points.append(CGPoint(x: xCross, y: yMiddle))
            points.append(CGPoint(x: xCross, y: yLower))
            points.append(CGPoint(x: xLoop, y: yLower))

            // Use larger rectangular return loops instead of sharp foldbacks.
            if rng.nextInt(100) < 75 {
                let loopY1 = clampY((yUpper + yMiddle) * 0.5 + rng.nextCGFloat(in: -0.01...0.01))
                let loopY2 = clampY((yMiddle + yLower) * 0.5 + rng.nextCGFloat(in: -0.01...0.01))
                let xWide = clampX(xLoop + (xLoop < 0.5 ? 0.17 : -0.17) + rng.nextCGFloat(in: -0.02...0.02))

                points.append(CGPoint(x: xLoop, y: loopY1))
                points.append(CGPoint(x: xWide, y: loopY1))
                points.append(CGPoint(x: xWide, y: loopY2))
                points.append(CGPoint(x: xCross, y: loopY2))
            }

            let isCorrect = (i == correctIndex)
            var wrongOutlet: CGPoint? = nil

            if isCorrect {
                let joinX = clampX(0.5 + rng.nextCGFloat(in: -0.025...0.025))
                points.append(CGPoint(x: joinX, y: 0.835))
                points.append(CGPoint(x: 0.5, y: 0.865))
                points.append(CGPoint(x: 0.5, y: outletY))
            } else {
                let outlet = wrongOutlets[wrongOutletCursor % wrongOutlets.count]
                wrongOutletCursor += 1
                let bottomLane = clampY(bottomRows[i % bottomRows.count] + rng.nextCGFloat(in: -0.004...0.004))
                points.append(CGPoint(x: xLoop, y: bottomLane))
                points.append(CGPoint(x: outlet.x, y: bottomLane))
                points.append(outlet)
                wrongOutlet = outlet
            }

            points = points.map(clampMazePoint)
            points = removeCloseNeighbors(points: points, minDistance: 0.02)
            points = collapseLinearSegments(points: points)

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

    func orthogonalizePath(points: [CGPoint], pipeIndex: Int, rng: inout RNG) -> [CGPoint] {
        guard points.count > 1 else { return points }

        struct Candidate {
            let pivots: [CGPoint]
            let firstDir: CGVector
            let lastDir: CGVector
            let cost: CGFloat
        }

        func normalized(_ v: CGVector) -> CGVector {
            let len = max(hypot(v.dx, v.dy), 0.001)
            return CGVector(dx: v.dx / len, dy: v.dy / len)
        }

        var result: [CGPoint] = [points[0]]
        var prevDir = CGVector(dx: 0, dy: 1)
        let laneCenter = CGFloat(max(inletCount - 1, 1)) * 0.5
        let laneBias = (CGFloat(pipeIndex) - laneCenter) * 0.03

        for idx in 1..<points.count {
            guard let from = result.last else { continue }
            let to = clampMazePoint(points[idx])
            let dx = to.x - from.x
            let dy = to.y - from.y
            if hypot(dx, dy) < 0.003 { continue }

            if abs(dx) < 0.004 || abs(dy) < 0.004 {
                result.append(to)
                prevDir = CGVector(dx: dx, dy: dy)
                continue
            }

            let horizontalPivot = clampMazePoint(CGPoint(x: to.x, y: from.y))
            let verticalPivot = clampMazePoint(CGPoint(x: from.x, y: to.y))

            func candidate(horizontalFirst: Bool) -> Candidate {
                if horizontalFirst {
                    let first = CGVector(dx: horizontalPivot.x - from.x, dy: 0)
                    let last = CGVector(dx: 0, dy: to.y - horizontalPivot.y)
                    var cost: CGFloat = 0
                    let dot = normalized(prevDir).dx * normalized(first).dx + normalized(prevDir).dy * normalized(first).dy
                    if dot < -0.3 { cost += 3.5 }
                    if abs(first.dx) < 0.05 { cost += 0.8 }
                    cost += abs(horizontalPivot.x - (0.5 + laneBias)) * 0.16
                    return Candidate(pivots: [horizontalPivot], firstDir: first, lastDir: last, cost: cost)
                } else {
                    let first = CGVector(dx: 0, dy: verticalPivot.y - from.y)
                    let last = CGVector(dx: to.x - verticalPivot.x, dy: 0)
                    var cost: CGFloat = 0
                    let dot = normalized(prevDir).dx * normalized(first).dx + normalized(prevDir).dy * normalized(first).dy
                    if dot < -0.3 { cost += 3.5 }
                    if abs(first.dy) < 0.05 { cost += 0.8 }
                    cost += abs(verticalPivot.x - (0.5 + laneBias)) * 0.1
                    return Candidate(pivots: [verticalPivot], firstDir: first, lastDir: last, cost: cost)
                }
            }

            let h = candidate(horizontalFirst: true)
            let v = candidate(horizontalFirst: false)
            let pickHorizontal = h.cost + rng.nextCGFloat(in: 0...0.03) < v.cost + rng.nextCGFloat(in: 0...0.03)
            let chosen = pickHorizontal ? h : v

            result.append(contentsOf: chosen.pivots)
            result.append(to)
            prevDir = chosen.lastDir
        }

        return collapseLinearSegments(points: result)
    }

    func expandLargeLoops(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var out: [CGPoint] = [points[0]]

        for i in 1..<(points.count - 1) {
            guard let prev = out.last else { continue }
            let curr = points[i]
            let next = points[i + 1]

            let v1 = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
            let v2 = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
            let len1 = max(hypot(v1.dx, v1.dy), 0.001)
            let len2 = max(hypot(v2.dx, v2.dy), 0.001)
            let n1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
            let n2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
            let cross = abs(n1.dx * n2.dy - n1.dy * n2.dx)
            let dot = n1.dx * n2.dx + n1.dy * n2.dy

            // Reverse direction: replace with wider U-shaped loop made from 90-degree turns.
            if cross < 0.05 && dot < -0.2 {
                let span = min(0.13, max(0.075, (len1 + len2) * 0.44))
                if abs(n1.dx) > abs(n1.dy) {
                    let side: CGFloat = curr.y < 0.55 ? 1 : -1
                    let yLoop = clampY(curr.y + side * span)
                    out.append(clampMazePoint(CGPoint(x: curr.x, y: yLoop)))
                    out.append(clampMazePoint(CGPoint(x: next.x, y: yLoop)))
                } else {
                    let side: CGFloat = curr.x < 0.5 ? 1 : -1
                    let xLoop = clampX(curr.x + side * span)
                    out.append(clampMazePoint(CGPoint(x: xLoop, y: curr.y)))
                    out.append(clampMazePoint(CGPoint(x: xLoop, y: next.y)))
                }
                continue
            }

            out.append(curr)
        }

        if let last = points.last {
            out.append(last)
        }
        return collapseLinearSegments(points: out)
    }

    func collapseLinearSegments(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var cleaned: [CGPoint] = [points[0]]

        for i in 1..<(points.count - 1) {
            guard let a = cleaned.last else { continue }
            let b = points[i]
            let c = points[i + 1]

            let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            let bc = CGVector(dx: c.x - b.x, dy: c.y - b.y)
            if hypot(ab.dx, ab.dy) < 0.003 { continue }
            let cross = abs(ab.dx * bc.dy - ab.dy * bc.dx)
            if cross < 0.0005 { continue }
            cleaned.append(b)
        }

        if let last = points.last {
            cleaned.append(last)
        }
        return cleaned
    }

    func clampMazePoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: clampX(point.x), y: clampY(point.y))
    }

    func clampX(_ x: CGFloat) -> CGFloat {
        min(max(x, 0.04), 0.96)
    }

    func clampY(_ y: CGFloat) -> CGFloat {
        min(max(y, 0.09), 0.9)
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
        let radius = min(size.width, size.height) * 0.042

        for i in 1..<(scaled.count - 1) {
            let prev = scaled[i - 1]
            let curr = scaled[i]
            let next = scaled[i + 1]

            let v1 = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
            let v2 = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
            let len1 = max(hypot(v1.dx, v1.dy), 0.001)
            let len2 = max(hypot(v2.dx, v2.dy), 0.001)

            let n1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
            let n2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
            let dot = n1.dx * n2.dx + n1.dy * n2.dy

            if abs(abs(dot) - 1) < 0.01 {
                path.addLine(to: curr)
                continue
            }

            let r = min(radius, len1 * 0.45, len2 * 0.45)
            let inPoint = CGPoint(x: curr.x - n1.dx * r, y: curr.y - n1.dy * r)
            let outPoint = CGPoint(x: curr.x + n2.dx * r, y: curr.y + n2.dy * r)

            path.addLine(to: inPoint)
            path.addQuadCurve(to: outPoint, control: curr)
        }

        if let last = scaled.last {
            path.addLine(to: last)
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
                    .offset(y: size.height * 0.25)

                Circle()
                    .fill(Color(red: 0.35, green: 0.9, blue: 1.0, opacity: isActive ? 0.8 : 0.3))
                    .frame(width: size.width * 0.2, height: size.width * 0.2)
                    .offset(y: size.height * 0.25)
                    .shadow(color: Color(red: 0.3, green: 0.9, blue: 1.0, opacity: isActive ? 0.8 : 0.3),
                            radius: isActive ? 12 : 4,
                            x: 0,
                            y: 0)
            }
        }
    }
}
