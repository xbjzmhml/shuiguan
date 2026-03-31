import SwiftUI

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var gameState = GameState()
    @StateObject private var settings = GameSettings()
    @StateObject private var feedback = FeedbackService()
    private let generator = LevelGenerator(inletCount: 6)
    @State private var successPulseID = UUID()
    @State private var wrongOutletFlashPipeID: Int?
    @State private var wrongOutletFlashPulse = false
    @State private var livesShakeTick: CGFloat = 0
    @State private var lostCupIndex: Int?
    @State private var lostCupDropping = false
    @State private var activeStarBurst: StarBurst?
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let generated = generator.generate(seed: gameState.levelSeed, levelNumber: gameState.levelNumber)
            let inlets = generated.inlets
            let level = generated.level
            let resolvedSeed = generated.resolvedSeed
            let pipes = level.pipes
            let pipeWidth = min(size.width, size.height) * 0.045

            ZStack {
                background(size: size)

                pipesLayer(pipes: pipes, size: size, pipeWidth: pipeWidth)
                waterLayer(pipes: pipes, size: size, pipeWidth: pipeWidth)

                outletMarkers(
                    pipes: pipes,
                    size: size,
                    flashingPipeID: wrongOutletFlashPipeID,
                    flashPulse: wrongOutletFlashPulse
                )
                outletGlow(
                    size: size,
                    isActive: gameState.lastResultCorrect && gameState.waterProgress > 0.97,
                    successPulseID: successPulseID
                )

                if let burst = activeStarBurst {
                    FlyingStarsOverlay(burst: burst)
                        .allowsHitTesting(false)
                }

                funnelsRow(
                    inlets: inlets,
                    size: size,
                    activePipeID: gameState.activePipeID,
                    isEnabled: gameState.phase == .idle,
                    pipes: pipes
                ) { pipeID in
                    feedback.playTap(using: settings)
                    gameState.startPour(pipeID: pipeID, correctPipeID: level.correctPipeID)

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 90_000_000)
                        feedback.playPourStart(using: settings)
                    }
                }

                if gameState.phase == .result {
                    resultPanel(size: size) {
                        let nextSeed = generator.nextSeed(from: resolvedSeed)
                        gameState.finishRound(nextSeed: nextSeed)
                    }
                }

                if let banner = gameState.praiseBanner {
                    praiseOverlay(size: size, banner: banner)
                        .id(banner.id)
                }

                livesPanel(size: size)
                chapterStarsPanel(
                    size: size,
                    currentChapter: gameState.currentChapter,
                    nextProgress: gameState.chapterProgressForHUD()
                )
#if DEBUG
                if settings.debugHUDEnabled {
                    answerHintPanel(size: size, correctFunnelID: level.correctPipeID)
                    progressDebugPanel(size: size)
                }
#endif

                if let lockNotice = gameState.chapterLockNotice {
                    chapterLockPanel(size: size, notice: lockNotice) {
                        gameState.dismissChapterLockNotice()
                    }
                }

                settingsButton(size: size) {
                    showingSettings = true
                }

                Text("MAZE v42")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.25), in: Capsule())
                    .position(x: size.width * 0.15, y: size.height * 0.12)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onChange(of: gameState.phase) { _, phase in
                handlePhaseChange(phase, pipes: pipes, size: size)
            }
            .onAppear {
                feedback.activateForForeground(using: settings)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    feedback.activateForForeground(using: settings)
                case .inactive, .background:
                    feedback.suspendForBackground()
                @unknown default:
                    break
                }
            }
            .sheet(isPresented: $showingSettings) {
                GameSettingsSheet(settings: settings, gameState: gameState, feedback: feedback)
            }
            .onTapGesture {
                guard gameState.phase == .result else { return }
                let nextSeed = generator.nextSeed(from: resolvedSeed)
                gameState.finishRound(nextSeed: nextSeed)
            }
        }
    }
}

