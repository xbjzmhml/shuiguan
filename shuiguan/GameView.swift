import SwiftUI

private struct RenderedLevelSnapshot {
    let seed: UInt64
    let levelNumber: Int
    let inlets: [CGPoint]
    let level: MazeLevel
}

struct GameView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var settings: GameSettings
    let feedback: FeedbackService
    let onExit: () -> Void
    let onShowGuide: () -> Void
    private let generator = LevelGenerator(inletCount: 6)
    @State private var successPulseID = UUID()
    @State private var wrongOutletFlashPipeID: Int?
    @State private var wrongOutletFlashPulse = false
    @State private var livesShakeTick: CGFloat = 0
    @State private var lostCupIndex: Int?
    @State private var lostCupDropping = false
    @State private var activeStarBurst: StarBurst?
    @State private var showingSettings = false
    @State private var tutorialPulse = false
    @State private var debugCupTapCount = 0
    @State private var debugCupResetTask: Task<Void, Never>?
    @State private var debugToast: DebugToast?
    @State private var campaignCelebration: CampaignCelebration?
    @State private var renderedLevel: RenderedLevelSnapshot?
    @State private var renderRequestID = UUID()

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let currentSeed = gameState.activeLevelSeed
            let currentLevelNumber = gameState.levelNumber
            let levelSnapshot = renderedLevel
            let isLevelReady = levelSnapshot?.seed == currentSeed && levelSnapshot?.levelNumber == currentLevelNumber
            let theme = ChapterTheme.forChapter(gameState.currentChapter)
            let inlets = isLevelReady ? (levelSnapshot?.inlets ?? []) : []
            let level = isLevelReady ? (levelSnapshot?.level ?? MazeLevel(pipes: [], correctPipeID: -1)) : MazeLevel(pipes: [], correctPipeID: -1)
            let pipes = level.pipes
            let pipeWidth = min(size.width, size.height) * 0.045

            ZStack {
                background(size: size, theme: theme)

                pipesLayer(pipes: pipes, size: size, pipeWidth: pipeWidth, theme: theme)
                waterLayer(pipes: pipes, size: size, pipeWidth: pipeWidth, theme: theme)

                outletMarkers(
                    pipes: pipes,
                    size: size,
                    flashingPipeID: wrongOutletFlashPipeID,
                    flashPulse: wrongOutletFlashPulse,
                    theme: theme
                )
                outletGlow(
                    size: size,
                    isActive: gameState.lastResultCorrect && gameState.waterProgress > 0.97,
                    successPulseID: successPulseID,
                    theme: theme
                )

                if !isLevelReady {
                    loadingOverlay(size: size, theme: theme)
                }

                if let burst = activeStarBurst {
                    FlyingStarsOverlay(burst: burst)
                        .allowsHitTesting(false)
                }

                tutorialHintOverlay(inlets: inlets, size: size)

                funnelsRow(
                    inlets: inlets,
                    size: size,
                    activePipeID: gameState.activePipeID,
                    isEnabled: gameState.phase == .idle,
                    pipes: pipes
                ) { pipeID in
                    feedback.playTap(using: settings)
                    gameState.startPour(pipeID: pipeID, correctPipeID: level.correctPipeID)
                    feedback.playPourStart(duration: gameState.animationDuration, using: settings)
                }

                if gameState.phase == .result {
                    resultPanel(size: size, theme: theme) {
                        handleResultAction()
                    }
                }

                if let banner = gameState.praiseBanner {
                    praiseOverlay(size: size, banner: banner)
                        .id(banner.id)
                }

                if let debugToast {
                    debugToastPanel(size: size, toast: debugToast, theme: theme)
                        .id(debugToast.id)
                }

                if let campaignCelebration {
                    campaignCelebrationOverlay(size: size, theme: theme)
                        .id(campaignCelebration.id)
                }

                levelBadge(size: size, theme: theme)
                livesPanel(size: size, theme: theme)
                chapterStarsPanel(
                    size: size,
                    currentChapter: gameState.currentChapter,
                    nextProgress: gameState.chapterProgressForHUD(),
                    theme: theme
                )
                if settings.debugHUDEnabled {
                    answerHintPanel(size: size, correctFunnelID: level.correctPipeID)
                    progressDebugPanel(size: size)
                }

                if let lockNotice = gameState.chapterLockNotice {
                    chapterLockPanel(size: size, notice: lockNotice, theme: theme) {
                        gameState.dismissChapterLockNotice()
                    }
                }

                topButtons(size: size, theme: theme)

                if gameState.isReplaying {
                    replayBadge(size: size, theme: theme)
                }
            }
            .contentShape(Rectangle())
            .onAppear {
                tutorialPulse = true
                requestRenderedLevel(seed: currentSeed, levelNumber: currentLevelNumber)
            }
            .onChange(of: gameState.activeLevelSeed) { seed in
                requestRenderedLevel(seed: seed, levelNumber: gameState.levelNumber)
            }
            .onChange(of: gameState.levelNumber) { levelNumber in
                requestRenderedLevel(seed: gameState.activeLevelSeed, levelNumber: levelNumber)
            }
            .onChange(of: gameState.phase) { phase in
                handlePhaseChange(phase, pipes: pipes, size: size)
            }
            .onDisappear {
                debugCupResetTask?.cancel()
                campaignCelebration = nil
                renderedLevel = nil
                feedback.stopPour()
            }
            .sheet(isPresented: $showingSettings) {
                GameSettingsSheet(
                    settings: settings,
                    gameState: gameState,
                    feedback: feedback,
                    onShowGuide: onShowGuide
                )
            }
            .onTapGesture {
                guard gameState.phase == .result else { return }
                handleResultAction()
            }
        }
    }
}

