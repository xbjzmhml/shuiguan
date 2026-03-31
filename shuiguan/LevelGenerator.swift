import CoreGraphics
import Foundation

struct ChapterDescriptor {
    let title: String
    let detail: String
}

private enum ChapterStyle {
    case training
    case crossfire
    case whirlpool
    case pressure

    static func forChapter(_ chapter: Int) -> ChapterStyle {
        switch max(chapter, 1) {
        case 1:
            return .training
        case 2:
            return .crossfire
        case 3:
            return .whirlpool
        default:
            return .pressure
        }
    }

    var descriptor: ChapterDescriptor {
        switch self {
        case .training:
            return ChapterDescriptor(
                title: "入门水路",
                detail: "先学会盯住最终主管，误导分支最少，给判断节奏打底。"
            )
        case .crossfire:
            return ChapterDescriptor(
                title: "交叉迷墙",
                detail: "中段交叉明显变密，假路线会更频繁地往主管附近靠。"
            )
        case .whirlpool:
            return ChapterDescriptor(
                title: "回环陷阱",
                detail: "回环和折返开始主导路线，不能只看局部拐点。"
            )
        case .pressure:
            return ChapterDescriptor(
                title: "深水高压",
                detail: "交叉、回环和绕路会混在一起，整体更紧、更乱、更难读。"
            )
        }
    }
}

private enum LevelDifficulty {
    case easy
    case normal
    case hard

    static func forLevel(_ levelNumber: Int) -> LevelDifficulty {
        switch max(levelNumber, 1) {
        case 1...8:
            return .easy
        case 9...24:
            return .normal
        default:
            return .hard
        }
    }

    var profile: GenerationProfile {
        switch self {
        case .easy:
            return GenerationProfile(
                attemptCount: 72,
                targetPenalty: 2.65,
                upperRows: [0.30, 0.33, 0.36, 0.39, 0.42, 0.45],
                middleRows: [0.50, 0.54, 0.58, 0.62, 0.64, 0.60],
                lowerRows: [0.70, 0.73, 0.76, 0.79, 0.82, 0.78],
                turnCols: [0.14, 0.26, 0.38, 0.62, 0.74, 0.86],
                crossCols: [0.18, 0.30, 0.42, 0.58, 0.70, 0.82],
                loopCols: [0.12, 0.24, 0.36, 0.64, 0.76, 0.88],
                bottomRows: [0.835, 0.848, 0.862, 0.878, 0.888, 0.852],
                rowJitter: 0.003,
                upperToMiddleGap: 0.13,
                middleToLowerGap: 0.12,
                loopChance: 40,
                secondLoopChance: 14,
                detourChance: 12,
                loopSpan: 0.15,
                detourSpan: 0.12,
                pushAwayFromInlet: 0.13,
                pushAwayChain: 0.14,
                joinVariance: 0.018
            )
        case .normal:
            return GenerationProfile(
                attemptCount: 88,
                targetPenalty: 3.05,
                upperRows: [0.30, 0.33, 0.36, 0.39, 0.42, 0.45],
                middleRows: [0.50, 0.53, 0.56, 0.59, 0.62, 0.65],
                lowerRows: [0.68, 0.71, 0.74, 0.77, 0.79, 0.81],
                turnCols: [0.14, 0.24, 0.34, 0.66, 0.76, 0.86],
                crossCols: [0.18, 0.29, 0.40, 0.60, 0.71, 0.82],
                loopCols: [0.12, 0.26, 0.38, 0.62, 0.74, 0.88],
                bottomRows: [0.83, 0.845, 0.86, 0.875, 0.89, 0.84],
                rowJitter: 0.004,
                upperToMiddleGap: 0.12,
                middleToLowerGap: 0.11,
                loopChance: 70,
                secondLoopChance: 36,
                detourChance: 30,
                loopSpan: 0.17,
                detourSpan: 0.14,
                pushAwayFromInlet: 0.11,
                pushAwayChain: 0.12,
                joinVariance: 0.025
            )
        case .hard:
            return GenerationProfile(
                attemptCount: 108,
                targetPenalty: 3.45,
                upperRows: [0.29, 0.32, 0.35, 0.38, 0.41, 0.44],
                middleRows: [0.48, 0.52, 0.55, 0.58, 0.61, 0.64],
                lowerRows: [0.67, 0.70, 0.73, 0.76, 0.79, 0.82],
                turnCols: [0.12, 0.22, 0.34, 0.66, 0.78, 0.88],
                crossCols: [0.16, 0.28, 0.40, 0.60, 0.72, 0.84],
                loopCols: [0.10, 0.24, 0.38, 0.62, 0.76, 0.90],
                bottomRows: [0.828, 0.842, 0.856, 0.870, 0.886, 0.898],
                rowJitter: 0.006,
                upperToMiddleGap: 0.105,
                middleToLowerGap: 0.102,
                loopChance: 84,
                secondLoopChance: 60,
                detourChance: 52,
                loopSpan: 0.20,
                detourSpan: 0.16,
                pushAwayFromInlet: 0.09,
                pushAwayChain: 0.10,
                joinVariance: 0.03
            )
        }
    }
}

