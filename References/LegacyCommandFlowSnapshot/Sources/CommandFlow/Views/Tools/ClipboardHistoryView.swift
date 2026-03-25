import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var preferences: CommandFlowStore

    var body: some View {
        ToolGlassContainer(
            store: preferences,
            title: "Clipboard History",
            detail: "The last \(store.limit) copied text snippets, ready to restore or paste again."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(store.items.count) items")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    if !store.items.isEmpty {
                        Button("Clear clipboard history") {
                            store.clear()
                            preferences.publishSuccess(title: "Clipboard cleared", detail: "Saved clipboard history was deleted.")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(preferences.palette.accentSecondary)
                    }
                }

                if store.items.isEmpty {
                    Text("Copy any text and it will appear here.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.items) { item in
                        ClipboardItemRow(item: item, isHighlighted: store.lastCopiedItemID == item.id, preferences: preferences) {
                            store.copy(item)
                            preferences.publishSuccess(title: "Copied again", detail: "The clipboard item is active again.")
                        } pasteAction: {
                            store.paste(item)
                            preferences.publishSuccess(title: "Paste sent", detail: "The selected clipboard item was pasted.")
                        }
                    }
                }
            }
        }
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardHistoryItem
    let isHighlighted: Bool
    @ObservedObject var preferences: CommandFlowStore
    let copyAction: () -> Void
    let pasteAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: copyAction) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(previewLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(metaLine)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: pasteAction) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.84))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .fill(preferences.palette.accent.opacity(isHighlighted ? 0.16 : 0.08))
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, preferences.densityMetrics.rowHorizontalPadding)
        .padding(.vertical, preferences.densityMetrics.rowVerticalPadding + 1)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.rowRadius, style: .continuous)
                .fill(.white.opacity(isHighlighted ? 0.05 : (isHovered ? 0.028 : 0.001)))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private var previewLine: String {
        item.value
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var metaLine: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.createdAt, relativeTo: .now)
    }
}