private extension GameView {
    func loadingOverlay(size: CGSize, theme: ChapterTheme) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.cardAccent)
                .scaleEffect(1.25)

            Text("Loading...")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.cardAccent.opacity(0.22), lineWidth: 1)
        )
        .position(x: size.width * 0.5, y: size.height * 0.5)
        .allowsHitTesting(false)
    }

    func requestRenderedLevel(seed: UInt64, levelNumber: Int) {
        let requestID = UUID()
        renderRequestID = requestID
        renderedLevel = nil
        let generator = self.generator

        DispatchQueue.global(qos: .userInitiated).async {
            let generated = generator.generate(seed: seed, levelNumber: levelNumber)
            DispatchQueue.main.async {
                guard renderRequestID == requestID else { return }
                renderedLevel = RenderedLevelSnapshot(
                    seed: seed,
                    levelNumber: levelNumber,
                    inlets: generated.inlets,
                    level: generated.level
                )
            }
        }
    }

    func pipesLayer(pipes: [Pipe], size: CGSize, pipeWidth: CGFloat, theme: ChapterTheme) -> some View {
        let ordered = pipes.sorted { lhs, rhs in
            if lhs.drawOrder == rhs.drawOrder {
                return lhs.id < rhs.id
            }
            return lhs.drawOrder < rhs.drawOrder
        }

        return ZStack {
            ForEach(ordered, id: \.id) { pipe in
                let path = pipePath(points: pipe.points, size: size)

                path
                    .stroke(
                        LinearGradient(
                            colors: theme.pipeGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: pipeWidth, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 7, x: 0, y: 4)

                path
                    .stroke(
                        Color.white.opacity(0.2),
                        style: StrokeStyle(lineWidth: pipeWidth * 0.34, lineCap: .round, lineJoin: .round)
                    )
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }

    func waterLayer(pipes: [Pipe], size: CGSize, pipeWidth: CGFloat, theme: ChapterTheme) -> some View {
        ZStack {
            if let activeID = gameState.activePipeID,
               let pipe = pipes.first(where: { $0.id == activeID }) {
                let path = pipePath(points: pipe.points, size: size)
                path
                    .trim(from: 0, to: gameState.waterProgress)
                    .stroke(
                        LinearGradient(
                            colors: theme.waterGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: pipeWidth * 0.55, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: theme.outletGlow.opacity(0.65), radius: 12, x: 0, y: 0)
                    .animation(.linear(duration: gameState.animationDuration), value: gameState.waterProgress)
            }
        }
        .allowsHitTesting(false)
    }

    func pipePath(points: [CGPoint], size: CGSize) -> Path {
        var path = Path()
        let scaled = points.map { scale($0, size: size) }

        guard scaled.count > 1 else { return path }
        if scaled.count == 2 {
            path.move(to: scaled[0])
            path.addLine(to: scaled[1])
            return path
        }

        path.move(to: scaled[0])
        let radius = min(size.width, size.height) * 0.042

        for i in 1..<(scaled.count - 1) {
            let prev = scaled[i - 1]
            let curr = scaled[i]
            let next = scaled[i + 1]

            let v1 = CGVector(dx: curr.x - prev.x, dy: curr.y - prev.y)
            let v2 = CGVector(dx: next.x - curr.x, dy: next.y - curr.y)
            let len1 = max(hypot(v1.dx, v1.dy), 0.001)
            let len2 = max(hypot(v2.dx, v2.dy), 0.001)

            let n1 = CGVector(dx: v1.dx / len1, dy: v1.dy / len1)
            let n2 = CGVector(dx: v2.dx / len2, dy: v2.dy / len2)
            let dot = n1.dx * n2.dx + n1.dy * n2.dy

            if abs(abs(dot) - 1) < 0.01 {
                path.addLine(to: curr)
                continue
            }

            let r = min(radius, len1 * 0.45, len2 * 0.45)
            let inPoint = CGPoint(x: curr.x - n1.dx * r, y: curr.y - n1.dy * r)
            let outPoint = CGPoint(x: curr.x + n2.dx * r, y: curr.y + n2.dy * r)

            path.addLine(to: inPoint)
            path.addQuadCurve(to: outPoint, control: curr)
        }

        if let last = scaled.last {
            path.addLine(to: last)
        }

        return path
    }

    func scale(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    func funnelsRow(
        inlets: [CGPoint],
        size: CGSize,
        activePipeID: Int?,
        isEnabled: Bool,
        pipes: [Pipe],
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        let funnelWidth = size.width * 0.07
        let funnelHeight = size.height * 0.08

        return ZStack {
            ForEach(Array(inlets.enumerated()), id: \.offset) { index, inlet in
                let pipeID = pipes.first { $0.inletIndex == index }?.id
                let isActive = (pipeID == activePipeID)
                let p = scale(inlet, size: size)

                FunnelView(isActive: isActive)
                    .frame(width: funnelWidth, height: funnelHeight)
                    .position(x: p.x, y: p.y)
                    .opacity(isEnabled || isActive ? 1 : 0.6)
                    .onTapGesture {
                        guard isEnabled else { return }
                        guard let pipeID else { return }
                        onSelect(pipeID)
                    }
            }
        }
    }

    func outletGlow(size: CGSize, isActive: Bool, successPulseID: UUID, theme: ChapterTheme) -> some View {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.93)

        return ZStack {
            Circle()
                .fill(theme.outletFill.opacity(isActive ? 0.82 : 0.34))
                .frame(width: size.width * 0.08, height: size.width * 0.08)
                .position(center)
                .shadow(
                    color: theme.outletGlow.opacity(isActive ? 0.82 : 0.32),
                    radius: isActive ? 30 : 15,
                    x: 0,
                    y: 0
                )

            Circle()
                .stroke(Color.white.opacity(0.62), lineWidth: 2)
                .frame(width: size.width * 0.1, height: size.width * 0.1)
                .position(center)

            SuccessOutletPulseView()
                .frame(width: size.width * 0.22, height: size.width * 0.22)
                .position(center)
                .id(successPulseID)
        }
        .allowsHitTesting(false)
    }

    func outletMarkers(
        pipes: [Pipe],
        size: CGSize,
        flashingPipeID: Int?,
        flashPulse: Bool,
        theme: ChapterTheme
    ) -> some View {
        ZStack {
            ForEach(pipes.filter { !$0.isCorrect }, id: \.id) { pipe in
                if let outlet = pipe.wrongOutlet {
                    let p = scale(outlet, size: size)
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.34))
                            .frame(width: size.width * 0.035, height: size.width * 0.035)
                            .overlay(Circle().stroke(Color.white.opacity(0.58), lineWidth: 1))

                        if flashingPipeID == pipe.id {
                            Circle()
                                .stroke(
                                    theme.warningAccent.opacity(flashPulse ? 0.95 : 0.4),
                                    lineWidth: flashPulse ? 4 : 2
                                )
                                .frame(
                                    width: size.width * (flashPulse ? 0.075 : 0.048),
                                    height: size.width * (flashPulse ? 0.075 : 0.048)
                                )
                                .shadow(
                                    color: theme.warningAccent.opacity(0.75),
                                    radius: 10,
                                    x: 0,
                                    y: 0
                                )
                        }
                    }
                    .position(p)
                }
            }
        }
        .allowsHitTesting(false)
    }

    func background(size: CGSize, theme: ChapterTheme) -> some View {
        ZStack {
            LinearGradient(
                colors: theme.gameBackground,
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    theme.gameGlow,
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 60,
                endRadius: min(size.width, size.height) * 0.6
            )

            Capsule()
                .fill(theme.cardAccent.opacity(0.08))
                .frame(width: size.width * 0.7, height: size.height * 0.25)
                .blur(radius: 40)
                .offset(x: -size.width * 0.1, y: -size.height * 0.25)

            Circle()
                .fill(theme.badgeColor.opacity(0.06))
                .frame(width: size.width * 0.65, height: size.width * 0.65)
                .blur(radius: 24)
                .offset(x: size.width * 0.28, y: size.height * 0.18)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    func livesPanel(size: CGSize, theme: ChapterTheme) -> some View {
        let cupWidth = size.width * 0.055
        let cupHeight = size.height * 0.05
        let spacing: CGFloat = 10

        return ZStack(alignment: .leading) {
            HStack(spacing: spacing) {
                ForEach(0..<gameState.maxLives, id: \.self) { idx in
                    WaterCupView(isFilled: idx < gameState.lives)
                        .frame(width: cupWidth, height: cupHeight)
                        .scaleEffect(idx == lostCupIndex && lostCupDropping ? 0.88 : 1)
                        .rotationEffect(.degrees(idx == lostCupIndex && lostCupDropping ? -14 : 0))
                        .offset(y: idx == lostCupIndex && lostCupDropping ? 9 : 0)
                        .overlay {
                            if idx == lostCupIndex {
                                RoundedRectangle(cornerRadius: size.width * 0.02, style: .continuous)
                                    .stroke(
                                        theme.warningAccent.opacity(lostCupDropping ? 0.9 : 0.45),
                                        lineWidth: 2
                                    )
                                    .blur(radius: lostCupDropping ? 0 : 1)
                                }
                    }
                        .opacity(idx == lostCupIndex && lostCupDropping ? 0.6 : 1)
                }
            }

            debugCupHotspot(cupWidth: cupWidth, cupHeight: cupHeight)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.badgeColor.opacity(0.22), in: Capsule())
        .position(x: size.width * 0.18, y: size.height * 0.958)
        .modifier(ShakeEffect(animatableData: livesShakeTick))
    }

    @ViewBuilder
    func debugCupHotspot(cupWidth: CGFloat, cupHeight: CGFloat) -> some View {
#if DEBUG
        Color.clear
            .frame(width: cupWidth + 18, height: cupHeight + 18)
            .contentShape(Rectangle())
            .onTapGesture {
                registerDebugCupTap()
            }
#else
        EmptyView()
#endif
    }

    func chapterStarsPanel(
        size: CGSize,
        currentChapter: Int,
        nextProgress: ChapterProgressInfo,
        theme: ChapterTheme
    ) -> some View {
        let progressText: String = {
            if gameState.isFinalChapter {
                return L10n.tr("game.chapter.finalChapter")
            }
            if nextProgress.isUnlocked {
                return L10n.tr("game.chapter.unlockProgressComplete", L10n.int(nextProgress.targetChapter))
            }
            return L10n.tr(
                "game.chapter.unlockProgress",
                L10n.int(nextProgress.targetChapter),
                L10n.int(nextProgress.earnedStars),
                L10n.int(nextProgress.requiredStars)
            )
        }()
        let progressColor = nextProgress.isUnlocked
            ? theme.successAccent
            : Color.white.opacity(0.76)

        return VStack(alignment: .trailing, spacing: 2) {
            Text("⭐ \(gameState.totalStars)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text(L10n.tr("game.chapter.current", L10n.int(currentChapter)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
            Text(theme.descriptor.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.cardAccent.opacity(0.92))
            Text(progressText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(progressColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.badgeColor.opacity(0.20), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.cardAccent.opacity(0.18), lineWidth: 1)
        )
        .position(x: size.width * 0.82, y: size.height * 0.955)
        .allowsHitTesting(false)
    }

    func topButtons(size: CGSize, theme: ChapterTheme) -> some View {
        HStack(spacing: 10) {
            topButton(symbol: "house.fill", theme: theme) {
                feedback.playTap(using: settings)
                onExit()
            }

            topButton(symbol: "gearshape.fill", theme: theme) {
                feedback.playTap(using: settings)
                showingSettings = true
            }
        }
        .position(x: size.width * 0.84, y: size.height * 0.12)
    }

    @ViewBuilder
    func tutorialHintOverlay(inlets: [CGPoint], size: CGSize) -> some View {
        if gameState.phase == .idle,
           gameState.levelNumber <= 3,
           gameState.starsEarned(for: gameState.levelNumber) == 0 {
            switch gameState.levelNumber {
            case 1:
                levelOneHint(inlets: inlets, size: size)
            case 2:
                levelTwoHint(size: size)
            case 3:
                levelThreeHint(size: size)
            default:
                EmptyView()
            }
        }
    }

    func levelOneHint(inlets: [CGPoint], size: CGSize) -> some View {
        ZStack {
            ForEach(Array(inlets.enumerated()), id: \.offset) { _, inlet in
                Circle()
                    .stroke(Color(red: 0.63, green: 0.97, blue: 0.98, opacity: tutorialPulse ? 0.88 : 0.35), lineWidth: tutorialPulse ? 4 : 2)
                    .frame(width: tutorialPulse ? size.width * 0.08 : size.width * 0.06, height: tutorialPulse ? size.width * 0.08 : size.width * 0.06)
                    .position(scale(inlet, size: size))
            }

            tutorialBubble(
                title: L10n.tr("game.hint.start.title"),
                detail: L10n.tr("game.hint.start.detail"),
                symbol: "hand.tap.fill",
                width: min(size.width * 0.72, 310)
            )
            .position(x: size.width * 0.5, y: size.height * 0.20)
        }
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: tutorialPulse)
        .allowsHitTesting(false)
    }

    func levelTwoHint(size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.58, green: 0.96, blue: 0.90, opacity: tutorialPulse ? 0.9 : 0.42), lineWidth: tutorialPulse ? 5 : 2)
                .frame(width: tutorialPulse ? size.width * 0.16 : size.width * 0.11, height: tutorialPulse ? size.width * 0.16 : size.width * 0.11)
                .position(x: size.width * 0.5, y: size.height * 0.93)

            tutorialBubble(
                title: L10n.tr("game.hint.exit.title"),
                detail: L10n.tr("game.hint.exit.detail"),
                symbol: "arrow.triangle.branch",
                width: min(size.width * 0.78, 340)
            )
            .position(x: size.width * 0.5, y: size.height * 0.23)
        }
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: tutorialPulse)
        .allowsHitTesting(false)
    }

    func levelThreeHint(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.76, blue: 0.42, opacity: tutorialPulse ? 0.92 : 0.36), lineWidth: tutorialPulse ? 4 : 2)
                .frame(width: size.width * 0.28, height: size.height * 0.07)
                .position(x: size.width * 0.18, y: size.height * 0.958)

            tutorialBubble(
                title: L10n.tr("game.hint.cup.title"),
                detail: L10n.tr("game.hint.cup.detail"),
                symbol: "drop.triangle.fill",
                width: min(size.width * 0.78, 340)
            )
            .position(x: size.width * 0.56, y: size.height * 0.82)
        }
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: tutorialPulse)
        .allowsHitTesting(false)
    }

    func tutorialBubble(title: String, detail: String, symbol: String, width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(red: 0.58, green: 0.96, blue: 0.90))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.96))

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    func replayBadge(size: CGSize, theme: ChapterTheme) -> some View {
        Text(L10n.tr("game.replayMode"))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                theme.warningAccent.opacity(0.92),
                in: Capsule()
            )
            .position(x: size.width * 0.50, y: size.height * 0.12)
            .allowsHitTesting(false)
    }

    func levelBadge(size: CGSize, theme: ChapterTheme) -> some View {
        Text(L10n.tr("home.level.value", L10n.int(gameState.levelNumber)))
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                theme.badgeColor.opacity(0.24),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(theme.cardAccent.opacity(0.18), lineWidth: 1)
            )
            .position(x: size.width * 0.50, y: size.height * 0.08)
            .allowsHitTesting(false)
    }

    func topButton(symbol: String, theme: ChapterTheme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(theme.badgeColor.opacity(0.30), in: Circle())
                .overlay(
                    Circle()
                        .stroke(theme.cardAccent.opacity(0.20), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    func answerHintPanel(size: CGSize, correctFunnelID: Int) -> some View {
        Text(L10n.tr("game.debug.correctFunnel", L10n.int(correctFunnelID + 1)))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.28), in: Capsule())
            .position(x: size.width * 0.82, y: size.height * 0.915)
            .allowsHitTesting(false)
    }

    func progressDebugPanel(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("L\(gameState.levelNumber)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text("V\(gameState.currentVariantNumber)/\(gameState.variantCount)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            Text("S\(gameState.activeLevelSeed)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(Color.white.opacity(0.78))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .position(x: size.width * 0.86, y: size.height * 0.12)
        .allowsHitTesting(false)
    }

    func praiseOverlay(size: CGSize, banner: PraiseBanner) -> some View {
        PraiseOverlayView(banner: banner)
            .position(x: size.width * 0.5, y: size.height * 0.22)
            .allowsHitTesting(false)
    }

    func campaignCelebrationOverlay(size: CGSize, theme: ChapterTheme) -> some View {
        CampaignCelebrationOverlay(theme: theme, size: size)
            .allowsHitTesting(false)
    }

    func debugToastPanel(size: CGSize, toast: DebugToast, theme: ChapterTheme) -> some View {
        Text(toast.text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.94))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.badgeColor.opacity(0.82), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.cardAccent.opacity(0.25), lineWidth: 1)
            )
            .position(x: size.width * 0.26, y: size.height * 0.885)
            .allowsHitTesting(false)
    }

    func handlePhaseChange(_ phase: RoundPhase, pipes: [Pipe], size: CGSize) {
        switch phase {
        case .success:
            feedback.playSuccess(using: settings)
            playSuccessFeedback(size: size)
            if gameState.levelNumber >= gameState.maxMainlineLevel {
                playCampaignCelebration()
            }
        case .fail:
            feedback.playFailure(using: settings)
            playFailureFeedback()
        case .idle:
            feedback.stopPour()
            wrongOutletFlashPipeID = nil
            wrongOutletFlashPulse = false
            lostCupIndex = nil
            lostCupDropping = false
            activeStarBurst = nil
            campaignCelebration = nil
        default:
            break
        }
    }

    func handleResultAction() {
        if gameState.isCampaignCompletionResult {
            gameState.finishRound()
            onExit()
            return
        }
        gameState.finishRound()
    }

    func playCampaignCelebration() {
        let celebration = CampaignCelebration()
        campaignCelebration = celebration

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if campaignCelebration?.id == celebration.id {
                campaignCelebration = nil
            }
        }
    }

    func registerDebugCupTap() {
        if settings.debugHUDEnabled {
            debugCupResetTask?.cancel()
            debugCupResetTask = nil
            debugCupTapCount = 0
            settings.toggleDebugHUDEnabled()
            feedback.playTap(using: settings)
            showDebugToast(L10n.tr("game.debug.disabled"))
            return
        }

        debugCupTapCount += 1
        debugCupResetTask?.cancel()

        guard debugCupTapCount >= 10 else {
            debugCupResetTask = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    return
                }
                debugCupTapCount = 0
            }
            return
        }

        debugCupTapCount = 0
        settings.toggleDebugHUDEnabled()
        feedback.playTap(using: settings)
        debugCupResetTask = nil
        showDebugToast(L10n.tr("game.debug.enabled"))
    }

    func showDebugToast(_ text: String) {
        let toast = DebugToast(text: text)
        debugToast = toast
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if debugToast?.id == toast.id {
                debugToast = nil
            }
        }
    }

    func playSuccessFeedback(size: CGSize) {
        successPulseID = UUID()
        let outletCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.93)
        let hudCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.955)
        activeStarBurst = StarBurst(
            count: max(gameState.lastEarnedStars, 1),
            start: outletCenter,
            destination: hudCenter
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_350_000_000)
            activeStarBurst = nil
        }
    }

    func playFailureFeedback() {
        if let activeID = gameState.activePipeID {
            wrongOutletFlashPipeID = activeID
            withAnimation(.easeOut(duration: 0.18)) {
                wrongOutletFlashPulse = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 520_000_000)
                wrongOutletFlashPulse = false
                try? await Task.sleep(nanoseconds: 220_000_000)
                if wrongOutletFlashPipeID == activeID {
                    wrongOutletFlashPipeID = nil
                }
            }
        }

        let lostIndex = min(max(gameState.lives, 0), gameState.maxLives - 1)
        lostCupIndex = lostIndex
        lostCupDropping = false
        livesShakeTick += 1

        withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) {
            lostCupDropping = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            lostCupDropping = false
            lostCupIndex = nil
        }
    }

    func chapterLockPanel(
        size: CGSize,
        notice: ChapterLockNotice,
        theme: ChapterTheme,
        onDismiss: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Text(L10n.tr("game.lockedChapter.title", L10n.int(notice.targetChapter)))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))

            Text(
                L10n.tr(
                    "game.lockedChapter.progress",
                    L10n.int(notice.earnedStars),
                    L10n.int(notice.requiredStars)
                )
            )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(L10n.tr("game.lockedChapter.replay", L10n.int(notice.replayStartLevel)))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))

            Button(action: onDismiss) {
                Text(L10n.tr("common.gotIt"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(
                        theme.badgeColor.opacity(0.95),
                        in: Capsule()
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.gameGlow.opacity(0.34), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(theme.cardAccent.opacity(0.16), lineWidth: 1)
        )
        .position(x: size.width * 0.5, y: size.height * 0.24)
        .transition(.opacity)
    }

    func resultPanel(size: CGSize, theme: ChapterTheme, onFinish: @escaping () -> Void) -> some View {
        let success = gameState.lastResultCorrect
        let campaignComplete = success && gameState.levelNumber >= gameState.maxMainlineLevel
        let outOfLives = !success && gameState.lives == 0
        let stars = gameState.lastEarnedStars
        let title: String = {
            if campaignComplete { return L10n.tr("game.result.campaignComplete") }
            if success { return L10n.tr("game.result.success") }
            if outOfLives { return L10n.tr("game.result.outOfLives") }
            return L10n.tr("game.result.fail")
        }()
        let buttonTitle: String = {
            if campaignComplete { return L10n.tr("game.result.returnHome") }
            if success { return L10n.tr("game.result.nextLevel") }
            if outOfLives { return L10n.tr("game.result.nextLayout") }
            return L10n.tr("game.result.retry")
        }()
        let subtitle: String = {
            if campaignComplete { return L10n.tr("game.result.campaignCompleteSubtitle") }
            if success {
                return L10n.tr("game.result.successSubtitle", L10n.int(stars), L10n.int(gameState.totalStars))
            }
            if outOfLives { return L10n.tr("game.result.outOfLivesSubtitle") }
            return L10n.tr("game.result.failSubtitle", L10n.int(gameState.lives), L10n.int(gameState.maxLives))
        }()

        return VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))

            if success, let milestone = gameState.chapterMilestoneNotice {
                VStack(spacing: 4) {
                    Text(milestone.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))

                    Text(milestone.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    theme.badgeColor.opacity(0.28),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.cardAccent.opacity(0.18), lineWidth: 1)
                )
            }

            if success {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { idx in
                        Image(systemName: idx < stars ? "star.fill" : "star")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                idx < stars
                                ? theme.warningAccent
                                : Color.white.opacity(0.4)
                            )
                    }
                }
            }

            Button(action: onFinish) {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        (success ? theme.successAccent : theme.badgeColor).opacity(0.95),
                        in: Capsule()
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.gameGlow.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.cardAccent.opacity(0.16), lineWidth: 1)
        )
        .position(x: size.width * 0.5, y: size.height * 0.17)
        .transition(.opacity)
    }
}

