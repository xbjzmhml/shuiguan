import SwiftUI

struct ChapterTheme {
    let chapter: Int
    let descriptor: ChapterDescriptor
    let homeBackground: [Color]
    let homeGlow: Color
    let heroGradient: [Color]
    let panelGradient: [Color]
    let cardAccent: Color
    let gameBackground: [Color]
    let gameGlow: Color
    let pipeGradient: [Color]
    let waterGradient: [Color]
    let outletFill: Color
    let outletGlow: Color
    let successAccent: Color
    let warningAccent: Color
    let badgeColor: Color
    let currentTileGradient: [Color]
    let selectedChapterGradient: [Color]

    static func forChapter(_ chapter: Int) -> ChapterTheme {
        let resolvedChapter = max(chapter, 1)
        let descriptor = LevelGenerator.chapterDescriptor(for: resolvedChapter)

        switch resolvedChapter {
        case 1:
            return ChapterTheme(
                chapter: resolvedChapter,
                descriptor: descriptor,
                homeBackground: [
                    Color(red: 0.04, green: 0.06, blue: 0.11),
                    Color(red: 0.07, green: 0.16, blue: 0.22),
                    Color(red: 0.10, green: 0.26, blue: 0.32)
                ],
                homeGlow: Color(red: 0.25, green: 0.78, blue: 0.85, opacity: 0.42),
                heroGradient: [
                    Color(red: 0.11, green: 0.22, blue: 0.30),
                    Color(red: 0.09, green: 0.33, blue: 0.40)
                ],
                panelGradient: [
                    Color(red: 0.09, green: 0.14, blue: 0.21),
                    Color(red: 0.08, green: 0.20, blue: 0.25)
                ],
                cardAccent: Color(red: 0.63, green: 0.97, blue: 0.98),
                gameBackground: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.10, green: 0.14, blue: 0.20),
                    Color(red: 0.13, green: 0.18, blue: 0.26)
                ],
                gameGlow: Color(red: 0.20, green: 0.30, blue: 0.45, opacity: 0.35),
                pipeGradient: [
                    Color(red: 0.56, green: 0.72, blue: 0.88, opacity: 0.44),
                    Color(red: 0.28, green: 0.40, blue: 0.54, opacity: 0.38)
                ],
                waterGradient: [
                    Color(red: 0.22, green: 0.86, blue: 1.00),
                    Color(red: 0.72, green: 0.98, blue: 1.00)
                ],
                outletFill: Color(red: 0.48, green: 1.00, blue: 0.75),
                outletGlow: Color(red: 0.40, green: 1.00, blue: 0.80),
                successAccent: Color(red: 0.56, green: 0.98, blue: 0.80),
                warningAccent: Color(red: 1.00, green: 0.76, blue: 0.42),
                badgeColor: Color(red: 0.28, green: 0.72, blue: 0.92),
                currentTileGradient: [
                    Color(red: 0.22, green: 0.58, blue: 0.74),
                    Color(red: 0.15, green: 0.37, blue: 0.58)
                ],
                selectedChapterGradient: [
                    Color(red: 0.28, green: 0.78, blue: 0.98),
                    Color(red: 0.16, green: 0.57, blue: 0.95)
                ]
            )
        case 2:
            return ChapterTheme(
                chapter: resolvedChapter,
                descriptor: descriptor,
                homeBackground: [
                    Color(red: 0.09, green: 0.05, blue: 0.08),
                    Color(red: 0.17, green: 0.10, blue: 0.12),
                    Color(red: 0.23, green: 0.16, blue: 0.11)
                ],
                homeGlow: Color(red: 0.94, green: 0.56, blue: 0.23, opacity: 0.36),
                heroGradient: [
                    Color(red: 0.28, green: 0.14, blue: 0.11),
                    Color(red: 0.39, green: 0.24, blue: 0.13)
                ],
                panelGradient: [
                    Color(red: 0.17, green: 0.09, blue: 0.12),
                    Color(red: 0.25, green: 0.14, blue: 0.11)
                ],
                cardAccent: Color(red: 0.98, green: 0.78, blue: 0.40),
                gameBackground: [
                    Color(red: 0.08, green: 0.06, blue: 0.10),
                    Color(red: 0.15, green: 0.10, blue: 0.13),
                    Color(red: 0.22, green: 0.15, blue: 0.12)
                ],
                gameGlow: Color(red: 0.90, green: 0.42, blue: 0.18, opacity: 0.34),
                pipeGradient: [
                    Color(red: 0.83, green: 0.64, blue: 0.46, opacity: 0.42),
                    Color(red: 0.44, green: 0.31, blue: 0.24, opacity: 0.38)
                ],
                waterGradient: [
                    Color(red: 0.34, green: 0.83, blue: 1.00),
                    Color(red: 1.00, green: 0.82, blue: 0.48)
                ],
                outletFill: Color(red: 1.00, green: 0.82, blue: 0.52),
                outletGlow: Color(red: 1.00, green: 0.67, blue: 0.30),
                successAccent: Color(red: 1.00, green: 0.82, blue: 0.52),
                warningAccent: Color(red: 1.00, green: 0.45, blue: 0.35),
                badgeColor: Color(red: 0.86, green: 0.48, blue: 0.22),
                currentTileGradient: [
                    Color(red: 0.54, green: 0.30, blue: 0.17),
                    Color(red: 0.36, green: 0.18, blue: 0.14)
                ],
                selectedChapterGradient: [
                    Color(red: 0.95, green: 0.66, blue: 0.30),
                    Color(red: 0.74, green: 0.32, blue: 0.15)
                ]
            )
        case 3:
            return ChapterTheme(
                chapter: resolvedChapter,
                descriptor: descriptor,
                homeBackground: [
                    Color(red: 0.03, green: 0.08, blue: 0.09),
                    Color(red: 0.04, green: 0.17, blue: 0.17),
                    Color(red: 0.07, green: 0.25, blue: 0.23)
                ],
                homeGlow: Color(red: 0.22, green: 0.88, blue: 0.67, opacity: 0.36),
                heroGradient: [
                    Color(red: 0.08, green: 0.20, blue: 0.20),
                    Color(red: 0.05, green: 0.31, blue: 0.26)
                ],
                panelGradient: [
                    Color(red: 0.06, green: 0.13, blue: 0.14),
                    Color(red: 0.05, green: 0.22, blue: 0.20)
                ],
                cardAccent: Color(red: 0.62, green: 1.00, blue: 0.82),
                gameBackground: [
                    Color(red: 0.04, green: 0.08, blue: 0.10),
                    Color(red: 0.05, green: 0.15, blue: 0.16),
                    Color(red: 0.07, green: 0.22, blue: 0.21)
                ],
                gameGlow: Color(red: 0.18, green: 0.52, blue: 0.42, opacity: 0.34),
                pipeGradient: [
                    Color(red: 0.49, green: 0.74, blue: 0.66, opacity: 0.44),
                    Color(red: 0.21, green: 0.41, blue: 0.36, opacity: 0.38)
                ],
                waterGradient: [
                    Color(red: 0.26, green: 0.96, blue: 0.86),
                    Color(red: 0.68, green: 1.00, blue: 0.92)
                ],
                outletFill: Color(red: 0.50, green: 1.00, blue: 0.86),
                outletGlow: Color(red: 0.30, green: 0.94, blue: 0.78),
                successAccent: Color(red: 0.62, green: 1.00, blue: 0.82),
                warningAccent: Color(red: 0.92, green: 0.44, blue: 0.42),
                badgeColor: Color(red: 0.23, green: 0.72, blue: 0.58),
                currentTileGradient: [
                    Color(red: 0.14, green: 0.46, blue: 0.40),
                    Color(red: 0.10, green: 0.29, blue: 0.27)
                ],
                selectedChapterGradient: [
                    Color(red: 0.20, green: 0.78, blue: 0.67),
                    Color(red: 0.10, green: 0.55, blue: 0.44)
                ]
            )
        default:
            return ChapterTheme(
                chapter: resolvedChapter,
                descriptor: descriptor,
                homeBackground: [
                    Color(red: 0.08, green: 0.04, blue: 0.05),
                    Color(red: 0.13, green: 0.06, blue: 0.07),
                    Color(red: 0.21, green: 0.10, blue: 0.10)
                ],
                homeGlow: Color(red: 1.00, green: 0.40, blue: 0.28, opacity: 0.36),
                heroGradient: [
                    Color(red: 0.23, green: 0.09, blue: 0.10),
                    Color(red: 0.34, green: 0.13, blue: 0.13)
                ],
                panelGradient: [
                    Color(red: 0.16, green: 0.07, blue: 0.08),
                    Color(red: 0.25, green: 0.10, blue: 0.10)
                ],
                cardAccent: Color(red: 1.00, green: 0.68, blue: 0.38),
                gameBackground: [
                    Color(red: 0.07, green: 0.04, blue: 0.05),
                    Color(red: 0.12, green: 0.06, blue: 0.07),
                    Color(red: 0.19, green: 0.09, blue: 0.09)
                ],
                gameGlow: Color(red: 1.00, green: 0.40, blue: 0.28, opacity: 0.30),
                pipeGradient: [
                    Color(red: 0.76, green: 0.56, blue: 0.52, opacity: 0.42),
                    Color(red: 0.36, green: 0.24, blue: 0.26, opacity: 0.38)
                ],
                waterGradient: [
                    Color(red: 0.72, green: 0.88, blue: 1.00),
                    Color(red: 1.00, green: 0.70, blue: 0.48)
                ],
                outletFill: Color(red: 1.00, green: 0.72, blue: 0.48),
                outletGlow: Color(red: 1.00, green: 0.45, blue: 0.28),
                successAccent: Color(red: 1.00, green: 0.72, blue: 0.48),
                warningAccent: Color(red: 1.00, green: 0.36, blue: 0.32),
                badgeColor: Color(red: 0.78, green: 0.29, blue: 0.20),
                currentTileGradient: [
                    Color(red: 0.54, green: 0.22, blue: 0.18),
                    Color(red: 0.33, green: 0.11, blue: 0.12)
                ],
                selectedChapterGradient: [
                    Color(red: 0.93, green: 0.44, blue: 0.29),
                    Color(red: 0.63, green: 0.18, blue: 0.14)
                ]
            )
        }
    }
}
