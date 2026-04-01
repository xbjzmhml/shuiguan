import SwiftUI

struct HomeView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var settings: GameSettings
    let feedback: FeedbackService
    let onContinue: () -> Void
    let onPlayLevel: (Int) -> Void
    let onShowGuide: () -> Void

    @State private var selectedChapter: Int
    @State private var showingSettings = false

    init(
        gameState: GameState,
        settings: GameSettings,
        feedback: FeedbackService,
        onContinue: @escaping () -> Void,
        onPlayLevel: @escaping (Int) -> Void,
        onShowGuide: @escaping () -> Void
    ) {
        self.gameState = gameState
        self.settings = settings
        self.feedback = feedback
        self.onContinue = onContinue
        self.onPlayLevel = onPlayLevel
        self.onShowGuide = onShowGuide
        _selectedChapter = State(initialValue: gameState.currentChapter)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let chapters = gameState.chapterSummaries()
            let activeChapter = chapters.first(where: { $0.chapter == selectedChapter }) ?? chapters[0]
            let currentTheme = ChapterTheme.forChapter(gameState.currentChapter)
            let activeTheme = ChapterTheme.forChapter(activeChapter.chapter)
            let levels = gameState.levelSummaries(for: activeChapter.chapter)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard(size: size, theme: currentTheme)
                    chapterStrip(chapters: chapters)
                    chapterPanel(summary: activeChapter, levels: levels, theme: activeTheme)
                }
                .padding(.horizontal, 18)
                .padding(.top, 26)
                .padding(.bottom, 34)
            }
            .background(background(size: size, theme: activeTheme))
        }
        .sheet(isPresented: $showingSettings) {
            GameSettingsSheet(
                settings: settings,
                gameState: gameState,
                feedback: feedback,
                onShowGuide: onShowGuide
            )
        }
    }
}

private extension HomeView {
    func heroCard(size: CGSize, theme: ChapterTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("水管迷阵")
                        .font(.system(size: min(size.width * 0.12, 42), weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text("当前章节：\(theme.descriptor.title) · 章节推进、刷星回放、从任意已解锁关卡继续。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer(minLength: 12)

                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.12), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                HomeStatPill(title: "当前关卡", value: "第 \(gameState.levelNumber) 关", accent: theme.cardAccent)
                HomeStatPill(title: "总星级", value: "⭐ \(gameState.totalStars)", accent: theme.cardAccent)
                HomeStatPill(title: "检查点", value: "第 \(gameState.checkpointLevel) 关", accent: theme.cardAccent)
            }

            HStack(spacing: 10) {
                Button(action: continueGame) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("继续主线")
                                .font(.system(size: 17, weight: .bold))
                            Text("从第 \(gameState.levelNumber) 关进入")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.68))
                        }

