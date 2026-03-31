import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var gameState = GameState()
    @StateObject private var settings = GameSettings()
    @StateObject private var feedback = FeedbackService()
    @State private var showingGame = false

    var body: some View {
        ZStack {
            if showingGame {
                GameView(
                    gameState: gameState,
                    settings: settings,
                    feedback: feedback,
                    onExit: exitToHome
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            } else {
                HomeView(
                    gameState: gameState,
                    settings: settings,
                    feedback: feedback,
                    onContinue: startCurrentGame,
                    onPlayLevel: startSelectedLevel
                )
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showingGame)
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
}