private struct GenerationProfile {
    let attemptCount: Int
    let targetPenalty: CGFloat
    let upperRows: [CGFloat]
    let middleRows: [CGFloat]
    let lowerRows: [CGFloat]
    let turnCols: [CGFloat]
    let crossCols: [CGFloat]
    let loopCols: [CGFloat]
    let bottomRows: [CGFloat]
    let rowJitter: CGFloat
    let upperToMiddleGap: CGFloat
    let middleToLowerGap: CGFloat
    let loopChance: Int
    let secondLoopChance: Int
    let detourChance: Int
    let loopSpan: CGFloat
    let detourSpan: CGFloat
    let pushAwayFromInlet: CGFloat
    let pushAwayChain: CGFloat
    let joinVariance: CGFloat
}

struct LevelGenerator {
    let inletCount: Int
    private let validator = LevelValidator()
    private static let chapterSize = 10
    private struct CacheKey: Hashable {
        let seed: UInt64
        let levelNumber: Int
        let inletCount: Int
    }

    private struct CacheValue {
        let inlets: [CGPoint]
        let level: MazeLevel
        let resolvedSeed: UInt64
    }

    private struct LevelFootprint {
        let levelNumber: Int
        let correctInlet: Int
        let cells: Set<Int>
    }

    private static let tutorialLayoutSeeds: [UInt64] = [
        0x4F9D_1821_A6B3_7C11,
        0x6E37_A95B_1420_FC8D,
        0x9B21_55A0_38D4_0F67,
        0x1FC8_DA47_925E_B301,
        0xA420_77C1_6E2D_19B5,
        0xD8F3_041B_5AC9_E27F,
        0x2B71_EEC0_91D8_45A3,
        0x75C4_132F_B8A6_DE09,
        0xC01E_9A65_47B2_3D81,
        0x8AD7_5F90_1CE4_62BB
    ]

    private static var cache: [CacheKey: CacheValue] = [:]
    private static var recentFootprints: [LevelFootprint] = []

    init(inletCount: Int = 6) {
        self.inletCount = inletCount
    }

