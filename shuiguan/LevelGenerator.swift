import CoreGraphics
import Foundation

struct LevelGenerator {
    let inletCount: Int
    private let validator = LevelValidator()

    init(inletCount: Int = 6) {
        self.inletCount = inletCount
    }

    func inletPositions() -> [CGPoint] {
        let left: CGFloat = 0.08
        let right: CGFloat = 0.92
        let y: CGFloat = 0.09
        let step = (right - left) / CGFloat(max(inletCount - 1, 1))
        return (0..<inletCount).map { idx in
            CGPoint(x: left + CGFloat(idx) * step, y: y)
        }
    }

    func nextSeed(from old: UInt64) -> UInt64 {
        // Deterministic seed step: same input seed always yields same next level.
        var x = old &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)
        return max(x, 1)
    }

    func generate(seed: UInt64) -> (inlets: [CGPoint], level: MazeLevel, resolvedSeed: UInt64) {
        let inlets = inletPositions()
        var candidateSeed = max(seed, 1)
        let mainOutlet = CGPoint(x: 0.5, y: 0.93)
        var bestLevel: MazeLevel?
        var bestSeed: UInt64 = candidateSeed
        var bestPenalty: CGFloat = .greatestFiniteMagnitude

        for _ in 0..<60 {
            let level = buildLevel(inlets: inlets, seed: candidateSeed)
            let result = validator.evaluate(
                level: level,
                inletCount: inletCount,
                inlets: inlets,
                mainOutlet: mainOutlet
            )

            if result.penalty < bestPenalty {
                bestPenalty = result.penalty
                bestLevel = level
                bestSeed = candidateSeed
            }

            if result.isValid {
                return (inlets, level, candidateSeed)
            }
            candidateSeed = nextSeed(from: candidateSeed)
        }

        if let bestLevel {
            return (inlets, bestLevel, bestSeed)
        }
        return (inlets, buildLevel(inlets: inlets, seed: candidateSeed), candidateSeed)
    }
}

private extension LevelGenerator {
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

            // Start from the funnel outlet so the pipe visually connects to the funnel.
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
            let distance = hypot(point.x - last.x, point.y - last.y)
            if distance > minDistance {
                filtered.append(point)
            }
        }

        if filtered.count == 1, let last = points.last {
            filtered.append(last)
        }

        return filtered
    }

    func collapseLinearSegments(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var cleaned: [CGPoint] = [points[0]]
        for i in 1..<(points.count - 1) {
            guard let previous = cleaned.last else { continue }
            let current = points[i]
            let next = points[i + 1]

            let ab = CGVector(dx: current.x - previous.x, dy: current.y - previous.y)
            let bc = CGVector(dx: next.x - current.x, dy: next.y - current.y)
            if hypot(ab.dx, ab.dy) < 0.003 { continue }
            let cross = abs(ab.dx * bc.dy - ab.dy * bc.dx)
            if cross < 0.0005 { continue }
            cleaned.append(current)
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
}
