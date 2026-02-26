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
    @Published private(set) var praiseBanner: PraiseBanner?

    let maxLives = 3
    private let storage = UserDefaults.standard
    private var roundToken = UUID()
    private let startSeed: UInt64
    private enum StorageKey {
        static let startSeed = "shuiguan.startSeed"
        static let levelSeed = "shuiguan.levelSeed"
        static let levelNumber = "shuiguan.levelNumber"
        static let lives = "shuiguan.lives"
        static let streak = "shuiguan.streak"
    }

    let animationDuration: Double = 3.2

    init() {
        let defaultLives = 3
        let defaultSeed = UInt64(Date().timeIntervalSince1970 * 1000)
        let storedStartSeed = Self.readUInt64(StorageKey.startSeed, from: storage)
        let storedLevelSeed = Self.readUInt64(StorageKey.levelSeed, from: storage)
        let storedLives = storage.object(forKey: StorageKey.lives) as? Int
        let storedLevelNumber = storage.object(forKey: StorageKey.levelNumber) as? Int
        let storedStreak = storage.object(forKey: StorageKey.streak) as? Int

        self.startSeed = storedStartSeed ?? defaultSeed
        self.levelSeed = storedLevelSeed ?? self.startSeed
        self.levelNumber = max(storedLevelNumber ?? 1, 1)
        self.lives = min(max(storedLives ?? defaultLives, 0), defaultLives)
        self.streak = max(storedStreak ?? 0, 0)

        // Each relaunch starts with full cups to avoid half-dead sessions.
        self.lives = maxLives

        if lives <= 0 {
            restorePlayableProgress()
        } else {
            persistProgress()
        }
    }

    func startPour(pipeID: Int, correctPipeID: Int) {
        if lives <= 0 {
            restorePlayableProgress()
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
        } else if lives == 0 {
            // All cups used: reset to the beginning progression state.
            levelSeed = startSeed
            levelNumber = 1
            lives = maxLives
            streak = 0
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

    private func restorePlayableProgress() {
        levelSeed = startSeed
        levelNumber = 1
        lives = maxLives
        streak = 0
        resetRoundState()
        persistProgress()
    }

    private func persistProgress() {
        storage.set(startSeed, forKey: StorageKey.startSeed)
        storage.set(levelSeed, forKey: StorageKey.levelSeed)
        storage.set(levelNumber, forKey: StorageKey.levelNumber)
        storage.set(lives, forKey: StorageKey.lives)
        storage.set(streak, forKey: StorageKey.streak)
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