    static func chapterDescriptor(for chapter: Int) -> ChapterDescriptor {
        ChapterStyle.forChapter(chapter).descriptor
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

    func generate(seed: UInt64, levelNumber: Int = 1) -> (inlets: [CGPoint], level: MazeLevel, resolvedSeed: UInt64) {
        let normalizedSeed = max(seed, 1)
        let normalizedLevel = max(levelNumber, 1)

        let cacheKey = CacheKey(
            seed: normalizedSeed,
            levelNumber: normalizedLevel,
            inletCount: inletCount
        )
        if let cached = Self.cache[cacheKey] {
            return (cached.inlets, cached.level, cached.resolvedSeed)
        }

        let inlets = inletPositions()
        let mainOutlet = CGPoint(x: 0.5, y: 0.93)

        func cacheAndReturn(
            _ inlets: [CGPoint],
            _ level: MazeLevel,
            _ resolvedSeed: UInt64
        ) -> (inlets: [CGPoint], level: MazeLevel, resolvedSeed: UInt64) {
            Self.cache[cacheKey] = CacheValue(inlets: inlets, level: level, resolvedSeed: resolvedSeed)
            if Self.cache.count > 320, let stale = Self.cache.keys.first {
                Self.cache.removeValue(forKey: stale)
            }
            rememberRecentFootprint(for: level, levelNumber: normalizedLevel)
            return (inlets, level, resolvedSeed)
        }

        // First 10 levels are fixed tutorial layouts (non-random), but we keep the
        // incoming progression seed as resolvedSeed so post-tutorial randomness remains unique per user.
        if normalizedLevel <= Self.tutorialLayoutSeeds.count {
            let tutorial = generateTutorialLevel(inlets: inlets, levelNumber: normalizedLevel, mainOutlet: mainOutlet)
            return cacheAndReturn(inlets, tutorial, normalizedSeed)
        }

        let profile = chapterProfile(for: normalizedLevel)
        var candidateSeed = normalizedSeed
        var bestAnyLevel: MazeLevel?
        var bestAnySeed: UInt64 = candidateSeed
        var bestAnyPenalty: CGFloat = .greatestFiniteMagnitude
        var bestValidLevel: MazeLevel?
        var bestValidSeed: UInt64 = candidateSeed
        var bestValidPenalty: CGFloat = .greatestFiniteMagnitude

        for _ in 0..<profile.attemptCount {
            let level = buildLevel(inlets: inlets, seed: candidateSeed, profile: profile)
            let validation = validator.evaluate(
                level: level,
                inletCount: inletCount,
                inlets: inlets,
                mainOutlet: mainOutlet
            )
            let duplicatePenalty = duplicationPenalty(for: level, levelNumber: normalizedLevel)
            let effectivePenalty = validation.penalty + duplicatePenalty

            if effectivePenalty < bestAnyPenalty {
                bestAnyPenalty = effectivePenalty
                bestAnyLevel = level
                bestAnySeed = candidateSeed
            }

            if validation.isValid, effectivePenalty < bestValidPenalty {
                bestValidPenalty = effectivePenalty
                bestValidLevel = level
                bestValidSeed = candidateSeed
                if duplicatePenalty < 0.001, validation.penalty <= profile.targetPenalty {
                    return cacheAndReturn(inlets, level, candidateSeed)
                }
            }
            candidateSeed = nextSeed(from: candidateSeed)
        }

        if let bestValidLevel {
            return cacheAndReturn(inlets, bestValidLevel, bestValidSeed)
        }

        if let bestAnyLevel {
            return cacheAndReturn(inlets, bestAnyLevel, bestAnySeed)
        }

        let fallback = buildLevel(inlets: inlets, seed: candidateSeed, profile: profile)
        return cacheAndReturn(inlets, fallback, candidateSeed)
    }
}

private extension LevelGenerator {
    func generateTutorialLevel(inlets: [CGPoint], levelNumber: Int, mainOutlet: CGPoint) -> MazeLevel {
        let tutorialIndex = min(max(levelNumber - 1, 0), Self.tutorialLayoutSeeds.count - 1)
        let layoutSeed = Self.tutorialLayoutSeeds[tutorialIndex]
        let profile = tutorialProfile(for: levelNumber)
        var candidateSeed = layoutSeed
        var bestLevel: MazeLevel?
        var bestPenalty: CGFloat = .greatestFiniteMagnitude

        for _ in 0..<profile.attemptCount {
            let level = buildLevel(inlets: inlets, seed: candidateSeed, profile: profile)
            let validation = validator.evaluate(
                level: level,
                inletCount: inletCount,
                inlets: inlets,
                mainOutlet: mainOutlet
            )
            let tutorialPenalty = validation.penalty + tutorialComplexityPenalty(level: level, tutorialLevel: levelNumber)

            if tutorialPenalty < bestPenalty {
                bestPenalty = tutorialPenalty
                bestLevel = level
            }

            if validation.isValid, tutorialPenalty <= profile.targetPenalty {
                return level
            }

            candidateSeed = nextSeed(from: candidateSeed)
        }

        if let bestLevel {
            return bestLevel
        }
        return buildLevel(inlets: inlets, seed: layoutSeed, profile: profile)
    }

