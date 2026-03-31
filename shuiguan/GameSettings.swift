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
        NavigationStack {
            Form {
                feedbackSection
                debugSection
                helpSection
                dataSection
            }
            .scrollContentBackground(.hidden)
            .background(backgroundGradient)
            .onChange(of: settings.soundEnabled) { _, isEnabled in
                guard isEnabled, !suppressPreview else { return }
                feedback.previewSoundToggleEnabled()
            }
            .onChange(of: settings.hapticsEnabled) { _, isEnabled in
                guard isEnabled, !suppressPreview else { return }
                feedback.previewHapticsToggleEnabled()
            }
            .alert("恢复默认设置？", isPresented: $showingResetSettingsAlert) {
                Button("取消", role: .cancel) {}
                Button("恢复") {
                    performWithoutPreview {
                        settings.resetToDefaults()
                    }
                    feedback.activateForForeground(using: settings)
                }
            } message: {
                Text("音效、震动和调试显示会恢复为默认值。")
            }
            .alert("重置游戏进度？", isPresented: $showingResetProgressAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    gameState.resetProgress()
                }
            } message: {
                Text("这会回到第 1 关，并清空已获得的星级和检查点。")
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var feedbackSection: some View {
        Section("反馈") {
            Toggle("音效", isOn: $settings.soundEnabled)
            Toggle("震动", isOn: $settings.hapticsEnabled)
        }
    }

    @ViewBuilder
    private var debugSection: some View {
#if DEBUG
        Section("调试") {
            Toggle("显示调试信息", isOn: $settings.debugHUDEnabled)
        }
#endif
    }

    private var dataSection: some View {
        Section {
            Button("恢复默认设置") {
                showingResetSettingsAlert = true
            }

            Button("重置游戏进度", role: .destructive) {
                showingResetProgressAlert = true
            }
        } header: {
            Text("数据")
        } footer: {
            Text("重置进度会清空关卡、星级和检查点记录。")
        }
    }

    private var helpSection: some View {
        Section {
            Button("查看玩法说明") {
                feedback.playTap(using: settings)
                dismiss()

                Task { @MainActor in
                    await Task.yield()
                    onShowGuide()
                }
            }
        } header: {
            Text("帮助")
        } footer: {
            Text(settings.tutorialGuideCompleted ? "可以随时重新查看玩法说明。" : "首次玩法说明还未完成。")
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