private struct FunnelView: View {
    let isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let topWidth = size.width * 0.8
            let bottomWidth = size.width * 0.45
            let height = size.height * 0.75
            let centerX = size.width * 0.5
            let topY: CGFloat = 0
            let bottomY = height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: centerX - topWidth * 0.5, y: topY))
                    path.addLine(to: CGPoint(x: centerX + topWidth * 0.5, y: topY))
                    path.addLine(to: CGPoint(x: centerX + bottomWidth * 0.5, y: bottomY))
                    path.addLine(to: CGPoint(x: centerX - bottomWidth * 0.5, y: bottomY))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.82, blue: 1.0, opacity: 0.7),
                            Color(red: 0.3, green: 0.45, blue: 0.62, opacity: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: centerX - topWidth * 0.5, y: topY))
                        path.addLine(to: CGPoint(x: centerX + topWidth * 0.5, y: topY))
                        path.addLine(to: CGPoint(x: centerX + bottomWidth * 0.5, y: bottomY))
                        path.addLine(to: CGPoint(x: centerX - bottomWidth * 0.5, y: bottomY))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )

                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: size.width * 0.28, height: size.width * 0.28)
                    .offset(y: size.height * 0.25)

                Circle()
                    .fill(Color(red: 0.35, green: 0.9, blue: 1.0, opacity: isActive ? 0.8 : 0.3))
                    .frame(width: size.width * 0.2, height: size.width * 0.2)
                    .offset(y: size.height * 0.25)
                    .shadow(
                        color: Color(red: 0.3, green: 0.9, blue: 1.0, opacity: isActive ? 0.8 : 0.3),
                        radius: isActive ? 12 : 4,
                        x: 0,
                        y: 0
                    )
            }
        }
    }
}