    func tutorialProfile(for levelNumber: Int) -> GenerationProfile {
        switch levelNumber {
        case 1...2:
            return adjustedProfile(
                LevelDifficulty.easy.profile,
                attemptCount: 120,
                targetPenalty: 2.30,
                rowJitter: 0.002,
                loopChance: 12,
                secondLoopChance: 0,
                detourChance: 0,
                loopSpan: 0.14,
                detourSpan: 0.11,
                pushAwayFromInlet: 0.18,
                pushAwayChain: 0.18,
                joinVariance: 0.010
            )
        case 3...4:
            return adjustedProfile(
                LevelDifficulty.easy.profile,
                attemptCount: 124,
                targetPenalty: 2.45,
                rowJitter: 0.0025,
                loopChance: 22,
                secondLoopChance: 6,
                detourChance: 6,
                loopSpan: 0.15,
                detourSpan: 0.12,
                pushAwayFromInlet: 0.16,
                pushAwayChain: 0.17,
                joinVariance: 0.012
            )
        case 5...6:
            return adjustedProfile(
                LevelDifficulty.easy.profile,
                attemptCount: 128,
                targetPenalty: 2.60,
                rowJitter: 0.003,
                loopChance: 36,
                secondLoopChance: 12,
                detourChance: 10,
                loopSpan: 0.16,
                detourSpan: 0.12,
                pushAwayFromInlet: 0.14,
                pushAwayChain: 0.15,
                joinVariance: 0.014
            )
        case 7...8:
            return adjustedProfile(
                LevelDifficulty.normal.profile,
                attemptCount: 132,
                targetPenalty: 2.90,
                rowJitter: 0.0035,
                loopChance: 46,
                secondLoopChance: 18,
                detourChance: 18,
                loopSpan: 0.16,
                detourSpan: 0.13,
                pushAwayFromInlet: 0.12,
                pushAwayChain: 0.13,
                joinVariance: 0.018
            )
        default:
            return adjustedProfile(
                LevelDifficulty.normal.profile,
                attemptCount: 136,
                targetPenalty: 3.10,
                rowJitter: 0.0038,
                loopChance: 56,
                secondLoopChance: 26,
                detourChance: 24,
                loopSpan: 0.17,
                detourSpan: 0.14,
                pushAwayFromInlet: 0.11,
                pushAwayChain: 0.12,
                joinVariance: 0.020
            )
        }
    }