                        Spacer()

                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: theme.selectedChapterGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Button(action: showGuide) {
                    VStack(spacing: 6) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("玩法说明")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 108)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.cardAccent.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: theme.heroGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.cardAccent.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 10)
    }

    func chapterStrip(chapters: [ChapterSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("章节进度")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(chapters) { chapter in
                        Button {
                            feedback.playTap(using: settings)
                            selectedChapter = chapter.chapter
                        } label: {
                            ChapterPill(
                                summary: chapter,
                                isSelected: chapter.chapter == selectedChapter
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    func chapterPanel(summary: ChapterSummary, levels: [LevelSummary], theme: ChapterTheme) -> some View {
        let descriptor = theme.descriptor

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("第 \(summary.chapter) 章")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.97))

                    Text("关卡 \(summary.levelRange.lowerBound)-\(summary.levelRange.upperBound) · \(summary.earnedStars)/\(summary.maxStars) 星")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                Spacer(minLength: 10)

                chapterBadge(summary: summary, theme: theme)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.cardAccent)

                Text(descriptor.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.74))
            }

            if !summary.isUnlocked,
               let earned = summary.unlockEarnedStars,
               let required = summary.unlockRequiredStars {
                Text("上一章达到 \(earned)/\(required) 星后解锁。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.52))
            } else {
                Text("点击任意已解锁关卡进入回放。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 12)],
                spacing: 12
            ) {
                ForEach(levels) { level in
                    Button {
                        guard level.isSelectable else { return }
                        playLevel(level.level)
                    } label: {
                        LevelTile(level: level, theme: theme)
                    }
                    .buttonStyle(.plain)
                    .disabled(!level.isSelectable)
                }
            }

            Text("关卡回放会保留当前主线进度，只更新最佳星级。")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: theme.panelGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.cardAccent.opacity(0.16), lineWidth: 1)
        )
    }

    func chapterBadge(summary: ChapterSummary, theme: ChapterTheme) -> some View {
        let text: String
        let fill: Color

        if summary.isCurrent {
            text = "当前章节"
            fill = theme.badgeColor
        } else if summary.isUnlocked {
            text = "已解锁"
            fill = theme.successAccent
        } else {
            text = "未解锁"
            fill = Color(red: 0.43, green: 0.47, blue: 0.56)
        }

        return Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fill.opacity(0.9), in: Capsule())
    }

    func background(size: CGSize, theme: ChapterTheme) -> some View {
        ZStack {
            LinearGradient(
                colors: theme.homeBackground,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    theme.homeGlow,
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: min(size.width, size.height) * 0.72
            )

            RoundedRectangle(cornerRadius: size.width * 0.14, style: .continuous)
                .fill(theme.cardAccent.opacity(0.10))
                .frame(width: size.width * 0.75, height: size.width * 0.75)
                .blur(radius: 40)
                .offset(x: size.width * 0.28, y: -size.height * 0.28)

            Circle()
                .fill(theme.badgeColor.opacity(0.08))
                .frame(width: size.width * 0.58, height: size.width * 0.58)
                .blur(radius: 24)
                .offset(x: -size.width * 0.34, y: size.height * 0.20)
        }
        .ignoresSafeArea()
    }

    func continueGame() {
        feedback.playTap(using: settings)
        onContinue()
    }

    func openSettings() {
        feedback.playTap(using: settings)
        showingSettings = true
    }

    func playLevel(_ level: Int) {
        feedback.playTap(using: settings)
        onPlayLevel(level)
    }

    func showGuide() {
        feedback.playTap(using: settings)
        onShowGuide()
    }
}

private struct HomeStatPill: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent.opacity(0.90))

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.94))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ChapterPill: View {
    let summary: ChapterSummary
    let isSelected: Bool
    private var theme: ChapterTheme {
        ChapterTheme.forChapter(summary.chapter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("第 \(summary.chapter) 章")
                    .font(.system(size: 14, weight: .bold))
                if !summary.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                }
            }

            Text("\(summary.earnedStars)/\(summary.maxStars) 星")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(isSelected ? 0.84 : 0.62))
        }
        .foregroundStyle(Color.white.opacity(0.95))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: theme.selectedChapterGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(summary.isUnlocked ? 0.10 : 0.06),
                                Color.white.opacity(summary.isUnlocked ? 0.06 : 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? theme.cardAccent.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LevelTile: View {
    let level: LevelSummary
    let theme: ChapterTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("第 \(level.level) 关")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(level.isSelectable ? 0.96 : 0.54))

                Spacer(minLength: 8)

                if level.isCurrent {
                    Text("当前")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(theme.cardAccent, in: Capsule())
                } else if level.isCheckpoint {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.warningAccent.opacity(level.isSelectable ? 0.96 : 0.42))
                }
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < level.stars ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(
                            index < level.stars
                                ? theme.warningAccent
                                : Color.white.opacity(level.isSelectable ? 0.2 : 0.1)
                        )
                }
            }

            if !level.isSelectable {
                Text("未开放")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.42))
            } else if level.stars > 0 {
                Text("已完成")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.successAccent)
            } else {
                Text("可挑战")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: level.isCurrent ? 1.5 : 1)
        )
    }

    private var backgroundFill: LinearGradient {
        if level.isCurrent {
            return LinearGradient(
                colors: theme.currentTileGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        if level.isSelectable {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color.white.opacity(0.04),
                Color.white.opacity(0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        if level.isCurrent {
            return theme.cardAccent.opacity(0.88)
        }
        if level.isSelectable {
            return theme.cardAccent.opacity(0.18)
        }
        return Color.white.opacity(0.04)
    }
}