private struct WaterCupView: View {
    let isFilled: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let topWidth = size.width * 0.86
            let bottomWidth = size.width * 0.56
            let height = size.height * 0.72
            let centerX = size.width * 0.5
            let topY: CGFloat = 0
            let bottomY = height
            let liquidHeight = height * 0.33
            let liquidY = bottomY - liquidHeight * 0.46

            let cupPath = Path { path in
                path.move(to: CGPoint(x: centerX - topWidth * 0.5, y: topY))
                path.addLine(to: CGPoint(x: centerX + topWidth * 0.5, y: topY))
                path.addLine(to: CGPoint(x: centerX + bottomWidth * 0.5, y: bottomY))
                path.addLine(to: CGPoint(x: centerX - bottomWidth * 0.5, y: bottomY))
                path.closeSubpath()
            }

            ZStack {
                cupPath
                    .fill(Color.white.opacity(isFilled ? 0.35 : 0.12))

                RoundedRectangle(cornerRadius: size.width * 0.08, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.88, blue: 1.0, opacity: isFilled ? 0.95 : 0.12),
                                Color(red: 0.18, green: 0.45, blue: 0.65, opacity: isFilled ? 0.92 : 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: topWidth * 0.74, height: liquidHeight)
                    .position(x: centerX, y: liquidY)
                    .mask(cupPath)

                cupPath
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            }
        }
    }
}