    func chapterProfile(for levelNumber: Int) -> GenerationProfile {
        let normalizedLevel = max(levelNumber, 1)
        let chapter = Self.chapterForLevel(normalizedLevel)
        let style = ChapterStyle.forChapter(chapter)
        let base = LevelDifficulty.forLevel(normalizedLevel).profile
        let levelInChapter = ((normalizedLevel - 1) % Self.chapterSize) + 1
        let ramp = CGFloat(levelInChapter - 1) / CGFloat(max(Self.chapterSize - 1, 1))
        let extraPressure = max(chapter - 4, 0)

        switch style {
        case .training:
            return base
        case .crossfire:
            return adjustedProfile(
                base,
                attemptCount: base.attemptCount + 12 + extraPressure * 4,
                targetPenalty: base.targetPenalty + 0.14 + CGFloat(extraPressure) * 0.05,
                middleRows: [0.49, 0.52, 0.55, 0.58, 0.61, 0.64],
                lowerRows: [0.67, 0.70, 0.73, 0.76, 0.79, 0.80],
                turnCols: [0.12, 0.25, 0.38, 0.62, 0.75, 0.88],
                crossCols: [0.22, 0.34, 0.46, 0.54, 0.66, 0.78],
                loopCols: [0.15, 0.29, 0.43, 0.57, 0.71, 0.85],
                bottomRows: [0.834, 0.848, 0.862, 0.876, 0.888, 0.852],
                rowJitter: min(base.rowJitter + 0.0012 + ramp * 0.0008 + CGFloat(extraPressure) * 0.0005, 0.0085),
                upperToMiddleGap: max(base.upperToMiddleGap - 0.006, 0.092),
                middleToLowerGap: max(base.middleToLowerGap - 0.004, 0.090),
                loopChance: min(base.loopChance + 8 + Int((ramp + CGFloat(extraPressure) * 0.25) * 10), 92),
                secondLoopChance: min(base.secondLoopChance + 6 + Int(ramp * 8), 78),
                detourChance: min(base.detourChance + 18 + Int((ramp + CGFloat(extraPressure) * 0.2) * 14), 76),
                loopSpan: min(base.loopSpan + 0.01 + ramp * 0.01, 0.24),
                detourSpan: min(base.detourSpan + 0.015 + ramp * 0.01, 0.20),
                pushAwayFromInlet: max(base.pushAwayFromInlet - 0.02 - CGFloat(extraPressure) * 0.004, 0.06),
                pushAwayChain: max(base.pushAwayChain - 0.02 - CGFloat(extraPressure) * 0.004, 0.07),
                joinVariance: min(base.joinVariance + 0.006 + ramp * 0.004 + CGFloat(extraPressure) * 0.002, 0.045)
            )
        case .whirlpool:
            return adjustedProfile(
                base,
                attemptCount: base.attemptCount + 16 + extraPressure * 5,
                targetPenalty: base.targetPenalty + 0.20 + CGFloat(extraPressure) * 0.06,
                upperRows: [0.29, 0.32, 0.35, 0.38, 0.41, 0.44],
                middleRows: [0.47, 0.51, 0.54, 0.57, 0.60, 0.63],
                lowerRows: [0.66, 0.69, 0.72, 0.75, 0.78, 0.81],
                turnCols: [0.13, 0.24, 0.35, 0.65, 0.76, 0.87],
                crossCols: [0.18, 0.30, 0.42, 0.58, 0.70, 0.82],
                loopCols: [0.09, 0.21, 0.35, 0.65, 0.79, 0.91],
                bottomRows: [0.83, 0.844, 0.858, 0.872, 0.886, 0.896],
                rowJitter: min(base.rowJitter + 0.0015 + ramp * 0.001 + CGFloat(extraPressure) * 0.0006, 0.009),
                upperToMiddleGap: max(base.upperToMiddleGap - 0.008, 0.090),
                middleToLowerGap: max(base.middleToLowerGap - 0.006, 0.088),
                loopChance: min(base.loopChance + 24 + Int((ramp + CGFloat(extraPressure) * 0.25) * 16), 96),
                secondLoopChance: min(base.secondLoopChance + 24 + Int((ramp + CGFloat(extraPressure) * 0.2) * 16), 88),
                detourChance: min(base.detourChance + 10 + Int(ramp * 10), 70),
                loopSpan: min(base.loopSpan + 0.045 + ramp * 0.015, 0.27),
                detourSpan: min(base.detourSpan + 0.01 + ramp * 0.01, 0.20),
                pushAwayFromInlet: max(base.pushAwayFromInlet - 0.015 - CGFloat(extraPressure) * 0.004, 0.06),
                pushAwayChain: max(base.pushAwayChain - 0.02 - CGFloat(extraPressure) * 0.004, 0.065),
                joinVariance: min(base.joinVariance + 0.005 + ramp * 0.004 + CGFloat(extraPressure) * 0.002, 0.046)
            )
        case .pressure:
            return adjustedProfile(
                base,
                attemptCount: base.attemptCount + 20 + extraPressure * 8,
                targetPenalty: base.targetPenalty + 0.28 + CGFloat(extraPressure) * 0.10,
                upperRows: [0.28, 0.31, 0.34, 0.37, 0.40, 0.43],
                middleRows: [0.46, 0.50, 0.53, 0.57, 0.60, 0.64],
                lowerRows: [0.65, 0.69, 0.72, 0.76, 0.80, 0.84],
                turnCols: [0.10, 0.21, 0.33, 0.67, 0.79, 0.90],
                crossCols: [0.15, 0.27, 0.39, 0.61, 0.73, 0.85],
                loopCols: [0.09, 0.23, 0.37, 0.63, 0.77, 0.91],
                bottomRows: [0.826, 0.842, 0.856, 0.872, 0.888, 0.898],
                rowJitter: min(base.rowJitter + 0.002 + ramp * 0.0014 + CGFloat(extraPressure) * 0.0008, 0.010),
                upperToMiddleGap: max(base.upperToMiddleGap - 0.010, 0.086),
                middleToLowerGap: max(base.middleToLowerGap - 0.008, 0.084),
                loopChance: min(base.loopChance + 18 + Int((ramp + CGFloat(extraPressure) * 0.3) * 16), 98),
                secondLoopChance: min(base.secondLoopChance + 18 + Int((ramp + CGFloat(extraPressure) * 0.3) * 18), 92),
                detourChance: min(base.detourChance + 16 + Int((ramp + CGFloat(extraPressure) * 0.25) * 16), 84),
                loopSpan: min(base.loopSpan + 0.03 + ramp * 0.015, 0.28),
                detourSpan: min(base.detourSpan + 0.02 + ramp * 0.015, 0.22),
                pushAwayFromInlet: max(base.pushAwayFromInlet - 0.025 - CGFloat(extraPressure) * 0.006, 0.05),
                pushAwayChain: max(base.pushAwayChain - 0.022 - CGFloat(extraPressure) * 0.006, 0.055),
                joinVariance: min(base.joinVariance + 0.008 + ramp * 0.005 + CGFloat(extraPressure) * 0.003, 0.052)
            )
        }
    }

