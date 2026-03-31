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

struct ChapterProgressInfo {
    let targetChapter: Int
    let earnedStars: Int
    let requiredStars: Int
    let sourceRange: ClosedRange<Int>

    var isUnlocked: Bool {
        earnedStars >= requiredStars
    }
}

struct ChapterLockNotice: Identifiable {
    let id = UUID()
    let targetChapter: Int
    let earnedStars: Int
    let requiredStars: Int
    let replayStartLevel: Int
}

struct ChapterMilestoneNotice: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct ChapterSummary: Identifiable {
    let id: Int
    let chapter: Int
    let levelRange: ClosedRange<Int>
    let earnedStars: Int
    let maxStars: Int
    let unlockEarnedStars: Int?
    let unlockRequiredStars: Int?
    let isUnlocked: Bool
    let isCurrent: Bool
}

struct LevelSummary: Identifiable {
    let id: Int
    let level: Int
    let stars: Int
    let isCurrent: Bool
    let isCheckpoint: Bool
    let isSelectable: Bool
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
    @Published private(set) var totalStars: Int = 0
    @Published private(set) var lastEarnedStars: Int = 0
    @Published private(set) var chapterLockNotice: ChapterLockNotice?
    @Published private(set) var chapterMilestoneNotice: ChapterMilestoneNotice?
    @Published private(set) var levelMistakes: Int = 0

    let maxLives = 3
    private let storage = UserDefaults.standard
    private var roundToken = UUID()
    private var startSeed: UInt64
    private let generator = LevelGenerator(inletCount: 6)
    private var checkpointSeed: UInt64 = 1
    private var bestStarsByLevel: [Int: Int] = [:]
    private var replayBaseline: ProgressSnapshot?
    private static let chapterSize = 10
    private static let chapterUnlockRequiredStars = 18
    private enum StorageKey {
        static let startSeed = "shuiguan.startSeed"
        static let levelSeed = "shuiguan.levelSeed"
        static let levelNumber = "shuiguan.levelNumber"
        static let lives = "shuiguan.lives"
        static let streak = "shuiguan.streak"
        static let checkpointSeed = "shuiguan.checkpointSeed"
        static let checkpointLevel = "shuiguan.checkpointLevel"
        static let levelStars = "shuiguan.levelStars"
        static let levelMistakes = "shuiguan.levelMistakes"
        static let all = [
            startSeed,
            levelSeed,
            levelNumber,
            lives,
            streak,
            checkpointSeed,
            checkpointLevel,
            levelStars,
            levelMistakes
        ]
    }

    private struct ProgressSnapshot {
        let levelSeed: UInt64
        let levelNumber: Int
        let lives: Int
        let streak: Int
        let checkpointLevel: Int
        let checkpointSeed: UInt64
        let levelMistakes: Int
    }

    let animationDuration: Double = 3.2

