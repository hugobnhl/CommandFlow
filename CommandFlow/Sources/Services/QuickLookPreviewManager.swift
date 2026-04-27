import AppKit
import Foundation
import QuickLookUI

final class QuickLookPreviewManager: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreviewManager()

    private var previewItems: [URL] = []
    private var sourceFrameOnScreen: NSRect = .zero

    func present(items: [URL], sourceFrameOnScreen: NSRect = .zero) {
        guard !items.isEmpty else {
            return
        }

        guard let panel = QLPreviewPanel.shared() else {
            _ = NSWorkspace.shared.open(items[0])
            return
        }

        previewItems = items
        self.sourceFrameOnScreen = sourceFrameOnScreen

        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = 0
        panel.reloadData()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItems.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> any QLPreviewItem {
        previewItems[index] as NSURL
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: (any QLPreviewItem)?) -> NSRect {
        sourceFrameOnScreen
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        if event.type == .keyDown, event.keyCode == 53 {
            panel.orderOut(nil)
            return true
        }

        return false
    }
}