    func tutorialComplexityPenalty(level: MazeLevel, tutorialLevel: Int) -> CGFloat {
        let totalPoints = level.pipes.reduce(0) { $0 + $1.points.count }
        let averagePoints = CGFloat(totalPoints) / CGFloat(max(level.pipes.count, 1))
        let targetRange: ClosedRange<CGFloat>

        switch tutorialLevel {
        case 1...2:
            targetRange = 8.0...12.5
        case 3...4:
            targetRange = 9.5...14.0
        case 5...6:
            targetRange = 11.0...16.0
        case 7...8:
            targetRange = 12.5...18.5
        default:
            targetRange = 14.0...21.0
        }

        var penalty: CGFloat = 0
        if averagePoints < targetRange.lowerBound {
            penalty += (targetRange.lowerBound - averagePoints) * 1.6
        }
        if averagePoints > targetRange.upperBound {
            penalty += (averagePoints - targetRange.upperBound) * 1.1
        }
        return penalty
    }

    func adjustedProfile(
        _ base: GenerationProfile,
        attemptCount: Int? = nil,
        targetPenalty: CGFloat? = nil,
        upperRows: [CGFloat]? = nil,
        middleRows: [CGFloat]? = nil,
        lowerRows: [CGFloat]? = nil,
        turnCols: [CGFloat]? = nil,
        crossCols: [CGFloat]? = nil,
        loopCols: [CGFloat]? = nil,
        bottomRows: [CGFloat]? = nil,
        rowJitter: CGFloat? = nil,
        upperToMiddleGap: CGFloat? = nil,
        middleToLowerGap: CGFloat? = nil,
        loopChance: Int? = nil,
        secondLoopChance: Int? = nil,
        detourChance: Int? = nil,
        loopSpan: CGFloat? = nil,
        detourSpan: CGFloat? = nil,
        pushAwayFromInlet: CGFloat? = nil,
        pushAwayChain: CGFloat? = nil,
        joinVariance: CGFloat? = nil
    ) -> GenerationProfile {
        GenerationProfile(
            attemptCount: attemptCount ?? base.attemptCount,
            targetPenalty: targetPenalty ?? base.targetPenalty,
            upperRows: upperRows ?? base.upperRows,
            middleRows: middleRows ?? base.middleRows,
            lowerRows: lowerRows ?? base.lowerRows,
            turnCols: turnCols ?? base.turnCols,
            crossCols: crossCols ?? base.crossCols,
            loopCols: loopCols ?? base.loopCols,
            bottomRows: bottomRows ?? base.bottomRows,
            rowJitter: rowJitter ?? base.rowJitter,
            upperToMiddleGap: upperToMiddleGap ?? base.upperToMiddleGap,
            middleToLowerGap: middleToLowerGap ?? base.middleToLowerGap,
            loopChance: loopChance ?? base.loopChance,
            secondLoopChance: secondLoopChance ?? base.secondLoopChance,
            detourChance: detourChance ?? base.detourChance,
            loopSpan: loopSpan ?? base.loopSpan,
            detourSpan: detourSpan ?? base.detourSpan,
            pushAwayFromInlet: pushAwayFromInlet ?? base.pushAwayFromInlet,
            pushAwayChain: pushAwayChain ?? base.pushAwayChain,
            joinVariance: joinVariance ?? base.joinVariance
        )
    }

