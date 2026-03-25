import SwiftUI

struct ActionRowView: View {
    @ObservedObject var store: CommandFlowStore
    let action: SystemAction

    @State private var isHovered = false
    @State private var isPressingPlay = false

    private var status: ActionRowStatus {
        store.rowStatus(for: action)
    }

    private var disabled: Bool {
        store.isDisabled(action)
    }

    private var shortcutText: String? {
        guard let shortcut = action.shortcut?.trimmingCharacters(in: .whitespacesAndNewlines), !shortcut.isEmpty else {
            return nil
        }
        return shortcut
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(LiquidGlassTheme.rowSpring) {
                    store.perform(action)
                }
            } label: {
                HStack(spacing: 10) {
                    iconView
                    textBlock
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)

            HStack(spacing: 5) {
                Button {
                    withAnimation(LiquidGlassTheme.rowSpring) {
                        store.toggleFavorite(for: action)
                    }
                } label: {
                    Image(systemName: store.isFavorite(action) ? "star.fill" : "star")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(store.isFavorite(action) ? store.palette.accentSecondary : Color.secondary.opacity(0.68))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(store.isFavorite(action) ? "Remove from favorites" : "Add to favorites")

                Button {
                    withAnimation(LiquidGlassTheme.rowSpring) {
                        store.perform(action)
                    }
                } label: {
                    playGlyph
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill(buttonOverlayColor)
                                )
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(isPressingPlay ? 0.95 : 1.0)
                .disabled(disabled)
                .pressEvents {
                    withAnimation(.easeOut(duration: 0.12)) {
                        isPressingPlay = true
                    }
                } onRelease: {
                    withAnimation(.easeOut(duration: 0.16)) {
                        isPressingPlay = false
                    }
                }
                .help(action.name)
            }
        }
        .padding(.horizontal, store.densityMetrics.rowHorizontalPadding)
        .padding(.vertical, store.densityMetrics.rowVerticalPadding)
        .frame(minHeight: store.densityMetrics.rowHeight)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.rowRadius, style: .continuous))
        .scaleEffect(isHovered ? 1.004 : 1.0)
        .opacity(disabled ? 0.48 : 1.0)
        .onHover { hovering in
            withAnimation(LiquidGlassTheme.rowSpring) {
                isHovered = hovering
            }
        }
        .animation(LiquidGlassTheme.rowSpring, value: status)
        .animation(LiquidGlassTheme.rowSpring, value: store.isFavorite(action))
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(store.palette.accent.opacity(isHovered ? 0.18 : 0.08))
                )

            Image(systemName: action.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.9))
        }
        .frame(width: 24, height: 24)
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            Text(action.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let shortcutText {
                Text(shortcutText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.disabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var playGlyph: some View {
        switch status {
        case .idle:
            Image(systemName: disabled ? "slash.circle" : "play.fill")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.6) : Color.primary.opacity(0.92))
        case .running:
            ProgressView()
                .controlSize(.small)
        case .success:
            Image(systemName: "checkmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(store.palette.accentSecondary)
        case .failure:
            Image(systemName: "exclamationmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.secondary.opacity(0.82))
        case .confirm:
            Image(systemName: "questionmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(store.palette.accent)
        }
    }

    private var buttonOverlayColor: Color {
        switch status {
        case .idle:
            return store.palette.accent.opacity(isHovered ? 0.16 : 0.1)
        case .running:
            return store.palette.accent.opacity(0.16)
        case .success:
            return store.palette.accentSecondary.opacity(0.18)
        case .failure:
            return .white.opacity(0.08)
        case .confirm:
            return store.palette.accent.opacity(0.18)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: LiquidGlassTheme.rowRadius, style: .continuous)
            .fill(.white.opacity(backgroundOpacity))
            .overlay {
                LinearGradient(
                    colors: [
                        .white.opacity(isHovered ? 0.05 : 0.01),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.rowRadius, style: .continuous))
            }
    }

    private var backgroundOpacity: Double {
        switch status {
        case .idle:
            return isHovered ? 0.035 : 0.001
        case .running:
            return 0.05
        case .success:
            return 0.06
        case .failure:
            return 0.045
        case .confirm:
            return 0.05
        }
    }
}

private struct PressEvents: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

private extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEvents(onPress: onPress, onRelease: onRelease))
    }
}
