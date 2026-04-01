import SwiftUI

private struct GameplayGuideStep: Identifiable {
    let id: Int
    let symbol: String
    let eyebrow: String
    let title: String
    let detail: String
}

struct GameplayGuideOverlay: View {
    let isFirstRun: Bool
    let onClose: () -> Void

    @State private var page = 0

    private var steps: [GameplayGuideStep] {
        [
            GameplayGuideStep(
                id: 0,
                symbol: "hand.tap.fill",
                eyebrow: L10n.tr("guide.stepLabel", L10n.int(1)),
                title: L10n.tr("guide.step1.title"),
                detail: L10n.tr("guide.step1.detail")
            ),
            GameplayGuideStep(
                id: 1,
                symbol: "arrow.triangle.branch",
                eyebrow: L10n.tr("guide.stepLabel", L10n.int(2)),
                title: L10n.tr("guide.step2.title"),
                detail: L10n.tr("guide.step2.detail")
            ),
            GameplayGuideStep(
                id: 2,
                symbol: "drop.triangle.fill",
                eyebrow: L10n.tr("guide.stepLabel", L10n.int(3)),
                title: L10n.tr("guide.step3.title"),
                detail: L10n.tr("guide.step3.detail")
            )
        ]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.60)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(current.eyebrow)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color(red: 0.63, green: 0.97, blue: 0.98))

                        Text(current.title)
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                    }

                    Spacer(minLength: 12)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.86))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.26, green: 0.80, blue: 1.0),
                                        Color(red: 0.18, green: 0.62, blue: 0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: current.symbol)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(Color.white)
                    }
                    .frame(width: 74, height: 74)

                    Text(current.detail)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    ForEach(steps) { step in
                        Capsule()
                            .fill(step.id == current.id ? Color.white.opacity(0.92) : Color.white.opacity(0.18))
                            .frame(width: step.id == current.id ? 28 : 10, height: 8)
                    }
                }

                HStack(spacing: 10) {
                    if page > 0 {
                        Button(L10n.tr("common.previous")) {
                            page = max(page - 1, 0)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if isFirstRun {
                        Button(L10n.tr("common.skip")) {
                            onClose()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Spacer(minLength: 8)

                    if page < steps.count - 1 {
                        Button(L10n.tr("common.next")) {
                            page += 1
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.63, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Button(isFirstRun ? L10n.tr("guide.finishFirstRun") : L10n.tr("guide.finish")) {
                            onClose()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.63, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 360, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.13, blue: 0.22),
                        Color(red: 0.07, green: 0.19, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 22)
            .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 14)
        }
    }

    private var current: GameplayGuideStep {
        steps[min(max(page, 0), steps.count - 1)]
    }
}