    func duplicationPenalty(for level: MazeLevel, levelNumber: Int) -> CGFloat {
        guard levelNumber >= 11 else { return 0 }
        guard !Self.recentFootprints.isEmpty else { return 0 }

        let footprint = makeFootprint(for: level, levelNumber: levelNumber)
        let recent = Self.recentFootprints.suffix(6)
        var penalty: CGFloat = 0

        for previous in recent {
            let similarity = jaccard(footprint.cells, previous.cells)
            if similarity > 0.82 {
                penalty += 20 + (similarity - 0.82) * 40
            } else if similarity > 0.72 {
                penalty += (similarity - 0.72) * 16
            } else if similarity > 0.66, footprint.correctInlet == previous.correctInlet {
                penalty += 0.35
            }
        }

        return penalty
    }

    func rememberRecentFootprint(for level: MazeLevel, levelNumber: Int) {
        guard levelNumber >= 11 else { return }
        let footprint = makeFootprint(for: level, levelNumber: levelNumber)

        if let last = Self.recentFootprints.last,
           last.levelNumber == footprint.levelNumber,
           jaccard(last.cells, footprint.cells) > 0.995,
           last.correctInlet == footprint.correctInlet {
            return
        }

        Self.recentFootprints.append(footprint)
        if Self.recentFootprints.count > 18 {
            Self.recentFootprints.removeFirst(Self.recentFootprints.count - 18)
        }
    }

    private func makeFootprint(for level: MazeLevel, levelNumber: Int) -> LevelFootprint {
        let cols = 10
        let rows = 13
        var cells: Set<Int> = []

        for pipe in level.pipes {
            guard pipe.points.count > 1 else { continue }
            for idx in 1..<pipe.points.count {
                let a = pipe.points[idx - 1]
                let b = pipe.points[idx]
                let length = max(hypot(b.x - a.x, b.y - a.y), 0.0001)
                let steps = max(Int(ceil(length / 0.02)), 1)
                for step in 0...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    let point = CGPoint(
                        x: a.x + (b.x - a.x) * t,
                        y: a.y + (b.y - a.y) * t
                    )
                    guard point.x >= 0.04, point.x <= 0.96,
                          point.y >= 0.20, point.y <= 0.90 else { continue }
                    let xNorm = (point.x - 0.04) / 0.92
                    let yNorm = (point.y - 0.20) / 0.70
                    let xIdx = min(max(Int((xNorm * CGFloat(cols)).rounded(.down)), 0), cols - 1)
                    let yIdx = min(max(Int((yNorm * CGFloat(rows)).rounded(.down)), 0), rows - 1)
                    cells.insert(yIdx * cols + xIdx)
                }
            }
        }

        return LevelFootprint(levelNumber: levelNumber, correctInlet: level.correctPipeID, cells: cells)
    }

    func jaccard(_ lhs: Set<Int>, _ rhs: Set<Int>) -> CGFloat {
        if lhs.isEmpty && rhs.isEmpty { return 1 }
        let inter = lhs.intersection(rhs).count
        let union = lhs.union(rhs).count
        guard union > 0 else { return 0 }
        return CGFloat(inter) / CGFloat(union)
    }

