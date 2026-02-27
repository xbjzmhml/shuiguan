import SwiftUI
import Combine

enum RoundPhase {
    case idle
    case pouring
    case success
    case fail
    case result
}

struct PraiseBanner: Identifiable {
    let id = UUID()
    let text: String
    let scale: CGFloat
    let glowRadius: CGFloat
}

final class GameState: ObservableObject {
    @Published var activePipeID: Int?
    @Published var waterProgress: CGFloat = 0
    @Published var lastResultCorrect = false
    @Published var levelSeed: UInt64
    @Published private(set) var phase: RoundPhase = .idle
    @Published private(set) var lives: Int
    @Published private(set) var streak: Int = 0
    @Published private(set) var levelNumber: Int = 1
    @Published private(set) var checkpointLevel: Int = 1
    @Published private(set) var praiseBanner: PraiseBanner?

    let maxLives = 3
    private let storage = UserDefaults.standard
    private var roundToken = UUID()
    private let startSeed: UInt64
    private let generator = LevelGenerator(inletCount: 6)
    private var checkpointSeed: UInt64 = 1
    private enum StorageKey {
        static let startSeed = "shuiguan.startSeed"
        static let levelSeed = "shuiguan.levelSeed"
        static let levelNumber = "shuiguan.levelNumber"
        static let lives = "shuiguan.lives"
        static let streak = "shuiguan.streak"
        static let checkpointSeed = "shuiguan.checkpointSeed"
        static let checkpointLevel = "shuiguan.checkpointLevel"
    }

    let animationDuration: Double = 3.2

    init() {
        let defaultLives = 3
        let defaultSeed = UInt64(Date().timeIntervalSince1970 * 1000)
        let storedStartSeed = Self.readUInt64(StorageKey.startSeed, from: storage)
        let storedLevelSeed = Self.readUInt64(StorageKey.levelSeed, from: storage)
        let storedLevelNumber = storage.object(forKey: StorageKey.levelNumber) as? Int
        let storedLives = storage.object(forKey: StorageKey.lives) as? Int
        let storedStreak = storage.object(forKey: StorageKey.streak) as? Int
        let storedCheckpointSeed = Self.readUInt64(StorageKey.checkpointSeed, from: storage)
        let storedCheckpointLevel = storage.object(forKey: StorageKey.checkpointLevel) as? Int

        self.startSeed = storedStartSeed ?? defaultSeed

        // First launch: create a clean progression from level 1.
        guard let savedLevelSeed = storedLevelSeed,
              let savedLevelNumber = storedLevelNumber else {
            self.levelSeed = self.startSeed
            self.levelNumber = 1
            self.lives = defaultLives
            self.streak = 0
            self.checkpointLevel = 1
            self.checkpointSeed = self.startSeed
            persistProgress()
            return
        }

        // Later launches: resume where player left.
        self.levelSeed = max(savedLevelSeed, 1)
        self.levelNumber = max(savedLevelNumber, 1)
        self.lives = min(max(storedLives ?? defaultLives, 0), defaultLives)
        self.streak = max(storedStreak ?? 0, 0)

        if let checkpointLevel = storedCheckpointLevel,
           let checkpointSeed = storedCheckpointSeed,
           checkpointLevel >= 1,
           checkpointLevel <= self.levelNumber {
            self.checkpointLevel = checkpointLevel
            self.checkpointSeed = max(checkpointSeed, 1)
        } else {
            self.checkpointLevel = Self.checkpointForLevel(self.levelNumber)
            self.checkpointSeed = seedForLevel(self.checkpointLevel)
        }

        if lives <= 0 {
            restoreFromCheckpoint()
        } else {
            persistProgress()
        }
    }

    func startPour(pipeID: Int, correctPipeID: Int) {
        if lives <= 0 {
            restoreFromCheckpoint()
        }
        guard phase == .idle else { return }
        guard lives > 0 else { return }

        activePipeID = pipeID
        waterProgress = 0
        lastResultCorrect = (pipeID == correctPipeID)
        phase = .pouring
        roundToken = UUID()
        let token = roundToken

        withAnimation(.linear(duration: animationDuration)) {
            waterProgress = 1
        }

        Task { [weak self] in
            guard let self else { return }
            let delay = UInt64(self.animationDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                self.finishPour(token: token)
            }
        }
    }