    init() {
        let defaultLives = 3
        let defaultSeed = Self.makeSeed()
        let storedStartSeed = Self.readUInt64(StorageKey.startSeed, from: storage)
        let storedLevelSeed = Self.readUInt64(StorageKey.levelSeed, from: storage)
        let storedLevelNumber = storage.object(forKey: StorageKey.levelNumber) as? Int
        let storedLives = storage.object(forKey: StorageKey.lives) as? Int
        let storedStreak = storage.object(forKey: StorageKey.streak) as? Int
        let storedLevelMistakes = storage.object(forKey: StorageKey.levelMistakes) as? Int
        let storedCheckpointSeed = Self.readUInt64(StorageKey.checkpointSeed, from: storage)
        let storedCheckpointLevel = storage.object(forKey: StorageKey.checkpointLevel) as? Int

        self.startSeed = storedStartSeed ?? defaultSeed
        self.bestStarsByLevel = Self.readLevelStars(from: storage)
        self.totalStars = bestStarsByLevel.values.reduce(0, +)

        // First launch: create a clean progression from level 1.
        guard let savedLevelSeed = storedLevelSeed,
              let savedLevelNumber = storedLevelNumber else {
            self.levelSeed = self.startSeed
            self.levelNumber = 1
            self.lives = defaultLives
            self.streak = 0
            self.levelMistakes = 0
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
        self.levelMistakes = max(storedLevelMistakes ?? 0, 0)

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

        if let gate = gateInfoForAccessingLevel(self.levelNumber), !gate.isUnlocked {
            applyChapterLock(gate)
        }

        if lives <= 0 {
            restoreFromCheckpoint()
        } else {
            persistProgress()
        }
    }

    func chapterProgressForHUD() -> ChapterProgressInfo {
        chapterProgressForUnlockingChapter(currentChapter + 1)
    }

    var currentChapter: Int {
        Self.chapterForLevel(levelNumber)
    }

    var isReplaying: Bool {
        replayBaseline != nil
    }

    func chapterSummaries() -> [ChapterSummary] {
        let highestCompletedLevel = bestStarsByLevel.keys.max() ?? 0
        let highestKnownLevel = max(levelNumber, highestCompletedLevel, 1)
        let chapterCount = max(Self.chapterForLevel(highestKnownLevel) + 1, 4)

        return (1...chapterCount).map { chapter in
            let range = Self.levelRange(for: chapter)
            let earned = stars(in: range)

            if chapter == 1 {
                return ChapterSummary(
                    id: chapter,
                    chapter: chapter,
                    levelRange: range,
                    earnedStars: earned,
                    maxStars: range.count * 3,
                    unlockEarnedStars: nil,
                    unlockRequiredStars: nil,
                    isUnlocked: true,
                    isCurrent: chapter == currentChapter
                )
            }

            let gate = chapterProgressForUnlockingChapter(chapter)
            return ChapterSummary(
                id: chapter,
                chapter: chapter,
                levelRange: range,
                earnedStars: earned,
                maxStars: range.count * 3,
                unlockEarnedStars: gate.earnedStars,
                unlockRequiredStars: gate.requiredStars,
                isUnlocked: gate.isUnlocked,
                isCurrent: chapter == currentChapter
            )
        }
    }

    func levelSummaries(for chapter: Int) -> [LevelSummary] {
        let range = Self.levelRange(for: chapter)
        return range.map { level in
            LevelSummary(
                id: level,
                level: level,
                stars: bestStarsByLevel[level] ?? 0,
                isCurrent: level == levelNumber,
                isCheckpoint: Self.isCheckpointLevel(level),
                isSelectable: canSelectLevel(level)
            )
        }
    }

    func starsEarned(for level: Int) -> Int {
        bestStarsByLevel[max(level, 1)] ?? 0
    }

    func dismissChapterLockNotice() {
        chapterLockNotice = nil
    }

    func dismissChapterMilestoneNotice() {
        chapterMilestoneNotice = nil
    }

    func selectLevel(_ targetLevel: Int) -> Bool {
        guard canSelectLevel(targetLevel) else { return false }

        let resolvedLevel = max(targetLevel, 1)
        let baseline = replayBaseline ?? currentProgressSnapshot()
        if resolvedLevel == baseline.levelNumber {
            if replayBaseline != nil {
                restoreReplayBaseline()
            }
            chapterLockNotice = nil
            chapterMilestoneNotice = nil
            praiseBanner = nil
            resetRoundState()
            persistProgress()
            return true
        }

        if replayBaseline == nil {
            replayBaseline = baseline
        }

        levelNumber = resolvedLevel
        levelSeed = seedForLevel(levelNumber)
        checkpointLevel = Self.checkpointForLevel(levelNumber)
        checkpointSeed = seedForLevel(checkpointLevel)
        lives = maxLives
        streak = 0
        levelMistakes = 0
        chapterLockNotice = nil
        chapterMilestoneNotice = nil
        praiseBanner = nil
        resetRoundState()
        persistProgress()
        return true
    }

    func prepareForMenu() {
        chapterLockNotice = nil
        chapterMilestoneNotice = nil
        praiseBanner = nil
        if replayBaseline != nil {
            restoreReplayBaseline()
        }
        resetRoundState()
        persistProgress()
    }

    func resetProgress() {
        for key in StorageKey.all {
            storage.removeObject(forKey: key)
        }

        startSeed = Self.makeSeed()
        bestStarsByLevel = [:]
        totalStars = 0
        checkpointLevel = 1
        checkpointSeed = startSeed
        levelSeed = startSeed
        levelNumber = 1
        lives = maxLives
        streak = 0
        levelMistakes = 0
        praiseBanner = nil
        chapterLockNotice = nil
        chapterMilestoneNotice = nil
        replayBaseline = nil
        resetRoundState()
        persistProgress()
    }

    func startPour(pipeID: Int, correctPipeID: Int) {
        chapterLockNotice = nil
        chapterMilestoneNotice = nil
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
            let nextChapterGateBefore = chapterProgressForUnlockingChapter(currentChapter + 1)
            lastEarnedStars = awardedStarsForCurrentRound()
            updateBestStars(for: levelNumber, earned: lastEarnedStars)
            let nextChapterGateAfter = chapterProgressForUnlockingChapter(currentChapter + 1)
            chapterMilestoneNotice = buildChapterMilestoneNotice(
                clearedLevel: levelNumber,
                gateBefore: nextChapterGateBefore,
                gateAfter: nextChapterGateAfter
            )
            streak += 1
            triggerPraiseIfNeeded()
        } else {
            lastEarnedStars = 0
            levelMistakes += 1
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
            let nextLevel = levelNumber + 1
            if let gate = gateInfoForAccessingLevel(nextLevel), !gate.isUnlocked {
                applyChapterLock(gate)
            } else {
                levelSeed = nextSeed
                levelNumber = nextLevel
                if Self.isCheckpointLevel(levelNumber) {
                    checkpointLevel = levelNumber
                    checkpointSeed = levelSeed
                }
            }
            levelMistakes = 0
            if let baseline = replayBaseline, levelNumber > baseline.levelNumber {
                replayBaseline = nil
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
        lastEarnedStars = 0
        chapterMilestoneNotice = nil
        phase = .idle
    }

    private func restoreFromCheckpoint() {
        levelSeed = checkpointSeed
        levelNumber = checkpointLevel
        lives = maxLives
        streak = 0
        levelMistakes = 0
        chapterLockNotice = nil
        chapterMilestoneNotice = nil
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
        let persisted = replayBaseline ?? currentProgressSnapshot()

        storage.set(startSeed, forKey: StorageKey.startSeed)
        storage.set(persisted.levelSeed, forKey: StorageKey.levelSeed)
        storage.set(persisted.levelNumber, forKey: StorageKey.levelNumber)
        storage.set(persisted.lives, forKey: StorageKey.lives)
        storage.set(persisted.streak, forKey: StorageKey.streak)
        storage.set(persisted.levelMistakes, forKey: StorageKey.levelMistakes)
        storage.set(persisted.checkpointSeed, forKey: StorageKey.checkpointSeed)
        storage.set(persisted.checkpointLevel, forKey: StorageKey.checkpointLevel)
        storage.set(encodeLevelStars(bestStarsByLevel), forKey: StorageKey.levelStars)
    }

    private func currentProgressSnapshot() -> ProgressSnapshot {
        ProgressSnapshot(
            levelSeed: levelSeed,
            levelNumber: levelNumber,
            lives: lives,
            streak: streak,
            checkpointLevel: checkpointLevel,
            checkpointSeed: checkpointSeed,
            levelMistakes: levelMistakes
        )
    }

    private func restoreReplayBaseline() {
        guard let baseline = replayBaseline else { return }
        apply(snapshot: baseline)
        replayBaseline = nil
    }

    private func apply(snapshot: ProgressSnapshot) {
        levelSeed = baselineSafeSeed(snapshot.levelSeed)
        levelNumber = max(snapshot.levelNumber, 1)
        lives = min(max(snapshot.lives, 0), maxLives)
        streak = max(snapshot.streak, 0)
        checkpointLevel = max(snapshot.checkpointLevel, 1)
        checkpointSeed = baselineSafeSeed(snapshot.checkpointSeed)
        levelMistakes = max(snapshot.levelMistakes, 0)
    }

    private func baselineSafeSeed(_ seed: UInt64) -> UInt64 {
        max(seed, 1)
    }

    private func updateBestStars(for level: Int, earned: Int) {
        let resolvedLevel = max(level, 1)
        let resolvedStars = min(max(earned, 1), 3)
        let old = bestStarsByLevel[resolvedLevel] ?? 0
        if resolvedStars > old {
            bestStarsByLevel[resolvedLevel] = resolvedStars
            totalStars += (resolvedStars - old)
        }
    }

    private func awardedStarsForCurrentRound() -> Int {
        switch levelMistakes {
        case 0:
            return 3
        case 1:
            return 2
        default:
            return 1
        }
    }

    private func stars(in range: ClosedRange<Int>) -> Int {
        guard range.lowerBound <= range.upperBound else { return 0 }
        return range.reduce(0) { partial, level in
            partial + (bestStarsByLevel[level] ?? 0)
        }
    }

    private func buildChapterMilestoneNotice(
        clearedLevel: Int,
        gateBefore: ChapterProgressInfo,
        gateAfter: ChapterProgressInfo
    ) -> ChapterMilestoneNotice? {
        let chapter = Self.chapterForLevel(clearedLevel)
        let chapterRange = Self.levelRange(for: chapter)

        if clearedLevel == chapterRange.upperBound {
            if gateAfter.isUnlocked {
                let descriptor = LevelGenerator.chapterDescriptor(for: gateAfter.targetChapter)
                return ChapterMilestoneNotice(
                    title: "第\(chapter)章完成",
                    detail: "已解锁第\(gateAfter.targetChapter)章 · \(descriptor.title)"
                )
            }

            let remain = max(gateAfter.requiredStars - gateAfter.earnedStars, 0)
            return ChapterMilestoneNotice(
                title: "第\(chapter)章完成",
                detail: "当前 \(gateAfter.earnedStars)/\(gateAfter.requiredStars) 星，再刷 \(remain) 星解锁第\(gateAfter.targetChapter)章"
            )
        }

        if !gateBefore.isUnlocked && gateAfter.isUnlocked {
            let descriptor = LevelGenerator.chapterDescriptor(for: gateAfter.targetChapter)
            return ChapterMilestoneNotice(
                title: "第\(gateAfter.targetChapter)章已解锁",
                detail: "\(descriptor.title) 已开放，可以从首页直接进入。"
            )
        }

        return nil
    }

    private func chapterProgressForUnlockingChapter(_ chapter: Int) -> ChapterProgressInfo {
        let safeChapter = max(chapter, 2)
        let previousChapter = safeChapter - 1
        let start = (previousChapter - 1) * Self.chapterSize + 1
        let end = previousChapter * Self.chapterSize
        let earned = stars(in: start...end)
        return ChapterProgressInfo(
            targetChapter: safeChapter,
            earnedStars: earned,
            requiredStars: Self.chapterUnlockRequiredStars,
            sourceRange: start...end
        )
    }

    private func gateInfoForAccessingLevel(_ level: Int) -> ChapterProgressInfo? {
        let resolvedLevel = max(level, 1)
        guard resolvedLevel > Self.chapterSize else { return nil }
        let chapter = Self.chapterForLevel(resolvedLevel)
        let gate = chapterProgressForUnlockingChapter(chapter)
        return gate.isUnlocked ? nil : gate
    }

    private func canSelectLevel(_ level: Int) -> Bool {
        let resolvedLevel = max(level, 1)
        guard gateInfoForAccessingLevel(resolvedLevel) == nil else { return false }
        return resolvedLevel <= max(levelNumber, bestStarsByLevel.keys.max() ?? 0, 1)
    }

    private func applyChapterLock(_ gate: ChapterProgressInfo) {
        let replayLevel = gate.sourceRange.lowerBound
        levelNumber = replayLevel
        levelSeed = seedForLevel(replayLevel)
        lives = maxLives
        streak = 0
        levelMistakes = 0
        checkpointLevel = Self.checkpointForLevel(replayLevel)
        checkpointSeed = seedForLevel(checkpointLevel)
        chapterLockNotice = ChapterLockNotice(
            targetChapter: gate.targetChapter,
            earnedStars: gate.earnedStars,
            requiredStars: gate.requiredStars,
            replayStartLevel: replayLevel
        )
    }

    private func encodeLevelStars(_ map: [Int: Int]) -> [String: Int] {
        var encoded: [String: Int] = [:]
        encoded.reserveCapacity(map.count)
        for (level, stars) in map {
            guard level >= 1 else { continue }
            encoded[String(level)] = min(max(stars, 1), 3)
        }
        return encoded
    }

    private static func checkpointForLevel(_ level: Int) -> Int {
        let resolvedLevel = max(level, 1)
        if resolvedLevel < chapterSize {
            return 1
        }
        return (resolvedLevel / chapterSize) * chapterSize
    }

    private static func isCheckpointLevel(_ level: Int) -> Bool {
        level >= chapterSize && level % chapterSize == 0
    }

    private static func chapterForLevel(_ level: Int) -> Int {
        let resolvedLevel = max(level, 1)
        return ((resolvedLevel - 1) / chapterSize) + 1
    }

    private static func levelRange(for chapter: Int) -> ClosedRange<Int> {
        let resolvedChapter = max(chapter, 1)
        let start = (resolvedChapter - 1) * chapterSize + 1
        let end = resolvedChapter * chapterSize
        return start...end
    }

    private static func makeSeed() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
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

    private static func readLevelStars(from storage: UserDefaults) -> [Int: Int] {
        guard let raw = storage.dictionary(forKey: StorageKey.levelStars) as? [String: Int] else {
            return [:]
        }

        var cleaned: [Int: Int] = [:]
        cleaned.reserveCapacity(raw.count)
        for (levelText, stars) in raw {
            guard let level = Int(levelText), level >= 1 else { continue }
            cleaned[level] = min(max(stars, 1), 3)
        }
        return cleaned
    }
}
