import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var dragDropStore: DragDropStore

    @State private var selectedFileID: DroppedFileItem.ID?
    @State private var isTargeted = false
    @State private var panelBounds: CGRect = .zero
    @State private var dragOffsets: [DroppedFileItem.ID: CGSize] = [:]

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    private var displayedItems: [DroppedFileItem] {
        Array(dragDropStore.items.reversed())
    }

    private var selectedItem: DroppedFileItem? {
        if let selectedFileID,
           let selected = dragDropStore.items.first(where: { $0.id == selectedFileID }) {
            return selected
        }

        return dragDropStore.items.last
    }

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "Drag & Drop",
            detail: "Keep up to 10 files handy, preview them, reveal them, or remove them one by one."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                if store.shouldKeepMenuPresented {
                    statusPill
                }

                dropZone

                if let selectedItem {
                    selectedFileDetails(for: selectedItem)
                }

                toolActions
            }
            .coordinateSpace(name: "drag-drop-root")
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DragDropPanelBoundsPreferenceKey.self,
                        value: proxy.frame(in: .named("drag-drop-root"))
                    )
                }
            )
            .onPreferenceChange(DragDropPanelBoundsPreferenceKey.self) { panelBounds = $0 }
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
            .frame(height: displayedItems.isEmpty ? 134 : 228)
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
                Text("Drop Another File")
                    .font(.system(size: 11.5, weight: .semibold))

                Spacer(minLength: 12)

                Text("\(dragDropStore.items.count)/10")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(displayedItems) { item in
                    DragDropLibraryItemView(
                        item: item,
                        isSelected: selectedItem?.id == item.id,
                        palette: store.palette,
                        offset: dragOffsets[item.id] ?? .zero,
                        onTap: {
                            selectedFileID = item.id
                        },
                        onDelete: {
                            remove(item)
                        },
                        onDragChanged: { value in
                            selectedFileID = item.id
                            dragOffsets[item.id] = value.translation
                        },
                        onDragEnded: { value in
                            let shouldRemove = !panelBounds.insetBy(dx: -10, dy: -10).contains(value.location)
                            withAnimation(LiquidGlassTheme.rowSpring) {
                                dragOffsets[item.id] = .zero
                            }

                            if shouldRemove {
                                remove(item)
                            }
                        }
                    )
                }
            }

            Text("Drag an icon outside this panel or press x to remove it.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
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
                toolButton("Copy selected path", enabled: selectedItem != nil) {
                    if dragDropStore.copyFilePath(for: selectedItem), let selectedItem {
                        store.publishSuccess(title: "Path copied", detail: selectedItem.name)
                    }
                }

                toolButton("Preview", enabled: selectedItem != nil) {
                    if dragDropStore.previewFile(selectedItem), let selectedItem {
                        store.publishSuccess(title: "Preview opened", detail: selectedItem.name)
                    }
                }
            }

            HStack(spacing: 8) {
                toolButton("Reveal", enabled: selectedItem != nil) {
                    if dragDropStore.revealFile(selectedItem), let selectedItem {
                        store.publishSuccess(title: "Revealed in Finder", detail: selectedItem.name)
                    }
                }

                toolButton("Open", enabled: selectedItem != nil) {
                    if dragDropStore.openFile(selectedItem), let selectedItem {
                        store.publishSuccess(title: "File opened", detail: selectedItem.name)
                    }
                }
            }
        }
    }

    private func syncSelection() {
        if let selectedFileID,
           dragDropStore.items.contains(where: { $0.id == selectedFileID }) {
            return
        }

        selectedFileID = dragDropStore.items.last?.id
    }

    private func remove(_ item: DroppedFileItem) {
        dragDropStore.remove(item)
        store.publishSuccess(title: "File removed", detail: item.name)
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
                        selectedFileID = droppedItem.id
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
    let offset: CGSize
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    @State private var isHovered = false

    private var iconImage: NSImage {
        let image = NSWorkspace.shared.icon(forFile: item.path)
        image.size = NSSize(width: 40, height: 40)
        return image
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            Image(nsImage: iconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .padding(10)

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(6)
            .opacity(isHovered || isSelected ? 1 : 0.62)
        }
        .frame(width: 58, height: 58)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .offset(offset)
        .onTapGesture(perform: onTap)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
        .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("drag-drop-root"))
                .onChanged(onDragChanged)
                .onEnded(onDragEnded)
        )
        .help(item.name)
    }
}

private struct DragDropPanelBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