    @MainActor
    private func finishPour(token: UUID) {
        guard token == roundToken, phase == .pouring else { return }

        phase = lastResultCorrect ? .success : .fail
        if lastResultCorrect {
            streak += 1
            triggerPraiseIfNeeded()
        } else {
            lives = max(lives - 1, 0)
            streak = 0
        }
        persistProgress()

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.moveToResult(token: token)
            }
        }
    }

    @MainActor
    private func moveToResult(token: UUID) {
        guard token == roundToken else { return }
        guard phase == .success || phase == .fail else { return }
        phase = .result
    }

    func finishRound(nextSeed: UInt64) {
        guard phase == .result else { return }

        if lastResultCorrect {
            levelSeed = nextSeed
            levelNumber += 1
            if Self.isCheckpointLevel(levelNumber) {
                checkpointLevel = levelNumber
                checkpointSeed = levelSeed
            }
        } else if lives == 0 {
            // All cups used: fallback to last checkpoint (10, 20, 30...).
            restoreFromCheckpoint()
            return
        }

        resetRoundState()
        persistProgress()
    }

    @MainActor
    private func triggerPraiseIfNeeded() {
        guard streak >= 2 else { return }
        let banner = buildPraiseBanner(for: streak)
        praiseBanner = banner

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                self.clearPraise(id: banner.id)
            }
        }
    }

    @MainActor
    private func clearPraise(id: UUID) {
        guard praiseBanner?.id == id else { return }
        praiseBanner = nil
    }

    private func buildPraiseBanner(for streak: Int) -> PraiseBanner {
        let message: String
        switch streak {
        case 2:
            message = "连中 x2 很棒"
        case 3:
            message = "连中 x3 太强了"
        case 4:
            message = "连中 x4 继续保持"
        case 5:
            message = "连中 x5 神准"
        default:
            message = "连中 x\(streak) 传奇"
        }

        let intensity = min(CGFloat(streak - 1), 8)
        return PraiseBanner(
            text: message,
            scale: 1.0 + intensity * 0.05,
            glowRadius: 8 + intensity * 2.5
        )
    }

    private func resetRoundState() {
        roundToken = UUID()
        activePipeID = nil
        waterProgress = 0
        lastResultCorrect = false
        phase = .idle
    }

    private func restoreFromCheckpoint() {
        levelSeed = checkpointSeed
        levelNumber = checkpointLevel
        lives = maxLives
        streak = 0
        resetRoundState()
        persistProgress()
    }

    private func seedForLevel(_ targetLevel: Int) -> UInt64 {
        let resolvedLevel = max(targetLevel, 1)
        if resolvedLevel == 1 {
            return startSeed
        }

        var seed = startSeed
        for level in 1..<resolvedLevel {
            let generated = generator.generate(seed: seed, levelNumber: level)
            seed = generator.nextSeed(from: generated.resolvedSeed)
        }
        return seed
    }

    private func persistProgress() {
        storage.set(startSeed, forKey: StorageKey.startSeed)
        storage.set(levelSeed, forKey: StorageKey.levelSeed)
        storage.set(levelNumber, forKey: StorageKey.levelNumber)
        storage.set(lives, forKey: StorageKey.lives)
        storage.set(streak, forKey: StorageKey.streak)
        storage.set(checkpointSeed, forKey: StorageKey.checkpointSeed)
        storage.set(checkpointLevel, forKey: StorageKey.checkpointLevel)
    }

    private static func checkpointForLevel(_ level: Int) -> Int {
        let resolvedLevel = max(level, 1)
        if resolvedLevel < 10 {
            return 1
        }
        return (resolvedLevel / 10) * 10
    }

    private static func isCheckpointLevel(_ level: Int) -> Bool {
        level >= 10 && level % 10 == 0
    }

    private static func readUInt64(_ key: String, from storage: UserDefaults) -> UInt64? {
        if let number = storage.object(forKey: key) as? NSNumber {
            return number.uint64Value
        }
        if let text = storage.string(forKey: key) {
            return UInt64(text)
        }
        return nil
    }
}