private struct PraiseOverlayView: View {
    let banner: PraiseBanner
    @State private var appeared = false

    var body: some View {
        Text(banner.text)
            .font(.system(size: 24, weight: .black))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 1.0, blue: 1.0),
                        Color(red: 0.54, green: 0.98, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.18), in: Capsule())
            .shadow(
                color: Color(red: 0.45, green: 0.95, blue: 1.0, opacity: 0.8),
                radius: banner.glowRadius,
                x: 0,
                y: 0
            )
            .scaleEffect(appeared ? banner.scale : 0.6)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    appeared = true
                }
            }
    }
}

private struct StarBurst: Identifiable {
    let id = UUID()
    let count: Int
    let start: CGPoint
    let destination: CGPoint
}

private struct DebugToast: Identifiable {
    let id = UUID()
    let text: String
}

private struct CampaignCelebration: Identifiable {
    let id = UUID()
}

private struct FlyingStarsOverlay: View {
    let burst: StarBurst
    @State private var started = false

    var body: some View {
        ZStack {
            ForEach(0..<burst.count, id: \.self) { index in
                let delay = Double(index) * 0.08
                let xOffset = CGFloat(index - max(burst.count - 1, 0) / 2) * 18
                let yOffset = CGFloat(index % 2 == 0 ? -10 : 8)

                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.74),
                                Color(red: 1.0, green: 0.77, blue: 0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.82, blue: 0.3, opacity: 0.85), radius: 10)
                    .scaleEffect(started ? 0.52 : 1.25)
                    .opacity(started ? 0.05 : 1)
                    .position(
                        x: started ? burst.destination.x + xOffset : burst.start.x,
                        y: started ? burst.destination.y + yOffset : burst.start.y
                    )
                    .animation(
                        .spring(response: 0.62, dampingFraction: 0.76)
                            .delay(delay),
                        value: started
                    )
            }
        }
        .onAppear {
            started = false
            withAnimation(.spring(response: 0.62, dampingFraction: 0.76)) {
                started = true
            }
        }
    }
}

