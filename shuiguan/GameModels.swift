import CoreGraphics

struct Pipe {
    let id: Int
    let inletIndex: Int
    let isCorrect: Bool
    let drawOrder: Int
    let points: [CGPoint]
    let wrongOutlet: CGPoint?
}

struct MazeLevel {
    let pipes: [Pipe]
    let correctPipeID: Int
}

struct RNG {
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
