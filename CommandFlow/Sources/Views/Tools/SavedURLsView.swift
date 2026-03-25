import SwiftUI

struct SavedURLsView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var savedURLStore: SavedURLStore

    @State private var draftName = ""
    @State private var draftURL = ""
    @State private var renameTargetID: SavedURLItem.ID?
    @State private var renameText = ""

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "Saved URLs",
            detail: "Save links you revisit often and open them with your preferred browser."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                VStack(spacing: 8) {
                    editorField("Name", text: $draftName)
                    HStack(spacing: 8) {
                        editorField("https://example.com", text: $draftURL)

                        Button("Paste") {
                            pasteURLFromClipboard()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, store.densityMetrics.controlVerticalPadding)
                        .background(
                            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                                        .fill(store.palette.accent.opacity(0.1))
                                )
                        )
                    }

                    Button("Save URL") {
                        let added = savedURLStore.add(name: draftName, urlString: draftURL)
                        if added {
                            draftName = ""
                            draftURL = ""
                            store.publishSuccess(title: "URL saved", detail: "The link is now available in Saved URLs.")
                        } else {
                            store.publishError(title: "Invalid URL", detail: "Enter a valid link to save it.")
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
                }

                if savedURLStore.orderedItems.isEmpty {
                    Text("Saved links will appear here.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(savedURLStore.orderedItems) { item in
                        SavedURLRow(
                            item: item,
                            sortOrder: savedURLStore.sortOrder,
                            renameTargetID: $renameTargetID,
                            renameText: $renameText,
                            store: store,
                            openAction: {
                                Task {
                                    do {
                                        try await savedURLStore.open(item, using: store.preferredBrowser)
                                        store.publishSuccess(title: "URL opened", detail: item.name)
                                    } catch {
                                        store.publishError(title: "Couldn’t open URL", detail: error.localizedDescription)
                                    }
                                }
                            },
                            beginRename: {
                                renameTargetID = item.id
                                renameText = item.name
                            },
                            confirmRename: {
                                savedURLStore.rename(item, to: renameText)
                                renameTargetID = nil
                            },
                            deleteAction: {
                                savedURLStore.delete(item)
                            },
                            moveUp: {
                                savedURLStore.moveUp(item)
                            },
                            moveDown: {
                                savedURLStore.moveDown(item)
                            }
                        )
                    }
                }
            }
        }
    }

    private func editorField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, store.densityMetrics.controlVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.05), lineWidth: 0.7)
                    )
            )
    }

    private func pasteURLFromClipboard() {
        guard let clipboardValue = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !clipboardValue.isEmpty else {
            store.publishError(title: "Clipboard empty", detail: "Copy a link first, then press Paste.")
            return
        }

        draftURL = clipboardValue
        store.publishSuccess(title: "URL pasted", detail: "The link field was filled from the clipboard.")
    }
}

private struct SavedURLRow: View {
    let item: SavedURLItem
    let sortOrder: SavedURLSortOrder
    @Binding var renameTargetID: SavedURLItem.ID?
    @Binding var renameText: String
    @ObservedObject var store: CommandFlowStore
    let openAction: () -> Void
    let beginRename: () -> Void
    let confirmRename: () -> Void
    let deleteAction: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if renameTargetID == item.id {
                TextField("Name", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .onSubmit(confirmRename)
            } else {
                Text(item.name)
                    .font(.system(size: 12.5, weight: .semibold))
            }

            Text(item.urlString)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                smallButton("Open", action: openAction)
                smallButton(renameTargetID == item.id ? "Done" : "Rename", action: renameTargetID == item.id ? confirmRename : beginRename)
                smallButton("Delete", action: deleteAction)

                if sortOrder == .manual {
                    smallButton("Up", action: moveUp)
                    smallButton("Down", action: moveDown)
                }
            }
        }
        .padding(.horizontal, store.densityMetrics.rowHorizontalPadding)
        .padding(.vertical, store.densityMetrics.rowVerticalPadding + 2)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.rowRadius, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.032 : 0.01))
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(store.palette.accentSecondary)
    }
}
