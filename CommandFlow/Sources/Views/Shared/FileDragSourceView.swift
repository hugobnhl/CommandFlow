import AppKit
import SwiftUI

struct FileDragSourceView: NSViewRepresentable {
    let dragItemsProvider: () -> [URL]
    let onTap: () -> Void
    let dragPreviewImageProvider: () -> NSImage
    let excludedTopLeadingSize: CGSize
    let excludedTopTrailingSize: CGSize

    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.dragItemsProvider = dragItemsProvider
        view.onTap = onTap
        view.dragPreviewImageProvider = dragPreviewImageProvider
        view.excludedTopLeadingSize = excludedTopLeadingSize
        view.excludedTopTrailingSize = excludedTopTrailingSize
        return view
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.dragItemsProvider = dragItemsProvider
        nsView.onTap = onTap
        nsView.dragPreviewImageProvider = dragPreviewImageProvider
        nsView.excludedTopLeadingSize = excludedTopLeadingSize
        nsView.excludedTopTrailingSize = excludedTopTrailingSize
    }
}

final class DragSourceNSView: NSView, NSDraggingSource {
    var dragItemsProvider: (() -> [URL])?
    var onTap: (() -> Void)?
    var dragPreviewImageProvider: (() -> NSImage)?
    var excludedTopLeadingSize = CGSize.zero
    var excludedTopTrailingSize = CGSize.zero

    private var mouseDownPoint: NSPoint?
    private var didStartDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isPointInsideExcludedCorner(point, topLeadingSize: excludedTopLeadingSize) {
            return nil
        }

        if isPointInsideExcludedCorner(point, topTrailingSize: excludedTopTrailingSize) {
            return nil
        }

        return self
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didStartDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDrag, let startPoint = mouseDownPoint else {
            return
        }

        let currentPoint = convert(event.locationInWindow, from: nil)
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
        guard distance > 3.5 else {
            return
        }

        beginDrag(with: event)
        didStartDrag = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            didStartDrag = false
        }

        guard !didStartDrag else {
            return
        }

        onTap?()
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    private func beginDrag(with event: NSEvent) {
        let urls = dragItemsProvider?() ?? []
        guard !urls.isEmpty else {
            return
        }

        let dragFrame = bounds.insetBy(dx: 6, dy: 6)
        let previewImage = dragPreviewImageProvider?() ?? NSWorkspace.shared.icon(forFile: urls[0].path)

        let draggingItems: [NSDraggingItem] = urls.map { url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(dragFrame, contents: previewImage)
            return item
        }

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    private func isPointInsideExcludedCorner(
        _ point: NSPoint,
        topLeadingSize: CGSize = .zero,
        topTrailingSize: CGSize = .zero
    ) -> Bool {
        if topLeadingSize != .zero {
            let rect = NSRect(
                x: 0,
                y: bounds.height - topLeadingSize.height,
                width: topLeadingSize.width,
                height: topLeadingSize.height
            )
            if rect.contains(point) {
                return true
            }
        }

        if topTrailingSize != .zero {
            let rect = NSRect(
                x: bounds.width - topTrailingSize.width,
                y: bounds.height - topTrailingSize.height,
                width: topTrailingSize.width,
                height: topTrailingSize.height
            )
            if rect.contains(point) {
                return true
            }
        }

        return false
    }
}