    func buildLevel(inlets: [CGPoint], seed: UInt64, profile: GenerationProfile) -> MazeLevel {
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

        var upperRows = profile.upperRows
        var middleRows = profile.middleRows
        var lowerRows = profile.lowerRows
        var turnCols = profile.turnCols
        var crossCols = profile.crossCols
        var loopCols = profile.loopCols
        var bottomRows = profile.bottomRows

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

            let yUpper = clampY(upperRows[i % upperRows.count] + rng.nextCGFloat(in: -profile.rowJitter...profile.rowJitter))
            let yMiddle = clampY(max(yUpper + profile.upperToMiddleGap, middleRows[i % middleRows.count] + rng.nextCGFloat(in: -profile.rowJitter...profile.rowJitter)))
            let yLower = clampY(max(yMiddle + profile.middleToLowerGap, lowerRows[i % lowerRows.count] + rng.nextCGFloat(in: -profile.rowJitter...profile.rowJitter)))

            var xTurn = turnCols[i % turnCols.count]
            var xCross = crossCols[i % crossCols.count]
            var xLoop = loopCols[i % loopCols.count]

            xTurn = pushAway(xTurn, from: inlet.x, amount: profile.pushAwayFromInlet)
            xCross = pushAway(xCross, from: xTurn, amount: profile.pushAwayChain)
            xLoop = pushAway(xLoop, from: xCross, amount: profile.pushAwayChain)

            points.append(CGPoint(x: inlet.x, y: pipeStartY))
            points.append(CGPoint(x: inlet.x, y: pipeNeckY))
            points.append(CGPoint(x: inlet.x, y: 0.205))
            points.append(CGPoint(x: inlet.x, y: yUpper))
            points.append(CGPoint(x: xTurn, y: yUpper))

            if rng.nextInt(100) < profile.detourChance {
                let detourY = clampY(yUpper - rng.nextCGFloat(in: 0.05...0.1))
                let detourX = clampX(xTurn + (xTurn < 0.5 ? profile.detourSpan : -profile.detourSpan) + rng.nextCGFloat(in: -0.02...0.02))
                let returnY = clampY(yUpper + rng.nextCGFloat(in: 0.015...0.03))
                points.append(CGPoint(x: xTurn, y: detourY))
                points.append(CGPoint(x: detourX, y: detourY))
                points.append(CGPoint(x: detourX, y: returnY))
                points.append(CGPoint(x: xTurn, y: returnY))
            }

            points.append(CGPoint(x: xTurn, y: yMiddle))
            points.append(CGPoint(x: xCross, y: yMiddle))
            points.append(CGPoint(x: xCross, y: yLower))
            points.append(CGPoint(x: xLoop, y: yLower))

            if rng.nextInt(100) < profile.loopChance {
                let loopY1 = clampY((yUpper + yMiddle) * 0.5 + rng.nextCGFloat(in: -0.01...0.01))
                let loopY2 = clampY((yMiddle + yLower) * 0.5 + rng.nextCGFloat(in: -0.01...0.01))
                let xWide = clampX(xLoop + (xLoop < 0.5 ? profile.loopSpan : -profile.loopSpan) + rng.nextCGFloat(in: -0.02...0.02))

                points.append(CGPoint(x: xLoop, y: loopY1))
                points.append(CGPoint(x: xWide, y: loopY1))
                points.append(CGPoint(x: xWide, y: loopY2))
                points.append(CGPoint(x: xCross, y: loopY2))

                if rng.nextInt(100) < profile.secondLoopChance {
                    let loopY3 = clampY(loopY2 + rng.nextCGFloat(in: 0.03...0.06))
                    let loopY4 = clampY(loopY3 + rng.nextCGFloat(in: 0.03...0.06))
                    let xBounce = clampX(xCross + (xCross < 0.5 ? profile.loopSpan * 0.9 : -profile.loopSpan * 0.9) + rng.nextCGFloat(in: -0.02...0.02))
                    points.append(CGPoint(x: xCross, y: loopY3))
                    points.append(CGPoint(x: xBounce, y: loopY3))
                    points.append(CGPoint(x: xBounce, y: loopY4))
                    points.append(CGPoint(x: xLoop, y: loopY4))
                }
            }

            let isCorrect = (i == correctIndex)
            var wrongOutlet: CGPoint? = nil

            if isCorrect {
                let joinX = clampX(0.5 + rng.nextCGFloat(in: -profile.joinVariance...profile.joinVariance))
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

    private static func chapterForLevel(_ level: Int) -> Int {
        let resolvedLevel = max(level, 1)
        return ((resolvedLevel - 1) / chapterSize) + 1
    }
}
