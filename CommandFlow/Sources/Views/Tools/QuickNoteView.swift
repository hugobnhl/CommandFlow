import SwiftUI

struct QuickNoteView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var quickNoteStore: QuickNoteStore

    @State private var draftText = ""

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "QuickNote",
            detail: "Jot something down instantly. Notes stay until you delete them."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                TextEditor(text: $draftText)
                    .font(.system(size: 12.5, weight: .medium))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 86)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                                    .strokeBorder(.white.opacity(0.05), lineWidth: 0.7)
                            )
                    )

                Button("Save note") {
                    quickNoteStore.add(text: draftText)
                    if !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        draftText = ""
                        store.publishSuccess(title: "Note saved", detail: "Your note stays here until you delete it.")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, store.densityMetrics.toolButtonVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                                .fill(store.palette.accent.opacity(0.12))
                        )
                )

                if quickNoteStore.notes.isEmpty {
                    Text("Your saved notes will appear here.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(quickNoteStore.notes) { note in
                        QuickNoteRow(note: note, store: store) {
                            quickNoteStore.delete(note)
                        }
                    }
                }
            }
        }
    }
}

private struct QuickNoteRow: View {
    let note: QuickNoteItem
    @ObservedObject var store: CommandFlowStore
    let deleteAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(relativeDate)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Button("Delete", action: deleteAction)
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(store.palette.accentSecondary)
            }
        }
        .padding(.horizontal, store.densityMetrics.rowHorizontalPadding)
        .padding(.vertical, store.densityMetrics.rowVerticalPadding + 2)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.rowRadius, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.03 : 0.012))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: note.updatedAt, relativeTo: .now)
    }
}
