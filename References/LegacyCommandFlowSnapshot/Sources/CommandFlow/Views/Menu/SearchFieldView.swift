import SwiftUI

struct SearchFieldView: View {
    @ObservedObject var store: CommandFlowStore
    @Binding var text: String

    private var palette: AccentPalette {
        store.palette
    }

    private var metrics: DensityMetrics {
        store.densityMetrics
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search actions", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))

            if !text.isEmpty {
                Button {
                    withAnimation(LiquidGlassTheme.rowSpring) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, metrics.controlVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(palette.accent.opacity(0.06))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 0.7)
                )
        )
    }
}
