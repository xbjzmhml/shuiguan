import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var gameState = GameState()
    @StateObject private var settings = GameSettings()
    @StateObject private var feedback = FeedbackService()
    @State private var showingGame = false
    @State private var showingGuide = false
    @State private var guideStartedAsFirstRun = false
    @State private var autoGuideChecked = false

    var body: some View {
        ZStack {
            if showingGame {
                GameView(
                    gameState: gameState,
                    settings: settings,
                    feedback: feedback,
                    onExit: exitToHome,
                    onShowGuide: { presentGuide() }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            } else {
                HomeView(
                    gameState: gameState,
                    settings: settings,
                    feedback: feedback,
                    onContinue: startCurrentGame,
                    onPlayLevel: startSelectedLevel,
                    onShowGuide: { presentGuide() }
                )
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
            }

            if showingGuide {
                GameplayGuideOverlay(
                    isFirstRun: guideStartedAsFirstRun,
                    onClose: dismissGuide
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showingGame)
        .onAppear {
            feedback.activateForForeground(using: settings)
            if !autoGuideChecked {
                autoGuideChecked = true
                if !settings.tutorialGuideCompleted {
                    presentGuide(firstRun: true)
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                feedback.activateForForeground(using: settings)
            case .inactive, .background:
                feedback.suspendForBackground()
            @unknown default:
                break
            }
        }
    }

    private func startCurrentGame() {
        showingGame = true
    }

    private func startSelectedLevel(_ level: Int) {
        guard gameState.selectLevel(level) else { return }
        showingGame = true
    }

    private func exitToHome() {
        gameState.prepareForMenu()
        showingGame = false
    }

    private func presentGuide(firstRun: Bool = false) {
        guideStartedAsFirstRun = firstRun && !settings.tutorialGuideCompleted
        showingGuide = true
    }

    private func dismissGuide() {
        if !settings.tutorialGuideCompleted {
            settings.markTutorialGuideCompleted()
        }
        showingGuide = false
        guideStartedAsFirstRun = false
    }
}