private struct CampaignCelebrationOverlay: View {
    let theme: ChapterTheme
    let size: CGSize

    @State private var animate = false

    private let particleOffsets: [CGSize] = [
        CGSize(width: -0.34, height: -0.28),
        CGSize(width: -0.20, height: -0.36),
        CGSize(width: 0.00, height: -0.40),
        CGSize(width: 0.22, height: -0.34),
        CGSize(width: 0.36, height: -0.24),
        CGSize(width: -0.40, height: -0.06),
        CGSize(width: 0.40, height: -0.04),
        CGSize(width: -0.34, height: 0.16),
        CGSize(width: -0.18, height: 0.28),
        CGSize(width: 0.18, height: 0.30),
        CGSize(width: 0.34, height: 0.18),
        CGSize(width: 0.00, height: 0.38)
    ]

    var body: some View {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
        let radius = min(size.width, size.height)

        return ZStack {
            RadialGradient(
                colors: [
                    theme.outletGlow.opacity(0.26),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: radius * 0.52
            )
            .frame(width: radius * 1.2, height: radius * 1.2)
            .position(center)

            ForEach(Array(particleOffsets.enumerated()), id: \.offset) { index, offset in
                let x = offset.width * radius
                let y = offset.height * radius
                let symbol = index.isMultiple(of: 3) ? "sparkle" : "star.fill"

                Image(systemName: symbol)
                    .font(.system(size: index.isMultiple(of: 3) ? 18 : 22, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                theme.warningAccent.opacity(0.98),
                                Color.white.opacity(0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: theme.outletGlow.opacity(0.84), radius: 12)
                    .scaleEffect(animate ? 1 : 0.3)
                    .opacity(animate ? 0 : 1)
                    .position(
                        x: center.x + (animate ? x : 0),
                        y: center.y + (animate ? y : 0)
                    )
                    .animation(
                        .easeOut(duration: 1.1).delay(Double(index) * 0.045),
                        value: animate
                    )
            }

            VStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(theme.warningAccent)
                    .padding(16)
                    .background(
                        Circle().fill(Color.black.opacity(0.26))
                    )
                    .overlay(
                        Circle()
                            .stroke(theme.cardAccent.opacity(0.26), lineWidth: 1)
                    )
                    .shadow(color: theme.outletGlow.opacity(0.78), radius: 18)

                Text(L10n.tr("game.result.campaignComplete"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.98))

                Text(L10n.tr("game.result.campaignCompleteSubtitle"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: min(size.width * 0.72, 320))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                Color.black.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.cardAccent.opacity(0.16), lineWidth: 1)
            )
            .scaleEffect(animate ? 1 : 0.82)
            .opacity(animate ? 1 : 0)
            .position(center)
            .animation(.spring(response: 0.56, dampingFraction: 0.72), value: animate)
        }
        .onAppear {
            animate = false
            withAnimation(.spring(response: 0.56, dampingFraction: 0.72)) {
                animate = true
            }
        }
    }
}

private struct SuccessOutletPulseView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.68, green: 1.0, blue: 0.85, opacity: 0.7), lineWidth: 5)
                .scaleEffect(animate ? 1.35 : 0.4)
                .opacity(animate ? 0 : 0.95)

            Circle()
                .stroke(Color.white.opacity(0.65), lineWidth: 2)
                .scaleEffect(animate ? 1.95 : 0.7)
                .opacity(animate ? 0 : 0.72)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.85)) {
                animate = true
            }
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 10 * sin(animatableData * .pi * 2.5)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
