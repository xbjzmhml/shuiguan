import CoreGraphics

struct LevelValidation {
    let isValid: Bool
    let penalty: CGFloat
}

struct LevelValidator {
    func evaluate(
        level: MazeLevel,
        inletCount: Int,
        inlets: [CGPoint],
        mainOutlet: CGPoint
    ) -> LevelValidation {
        guard level.pipes.count == inletCount else {
            return LevelValidation(isValid: false, penalty: 999)
        }

        guard inlets.count == inletCount else {
            return LevelValidation(isValid: false, penalty: 999)
        }

        let idSet = Set(level.pipes.map { $0.id })
        guard idSet.count == level.pipes.count else {
            return LevelValidation(isValid: false, penalty: 999)
        }

        let inletSet = Set(level.pipes.map { $0.inletIndex })
        guard inletSet.count == inletCount else {
            return LevelValidation(isValid: false, penalty: 999)
        }

        let correctPipes = level.pipes.filter { $0.isCorrect }
        guard correctPipes.count == 1,
              let correctPipe = correctPipes.first,
              correctPipe.id == level.correctPipeID else {
            return LevelValidation(isValid: false, penalty: 999)
        }

        guard pipeStartsAtInlet(correctPipe, inlets: inlets),
              correctPipe.wrongOutlet == nil,
              endpointDistance(correctPipe.points.last, mainOutlet) < 0.04 else {
            return LevelValidation(isValid: false, penalty: 999)
        }

        var wrongOutletPoints: [CGPoint] = []

        for pipe in level.pipes where !pipe.isCorrect {
            guard pipeStartsAtInlet(pipe, inlets: inlets) else {
                return LevelValidation(isValid: false, penalty: 999)
            }

            guard let wrongOutlet = pipe.wrongOutlet else {
                return LevelValidation(isValid: false, penalty: 999)
            }

            wrongOutletPoints.append(wrongOutlet)

            guard endpointDistance(pipe.points.last, wrongOutlet) < 0.04 else {
                return LevelValidation(isValid: false, penalty: 999)
            }

            guard endpointDistance(wrongOutlet, mainOutlet) > 0.07,
                  endpointDistance(pipe.points.last, mainOutlet) > 0.07 else {
                return LevelValidation(isValid: false, penalty: 999)
            }
        }

        // Avoid fake ambiguity from wrong outlets being too close to each other.
        for i in 0..<wrongOutletPoints.count {
            for j in (i + 1)..<wrongOutletPoints.count {
                if endpointDistance(wrongOutletPoints[i], wrongOutletPoints[j]) < 0.045 {
                    return LevelValidation(isValid: false, penalty: 999)
                }
            }
        }

        let readabilityPenalty = computeReadabilityPenalty(level: level)
        let isReadable = readabilityPenalty < 5.2
        return LevelValidation(isValid: isReadable, penalty: readabilityPenalty)
    }
}

private extension LevelValidator {
    struct Segment {
        let a: CGPoint
        let b: CGPoint
        let pipeID: Int

        var dx: CGFloat { b.x - a.x }
        var dy: CGFloat { b.y - a.y }
        var length: CGFloat { hypot(dx, dy) }
    }

    func pipeStartsAtInlet(_ pipe: Pipe, inlets: [CGPoint]) -> Bool {
        guard pipe.inletIndex >= 0, pipe.inletIndex < inlets.count else { return false }
        guard pipe.points.count >= 2 else { return false }

        let inlet = inlets[pipe.inletIndex]
        guard let start = pipe.points.first else { return false }

        guard abs(start.x - inlet.x) < 0.035 else { return false }
        guard start.y > inlet.y - 0.01, start.y < inlet.y + 0.12 else { return false }

        // Reject degenerate segments early.
        for idx in 1..<pipe.points.count {
            let d = endpointDistance(pipe.points[idx - 1], pipe.points[idx])
            if d < 0.01 { return false }
        }

        return true
    }

