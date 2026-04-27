import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var dragDropStore: DragDropStore

    @State private var focusedFileID: DroppedFileItem.ID?
    @State private var selectedFileIDs: Set<DroppedFileItem.ID> = []
    @State private var isTargeted = false

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    private var displayedItems: [DroppedFileItem] {
        Array(dragDropStore.items.reversed())
    }

    private var focusedItem: DroppedFileItem? {
        if let focusedFileID,
           let focused = dragDropStore.items.first(where: { $0.id == focusedFileID }) {
            return focused
        }

        return dragDropStore.items.last
    }

    private var selectedItems: [DroppedFileItem] {
        let explicitlySelected = displayedItems.filter { selectedFileIDs.contains($0.id) }
        if !explicitlySelected.isEmpty {
            return explicitlySelected
        }

        if let focusedItem {
            return [focusedItem]
        }

        return []
    }

    private var selectionSummaryText: String? {
        guard selectedItems.count > 1 else {
            return nil
        }

        return "\(selectedItems.count) files selected"
    }

    private var selectedFileCountText: String {
        if selectedItems.isEmpty {
            return "No file selected"
        }

        if selectedItems.count == 1 {
            return "1 file ready"
        }

        return "\(selectedItems.count) files ready"
    }

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "Drag & Drop",
            detail: "Drop files into the panel, check several to move them together, then drag them out to Finder or another app."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                if store.shouldKeepMenuPresented {
                    statusPill
                }

                dropZone

                if let focusedItem {
                    selectedFileDetails(for: focusedItem)
                }

                toolActions
            }
            .onChange(of: isTargeted) { _, targeted in
                store.setDragInteractionActive(targeted)
                dragDropStore.setInteractionActive(targeted)
            }
            .onChange(of: dragDropStore.items) { _, _ in
                syncSelection()
            }
            .onAppear {
                syncSelection()
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
                if displayedItems.isEmpty {
                    emptyDropZoneContent
                } else {
                    populatedDropZoneContent
                }
            }
            .frame(height: displayedItems.isEmpty ? 134 : 252)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted, perform: handleDrop(providers:))
    }

    private var emptyDropZoneContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))

            Text("Drop File Here")
                .font(.system(size: 11.5, weight: .semibold))

            Text("Finder items, images, folders, or documents")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var populatedDropZoneContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drag files out of CommandFlow")
                        .font(.system(size: 11.5, weight: .semibold))

                    Text(selectedFileCountText)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let selectionSummaryText {
                    Text(selectionSummaryText)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(dragDropStore.items.count)/10")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(displayedItems) { item in
                    DragDropLibraryItemView(
                        item: item,
                        isSelected: selectedFileIDs.contains(item.id),
                        palette: store.palette,
                        dragItemsProvider: { dragItems(for: item) },
                        onSelect: {
                            focusedFileID = item.id
                        },
                        onToggleSelection: {
                            toggleSelection(for: item)
                        },
                        onDelete: {
                            remove(item)
                        }
                    )
                }
            }

            if !selectedItems.isEmpty {
                HStack(spacing: 8) {
                    Text("Check several tiles to drag them together.")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Button("Clear selection") {
                        selectedFileIDs.removeAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(store.palette.accentSecondary)
                }
            }
        }
        .padding(12)
    }

    private func selectedFileDetails(for item: DroppedFileItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)

            Text(item.path)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var toolActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                toolButton("Copy path", enabled: !selectedItems.isEmpty) {
                    if dragDropStore.copyFilePaths(for: selectedItems), let focusedItem {
                        store.publishSuccess(
                            title: selectedItems.count == 1 ? "Path copied" : "Paths copied",
                            detail: focusedItem.name
                        )
                    }
                }

                toolButton("Quick Look", enabled: !selectedItems.isEmpty) {
                    if dragDropStore.previewFiles(selectedItems), let focusedItem {
                        store.publishSuccess(title: "Quick Look opened", detail: focusedItem.name)
                    }
                }
            }

            HStack(spacing: 8) {
                toolButton("Reveal", enabled: !selectedItems.isEmpty) {
                    if dragDropStore.revealFiles(selectedItems), let focusedItem {
                        store.publishSuccess(title: "Revealed in Finder", detail: focusedItem.name)
                    }
                }

                toolButton("Open", enabled: !selectedItems.isEmpty) {
                    if dragDropStore.openFiles(selectedItems), let focusedItem {
                        store.publishSuccess(title: "File opened", detail: focusedItem.name)
                    }
                }
            }

            HStack(spacing: 8) {
                toolButton("Remove", enabled: !selectedItems.isEmpty) {
                    removeSelectedItems()
                }

                toolButton("Copy latest", enabled: dragDropStore.latestDroppedFileURL != nil) {
                    if dragDropStore.copyLatestFilePath() {
                        store.publishSuccess(title: "Latest path copied", detail: dragDropStore.latestDroppedFileURL?.lastPathComponent ?? "File")
                    }
                }
            }
        }
    }

    private func dragItems(for item: DroppedFileItem) -> [URL] {
        let selected = selectedItems
        if selected.count > 1, selected.contains(where: { $0.id == item.id }) {
            return selected.map(\.url)
        }

        return [item.url]
    }

    private func toggleSelection(for item: DroppedFileItem) {
        if selectedFileIDs.contains(item.id) {
            selectedFileIDs.remove(item.id)
        } else {
            selectedFileIDs.insert(item.id)
            focusedFileID = item.id
        }
    }

    private func syncSelection() {
        let availableIDs = Set(dragDropStore.items.map(\.id))
        selectedFileIDs = selectedFileIDs.intersection(availableIDs)

        if let focusedFileID, availableIDs.contains(focusedFileID) {
            return
        }

        focusedFileID = dragDropStore.items.last?.id
    }

    private func remove(_ item: DroppedFileItem) {
        dragDropStore.remove(item)
        selectedFileIDs.remove(item.id)
        store.publishSuccess(title: "File removed", detail: item.name)
        syncSelection()
    }

    private func removeSelectedItems() {
        let itemsToRemove = selectedItems
        guard !itemsToRemove.isEmpty else {
            return
        }

        dragDropStore.remove(itemsToRemove)
        selectedFileIDs.subtract(Set(itemsToRemove.map(\.id)))
        if let focusedItem = itemsToRemove.first {
            store.publishSuccess(title: "File removed", detail: focusedItem.name)
        }
        syncSelection()
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else {
            return false
        }

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let fileURL = resolvedFileURL(from: item), fileURL.isFileURL else {
                    return
                }

                DispatchQueue.main.async {
                    withAnimation(LiquidGlassTheme.panelSpring) {
                        let droppedItem = dragDropStore.registerDroppedFile(fileURL)
                        focusedFileID = droppedItem.id
                        selectedFileIDs = [droppedItem.id]
                        store.setDragInteractionActive(false)
                    }

                    store.publishSuccess(title: "File ready", detail: fileURL.lastPathComponent)
                }
            }
        }

        return true
    }

    private func resolvedFileURL(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL:
            return url
        case let data as Data:
            let rawValue = String(bytes: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return rawValue.flatMap(URL.init(string:))
        case let rawValue as String:
            return URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
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

private struct DragDropLibraryItemView: View {
    let item: DroppedFileItem
    let isSelected: Bool
    let palette: AccentPalette
    let dragItemsProvider: () -> [URL]
    let onSelect: () -> Void
    let onToggleSelection: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var iconImage: NSImage {
        let image = NSWorkspace.shared.icon(forFile: item.path)
        image.size = NSSize(width: 40, height: 40)
        return image
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? palette.accent.opacity(0.16) : .white.opacity(isHovered ? 0.06 : 0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? palette.accent.opacity(0.34) : .white.opacity(0.05), lineWidth: 0.8)
                )

            VStack(spacing: 6) {
                Image(nsImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .padding(.top, 6)

                Text(item.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }

            FileDragSourceView(
                dragItemsProvider: dragItemsProvider,
                onTap: onSelect,
                dragPreviewImageProvider: { iconImage },
                excludedTopLeadingSize: CGSize(width: 22, height: 22),
                excludedTopTrailingSize: CGSize(width: 22, height: 22)
            )

            HStack {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? palette.accentSecondary : .secondary.opacity(0.7))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 66, height: 78)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
        .help(item.name)
    }
}
