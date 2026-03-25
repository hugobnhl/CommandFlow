import SwiftUI

struct ToolGlassContainer<Content: View>: View {
    @ObservedObject var store: CommandFlowStore
    let title: String
    let detail: String
    @ViewBuilder let content: () -> Content

    init(store: CommandFlowStore, title: String, detail: String, @ViewBuilder content: @escaping () -> Content) {
        self.store = store
        self.title = title
        self.detail = detail
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))

                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.62)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.055),
                                    store.palette.accent.opacity(0.05),
                                    .clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 0.7)
                )
        )
    }
}