    func computeReadabilityPenalty(level: MazeLevel) -> CGFloat {
        var penalty: CGFloat = 0

        let allPoints = level.pipes.flatMap { $0.points }
        if let minX = allPoints.map(\.x).min(),
           let maxX = allPoints.map(\.x).max(),
           maxX - minX < 0.62 {
            penalty += 2.6
        }

        if let minY = allPoints.map(\.y).min(),
           let maxY = allPoints.map(\.y).max(),
           maxY - minY < 0.62 {
            penalty += 2.6
        }

        let segments = buildSegments(level: level)
        for i in 0..<segments.count {
            let s1 = segments[i]
            for j in (i + 1)..<segments.count {
                let s2 = segments[j]
                if s1.pipeID == s2.pipeID { continue }

                let angle = angleBetween(s1, s2)

                if segmentsIntersect(s1, s2) {
                    // Encourage near-vertical crossings for readability.
                    if angle < 0.60 {
                        penalty += 1.1
                    }
                    continue
                }

                // Parallel close overlap is the biggest readability issue in this game.
                if angle < 0.22 {
                    let overlap = projectionOverlapLength(s1, s2)
                    if overlap > 0.05 {
                        let d = segmentDistance(s1, s2)
                        if d < 0.028 {
                            let distFactor = (0.028 - d) / 0.028
                            let overlapFactor = overlap / 0.08
                            penalty += distFactor * overlapFactor
                        }
                    }
                }
            }
        }

        return penalty
    }

    func buildSegments(level: MazeLevel) -> [Segment] {
        var segments: [Segment] = []
        for pipe in level.pipes {
            guard pipe.points.count > 1 else { continue }
            for idx in 1..<pipe.points.count {
                let segment = Segment(a: pipe.points[idx - 1], b: pipe.points[idx], pipeID: pipe.id)
                if segment.length > 0.01 {
                    segments.append(segment)
                }
            }
        }
        return segments
    }

    func endpointDistance(_ lhs: CGPoint?, _ rhs: CGPoint?) -> CGFloat {
        guard let lhs, let rhs else { return 999 }
        return hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    func normalized(_ segment: Segment) -> CGVector {
        let len = max(segment.length, 0.0001)
        return CGVector(dx: segment.dx / len, dy: segment.dy / len)
    }

    func angleBetween(_ s1: Segment, _ s2: Segment) -> CGFloat {
        let n1 = normalized(s1)
        let n2 = normalized(s2)
        let dot = abs(n1.dx * n2.dx + n1.dy * n2.dy)
        let clamped = min(max(dot, -1), 1)
        return acos(clamped)
    }

    func segmentsIntersect(_ s1: Segment, _ s2: Segment) -> Bool {
        let p = s1.a
        let r = CGVector(dx: s1.b.x - s1.a.x, dy: s1.b.y - s1.a.y)
        let q = s2.a
        let s = CGVector(dx: s2.b.x - s2.a.x, dy: s2.b.y - s2.a.y)

        let rxs = cross(r, s)
        let qmp = CGVector(dx: q.x - p.x, dy: q.y - p.y)
        let qmpxr = cross(qmp, r)

        if abs(rxs) < 0.00001 && abs(qmpxr) < 0.00001 {
            return false
        }

        if abs(rxs) < 0.00001 && abs(qmpxr) >= 0.00001 {
            return false
        }

        let t = cross(qmp, s) / rxs
        let u = cross(qmp, r) / rxs
        return t >= 0 && t <= 1 && u >= 0 && u <= 1
    }

    func cross(_ v1: CGVector, _ v2: CGVector) -> CGFloat {
        v1.dx * v2.dy - v1.dy * v2.dx
    }

    func projectionOverlapLength(_ s1: Segment, _ s2: Segment) -> CGFloat {
        let dir = normalized(s1)
        let a0: CGFloat = 0
        let a1: CGFloat = s1.length

        let b0 = project(s2.a, origin: s1.a, dir: dir)
        let b1 = project(s2.b, origin: s1.a, dir: dir)

        let bMin = min(b0, b1)
        let bMax = max(b0, b1)
        let overlapStart = max(a0, bMin)
        let overlapEnd = min(a1, bMax)
        return max(0, overlapEnd - overlapStart)
    }

    func project(_ point: CGPoint, origin: CGPoint, dir: CGVector) -> CGFloat {
        let v = CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
        return v.dx * dir.dx + v.dy * dir.dy
    }

    func segmentDistance(_ s1: Segment, _ s2: Segment) -> CGFloat {
        min(
            pointToSegmentDistance(point: s1.a, segment: s2),
            pointToSegmentDistance(point: s1.b, segment: s2),
            pointToSegmentDistance(point: s2.a, segment: s1),
            pointToSegmentDistance(point: s2.b, segment: s1)
        )
    }

    func pointToSegmentDistance(point: CGPoint, segment: Segment) -> CGFloat {
        let vx = segment.b.x - segment.a.x
        let vy = segment.b.y - segment.a.y
        let len2 = max(vx * vx + vy * vy, 0.000001)

        let wx = point.x - segment.a.x
        let wy = point.y - segment.a.y
        let t = min(max((wx * vx + wy * vy) / len2, 0), 1)

        let px = segment.a.x + t * vx
        let py = segment.a.y + t * vy
        return hypot(point.x - px, point.y - py)
    }
}