private extension GameView {
    func pipesLayer(pipes: [Pipe], size: CGSize, pipeWidth: CGFloat) -> some View {
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
                            colors: [
                                Color(red: 0.56, green: 0.72, blue: 0.88, opacity: 0.44),
                                Color(red: 0.28, green: 0.4, blue: 0.54, opacity: 0.38)
                            ],
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

    func waterLayer(pipes: [Pipe], size: CGSize, pipeWidth: CGFloat) -> some View {
        ZStack {
            if let activeID = gameState.activePipeID,
               let pipe = pipes.first(where: { $0.id == activeID }) {
                let path = pipePath(points: pipe.points, size: size)
                path
                    .trim(from: 0, to: gameState.waterProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.86, blue: 1.0),
                                Color(red: 0.72, green: 0.98, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: pipeWidth * 0.55, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color(red: 0.33, green: 0.92, blue: 1.0, opacity: 0.65), radius: 12, x: 0, y: 0)
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

    func outletGlow(size: CGSize, isActive: Bool, successPulseID: UUID) -> some View {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.93)

        return ZStack {
            Circle()
                .fill(Color(red: 0.48, green: 1.0, blue: 0.75, opacity: isActive ? 0.82 : 0.34))
                .frame(width: size.width * 0.08, height: size.width * 0.08)
                .position(center)
                .shadow(
                    color: Color(red: 0.4, green: 1.0, blue: 0.8, opacity: isActive ? 0.82 : 0.32),
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
        flashPulse: Bool
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
                                    Color(red: 1.0, green: 0.45, blue: 0.4, opacity: flashPulse ? 0.95 : 0.4),
                                    lineWidth: flashPulse ? 4 : 2
                                )
                                .frame(
                                    width: size.width * (flashPulse ? 0.075 : 0.048),
                                    height: size.width * (flashPulse ? 0.075 : 0.048)
                                )
                                .shadow(
                                    color: Color(red: 1.0, green: 0.4, blue: 0.35, opacity: 0.75),
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

    func background(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.1, green: 0.14, blue: 0.2),
                    Color(red: 0.13, green: 0.18, blue: 0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.45, opacity: 0.35),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 60,
                endRadius: min(size.width, size.height) * 0.6
            )

            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: size.width * 0.7, height: size.height * 0.25)
                .blur(radius: 40)
                .offset(x: -size.width * 0.1, y: -size.height * 0.25)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    func livesPanel(size: CGSize) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<gameState.maxLives, id: \.self) { idx in
                WaterCupView(isFilled: idx < gameState.lives)
                    .frame(width: size.width * 0.055, height: size.height * 0.05)
                    .scaleEffect(idx == lostCupIndex && lostCupDropping ? 0.88 : 1)
                    .rotationEffect(.degrees(idx == lostCupIndex && lostCupDropping ? -14 : 0))
                    .offset(y: idx == lostCupIndex && lostCupDropping ? 9 : 0)
                    .overlay {
                        if idx == lostCupIndex {
                            RoundedRectangle(cornerRadius: size.width * 0.02, style: .continuous)
                                .stroke(
                                    Color(red: 1.0, green: 0.48, blue: 0.42, opacity: lostCupDropping ? 0.9 : 0.45),
                                    lineWidth: 2
                                )
                                .blur(radius: lostCupDropping ? 0 : 1)
                        }
                    }
                    .opacity(idx == lostCupIndex && lostCupDropping ? 0.6 : 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.25), in: Capsule())
        .position(x: size.width * 0.18, y: size.height * 0.958)
        .modifier(ShakeEffect(animatableData: livesShakeTick))
        .allowsHitTesting(false)
    }

    func chapterStarsPanel(
        size: CGSize,
        currentChapter: Int,
        nextProgress: ChapterProgressInfo
    ) -> some View {
        let progressText: String = {
            if nextProgress.isUnlocked {
                return "解锁第\(nextProgress.targetChapter)章 已达成"
            }
            return "解锁第\(nextProgress.targetChapter)章 \(nextProgress.earnedStars)/\(nextProgress.requiredStars)"
        }()
        let progressColor = nextProgress.isUnlocked
            ? Color(red: 0.56, green: 0.98, blue: 0.8)
            : Color.white.opacity(0.76)

        return VStack(alignment: .trailing, spacing: 2) {
            Text("⭐ \(gameState.totalStars)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("当前：第\(currentChapter)章")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
            Text(progressText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(progressColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .position(x: size.width * 0.82, y: size.height * 0.955)
        .allowsHitTesting(false)
    }

    func settingsButton(size: CGSize, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.28), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .position(x: size.width * 0.92, y: size.height * 0.12)
    }

    func answerHintPanel(size: CGSize, correctFunnelID: Int) -> some View {
        Text("Correct: F\(correctFunnelID + 1)")
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
            Text("S\(gameState.levelSeed)")
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

    func handlePhaseChange(_ phase: RoundPhase, pipes: [Pipe], size: CGSize) {
        switch phase {
        case .success:
            feedback.playSuccess(using: settings)
            playSuccessFeedback(size: size)
        case .fail:
            feedback.playFailure(using: settings)
            playFailureFeedback()
        case .idle:
            wrongOutletFlashPipeID = nil
            wrongOutletFlashPulse = false
            lostCupIndex = nil
            lostCupDropping = false
            activeStarBurst = nil
        default:
            break
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
        onDismiss: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            Text("第\(notice.targetChapter)章未解锁")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))

            Text("当前 \(notice.earnedStars)/\(notice.requiredStars) 星")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))

            Text("已回到第 \(notice.replayStartLevel) 关刷星")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.74))

            Button(action: onDismiss) {
                Text("知道了")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(
                        Color(red: 0.28, green: 0.62, blue: 0.86, opacity: 0.95),
                        in: Capsule()
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .position(x: size.width * 0.5, y: size.height * 0.24)
        .transition(.opacity)
    }

    func resultPanel(size: CGSize, onFinish: @escaping () -> Void) -> some View {
        let success = gameState.lastResultCorrect
        let outOfLives = !success && gameState.lives == 0
        let stars = gameState.lastEarnedStars
        let title: String = {
            if success { return "通关成功" }
            if outOfLives { return "水杯用完，回到第 \(gameState.checkpointLevel) 关" }
            return "失败，扣 1 杯水"
        }()
        let buttonTitle: String = {
            if success { return "下一关" }
            if outOfLives { return "重新开始" }
            return "重试"
        }()
        let subtitle: String = {
            if success { return "本关 \(stars) 星 · 总星 \(gameState.totalStars)" }
            if outOfLives { return "已回退到第 \(gameState.checkpointLevel) 关" }
            return "剩余水杯 \(gameState.lives)/\(gameState.maxLives)"
        }()

        return VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.95))

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))

            if success {
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { idx in
                        Image(systemName: idx < stars ? "star.fill" : "star")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                idx < stars
                                ? Color(red: 1.0, green: 0.86, blue: 0.36)
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
                        Color(
                            red: success ? 0.27 : 0.25,
                            green: success ? 0.75 : 0.52,
                            blue: success ? 0.52 : 0.74,
                            opacity: 0.95
                        ),
                        in: Capsule()
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
