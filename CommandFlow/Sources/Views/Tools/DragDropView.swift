import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var dragDropStore: DragDropStore

    @State private var droppedFileURL: URL?
    @State private var isTargeted = false

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "Drag & Drop",
            detail: "Drop a file to copy its path, reveal it in Finder, preview it, or open it."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                if store.shouldKeepMenuPresented {
                    statusPill
                }

                dropZone

                if let currentFile = droppedFileURL ?? dragDropStore.latestDroppedFileURL {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentFile.lastPathComponent)
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)

                        Text(currentFile.path)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                toolActions
            }
            .onChange(of: isTargeted) { _, targeted in
                store.setDragInteractionActive(targeted)
                dragDropStore.setInteractionActive(targeted)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(store.palette.accentSecondary)

            Text(store.disableAutoClose ? "Auto close disabled" : "Menu stays open during drag & drop")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(store.palette.accent.opacity(0.1))
                )
        )
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(isTargeted ? 0.78 : 0.58)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                    .fill(store.palette.accent.opacity(isTargeted ? 0.16 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                    .strokeBorder(
                        isTargeted ? store.palette.accent.opacity(0.28) : .white.opacity(0.06),
                        style: StrokeStyle(lineWidth: 1, dash: isTargeted ? [] : [6, 5])
                    )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.88))

                    Text(droppedFileURL == nil ? "Drop File Here" : "Drop Another File")
                        .font(.system(size: 11.5, weight: .semibold))

                    Text("Finder items, images, folders, or documents")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 134)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted, perform: handleDrop(providers:))
    }

    private var toolActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                toolButton("Copy latest file path", enabled: dragDropStore.latestDroppedFileURL != nil || droppedFileURL != nil) {
                    if dragDropStore.copyLatestFilePath() {
                        store.publishSuccess(title: "Path copied", detail: "The most recently dropped file path is on the clipboard.")
                    }
                }

                toolButton("Preview", enabled: dragDropStore.latestDroppedFileURL != nil || droppedFileURL != nil) {
                    if dragDropStore.previewLatestFile() {
                        store.publishSuccess(title: "Preview opened", detail: "Quick preview opened for the latest dropped file.")
                    }
                }
            }

            HStack(spacing: 8) {
                toolButton("Reveal", enabled: dragDropStore.latestDroppedFileURL != nil || droppedFileURL != nil) {
                    if dragDropStore.revealLatestFile() {
                        store.publishSuccess(title: "Revealed in Finder", detail: "The latest dropped file is selected in Finder.")
                    }
                }

                toolButton("Open", enabled: dragDropStore.latestDroppedFileURL != nil || droppedFileURL != nil) {
                    if dragDropStore.openLatestFile() {
                        store.publishSuccess(title: "File opened", detail: "The latest dropped file was opened.")
                    }
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let fileURL: URL?

            switch item {
            case let url as URL:
                fileURL = url
            case let data as Data:
                let rawValue = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                fileURL = URL(string: rawValue)
            case let rawValue as String:
                fileURL = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
            default:
                fileURL = nil
            }

            guard let fileURL, fileURL.isFileURL else {
                return
            }

            DispatchQueue.main.async {
                withAnimation(LiquidGlassTheme.panelSpring) {
                    droppedFileURL = fileURL
                    dragDropStore.registerDroppedFile(fileURL)
                    store.setDragInteractionActive(false)
                }
                store.publishSuccess(title: "File ready", detail: fileURL.lastPathComponent)
            }
        }

        return true
    }

    private func toolButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title) {
            action()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(enabled ? Color.primary.opacity(0.9) : Color.secondary.opacity(0.55))
        .frame(maxWidth: .infinity)
        .padding(.vertical, store.densityMetrics.toolButtonVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(enabled ? store.palette.accent.opacity(0.09) : .white.opacity(0.02))
                )
        )
        .disabled(!enabled)
    }
}
