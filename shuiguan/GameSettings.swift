import Combine
import SwiftUI

final class GameSettings: ObservableObject {
    private enum Defaults {
        static let soundEnabled = true
        static let hapticsEnabled = true
        static let debugHUDEnabled = false
        static let tutorialGuideCompleted = false
    }

    @Published var soundEnabled: Bool {
        didSet { storage.set(soundEnabled, forKey: StorageKey.soundEnabled) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { storage.set(hapticsEnabled, forKey: StorageKey.hapticsEnabled) }
    }

    @Published var debugHUDEnabled: Bool {
        didSet { storage.set(debugHUDEnabled, forKey: StorageKey.debugHUDEnabled) }
    }

    @Published private(set) var tutorialGuideCompleted: Bool {
        didSet { storage.set(tutorialGuideCompleted, forKey: StorageKey.tutorialGuideCompleted) }
    }

    private let storage = UserDefaults.standard

    private enum StorageKey {
        static let soundEnabled = "shuiguan.settings.soundEnabled"
        static let hapticsEnabled = "shuiguan.settings.hapticsEnabled"
        static let debugHUDEnabled = "shuiguan.settings.debugHUDEnabled"
        static let all = [soundEnabled, hapticsEnabled, debugHUDEnabled]
        static let tutorialGuideCompleted = "shuiguan.settings.tutorialGuideCompleted"
    }

    init() {
        if storage.object(forKey: StorageKey.soundEnabled) == nil {
            storage.set(Defaults.soundEnabled, forKey: StorageKey.soundEnabled)
        }
        if storage.object(forKey: StorageKey.hapticsEnabled) == nil {
            storage.set(Defaults.hapticsEnabled, forKey: StorageKey.hapticsEnabled)
        }
        if storage.object(forKey: StorageKey.debugHUDEnabled) == nil {
            storage.set(Defaults.debugHUDEnabled, forKey: StorageKey.debugHUDEnabled)
        }
        if storage.object(forKey: StorageKey.tutorialGuideCompleted) == nil {
            storage.set(Defaults.tutorialGuideCompleted, forKey: StorageKey.tutorialGuideCompleted)
        }

        self.soundEnabled = storage.bool(forKey: StorageKey.soundEnabled)
        self.hapticsEnabled = storage.bool(forKey: StorageKey.hapticsEnabled)
        self.debugHUDEnabled = storage.bool(forKey: StorageKey.debugHUDEnabled)
        self.tutorialGuideCompleted = storage.bool(forKey: StorageKey.tutorialGuideCompleted)
    }

    func resetToDefaults() {
        for key in StorageKey.all {
            storage.removeObject(forKey: key)
        }

        soundEnabled = Defaults.soundEnabled
        hapticsEnabled = Defaults.hapticsEnabled
        debugHUDEnabled = Defaults.debugHUDEnabled
    }

    func markTutorialGuideCompleted() {
        tutorialGuideCompleted = true
    }
}

struct GameSettingsSheet: View {
    @ObservedObject var settings: GameSettings
    @ObservedObject var gameState: GameState
    let feedback: FeedbackService
    let onShowGuide: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetSettingsAlert = false
    @State private var showingResetProgressAlert = false
    @State private var suppressPreview = false

    var body: some View {
        NavigationView {
            formBody
                .background(backgroundGradient)
                .navigationTitle(L10n.tr("settings.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.tr("common.done")) {
                            dismiss()
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var formBody: some View {
        let form = Form {
            feedbackSection
            debugSection
            helpSection
            dataSection
        }
        .onChange(of: settings.soundEnabled) { isEnabled in
            guard isEnabled, !suppressPreview else { return }
            feedback.previewSoundToggleEnabled()
        }
        .onChange(of: settings.hapticsEnabled) { isEnabled in
            guard isEnabled, !suppressPreview else { return }
            feedback.previewHapticsToggleEnabled()
        }
        .alert(L10n.tr("settings.resetDefaults.title"), isPresented: $showingResetSettingsAlert) {
            Button(L10n.tr("common.cancel"), role: .cancel) {}
            Button(L10n.tr("settings.resetDefaults.confirm")) {
                performWithoutPreview {
                    settings.resetToDefaults()
                }
                feedback.activateForForeground(using: settings)
            }
        } message: {
            Text(L10n.tr("settings.resetDefaults.message"))
        }
        .alert(L10n.tr("settings.resetProgress.title"), isPresented: $showingResetProgressAlert) {
            Button(L10n.tr("common.cancel"), role: .cancel) {}
            Button(L10n.tr("settings.resetProgress.confirm"), role: .destructive) {
                gameState.resetProgress()
            }
        } message: {
            Text(L10n.tr("settings.resetProgress.message"))
        }

        if #available(iOS 16.0, *) {
            form.scrollContentBackground(.hidden)
        } else {
            form
        }
    }

    private var feedbackSection: some View {
        Section {
            Toggle(L10n.tr("settings.sound"), isOn: $settings.soundEnabled)
            Toggle(L10n.tr("settings.haptics"), isOn: $settings.hapticsEnabled)
        } header: {
            Text(L10n.tr("settings.section.feedback"))
        }
    }

    @ViewBuilder
    private var debugSection: some View {
#if DEBUG
        Section {
            Toggle(L10n.tr("settings.showDebugInfo"), isOn: $settings.debugHUDEnabled)
        } header: {
            Text(L10n.tr("settings.section.debug"))
        }
#endif
    }

    private var dataSection: some View {
        Section {
            Button(L10n.tr("settings.resetDefaults")) {
                showingResetSettingsAlert = true
            }

            Button(L10n.tr("settings.resetProgress"), role: .destructive) {
                showingResetProgressAlert = true
            }
        } header: {
            Text(L10n.tr("settings.section.data"))
        } footer: {
            Text(L10n.tr("settings.dataFooter"))
        }
    }

    private var helpSection: some View {
        Section {
            Button(L10n.tr("settings.viewGuide")) {
                feedback.playTap(using: settings)
                dismiss()

                Task { @MainActor in
                    await Task.yield()
                    onShowGuide()
                }
            }
        } header: {
            Text(L10n.tr("settings.section.help"))
        } footer: {
            Text(
                settings.tutorialGuideCompleted
                    ? L10n.tr("settings.helpFooter.complete")
                    : L10n.tr("settings.helpFooter.pending")
            )
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.12),
                Color(red: 0.11, green: 0.15, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func performWithoutPreview(_ action: () -> Void) {
        suppressPreview = true
        action()

        Task { @MainActor in
            await Task.yield()
            suppressPreview = false
        }
    }
}
