struct LevelValidator {
    func validate(level: MazeLevel, inletCount: Int) -> Bool {
        guard level.pipes.count == inletCount else { return false }

        let correctPipes = level.pipes.filter { $0.isCorrect }
        guard correctPipes.count == 1 else { return false }
        guard correctPipes[0].id == level.correctPipeID else { return false }

        let inletSet = Set(level.pipes.map { $0.inletIndex })
        guard inletSet.count == inletCount else { return false }

        for pipe in level.pipes {
            guard pipe.points.count >= 2 else { return false }
            if pipe.isCorrect {
                if pipe.wrongOutlet != nil { return false }
            } else {
                if pipe.wrongOutlet == nil { return false }
            }
        }

        return true
    }
}
