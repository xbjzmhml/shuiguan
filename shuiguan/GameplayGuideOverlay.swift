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

    private let steps = [
        GameplayGuideStep(
            id: 0,
            symbol: "hand.tap.fill",
            eyebrow: "STEP 1",
            title: "点上方入口开始放水",
            detail: "每次只能选一根漏斗。水会顺着你选中的那条管路一直流下去。"
        ),
        GameplayGuideStep(
            id: 1,
            symbol: "arrow.triangle.branch",
            eyebrow: "STEP 2",
            title: "看清最终是不是流进主管",
            detail: "拐弯、交叉和回环都会干扰判断。只有最后汇入下方主管的那根才是正确入口。"
        ),
        GameplayGuideStep(
            id: 2,
            symbol: "drop.triangle.fill",
            eyebrow: "STEP 3",
            title: "失误会扣水杯，但星级会保留",
            detail: "选错会扣 1 杯水，水杯用完回到检查点。回放旧关只刷新最佳星级，不会覆盖主线进度。"
        )
    ]

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
                        Button("上一步") {
                            page = max(page - 1, 0)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if isFirstRun {
                        Button("跳过") {
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
                        Button("下一步") {
                            page += 1
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.63, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Button(isFirstRun ? "开始试玩" : "关闭说明") {
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
