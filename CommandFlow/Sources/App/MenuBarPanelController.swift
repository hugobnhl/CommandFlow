import AppKit
import Combine
import OSLog
import SwiftUI

@MainActor
final class CommandFlowAppModel {
    let store = CommandFlowStore()
    let clipboardHistoryStore = ClipboardHistoryStore()
    let savedURLStore = SavedURLStore()
    let quickNoteStore = QuickNoteStore()
    let dragDropStore = DragDropStore()

    private lazy var panelController = MenuBarPanelController(
        store: store,
        rootViewProvider: { [weak self] in
            guard let self else {
                return AnyView(EmptyView())
            }

            return AnyView(
                CommandFlowMenuView(
                    store: store,
                    clipboardStore: clipboardHistoryStore,
                    savedURLStore: savedURLStore,
                    quickNoteStore: quickNoteStore,
                    dragDropStore: dragDropStore,
                    onOpenSettings: { [weak self] in self?.showSettings() },
                    onOpenOnboarding: { [weak self] in self?.presentOnboarding() },
                    onDismissMenu: { [weak self] in self?.dismissMenu() }
                )
            )
        }
    )

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "app"
    )

    private var settingsWindowController: NSWindowController?
    private var onboardingWindowController: NSWindowController?
    private var isOnboardingPresentedManually = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        store.$permissionSnapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else {
                    return
                }

                if snapshot.accessibilityGranted {
                    if !isOnboardingPresentedManually {
                        dismissOnboarding()
                    }
                } else if store.shouldShowSetupPrompt {
                    presentOnboarding()
                }
            }
            .store(in: &cancellables)

        store.$isDragInteractionActive
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                self?.dragDropStore.setInteractionActive(active)
            }
            .store(in: &cancellables)
    }

    func start() {
        panelController.start()

        if store.shouldShowSetupPrompt {
            presentOnboarding()
        }
    }

    func makeSettingsView() -> SettingsView {
        SettingsView(
            store: store,
            clipboardStore: clipboardHistoryStore,
            savedURLStore: savedURLStore,
            quickNoteStore: quickNoteStore,
            showOnboarding: { [weak self] in
                self?.presentOnboarding(manual: true)
            }
        )
    }

    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        store.refreshPermissions()

        if settingsWindowController == nil {
            let hostingController = NSHostingController(rootView: makeSettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "CommandFlow Settings"
            window.identifier = NSUserInterfaceItemIdentifier("CommandFlowSettingsWindow")
            window.isReleasedWhenClosed = false
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.setContentSize(NSSize(width: 620, height: 760))
            window.center()
            settingsWindowController = NSWindowController(window: window)
            logger.info("Created settings window controller")
        }

        logger.info("Opening settings window")
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        settingsWindowController?.window?.orderFrontRegardless()
    }

    func presentOnboarding() {
        presentOnboarding(manual: false)
    }

    func presentOnboarding(manual: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        isOnboardingPresentedManually = manual
        store.markOnboardingPresented()

        if onboardingWindowController == nil {
            let rootView = OnboardingView(
                store: store,
                onDismiss: { [weak self] in self?.dismissOnboarding() }
            )

            let hostingController = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hostingController)
            window.title = "CommandFlow Setup"
            window.isReleasedWhenClosed = false
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.setContentSize(NSSize(width: 490, height: 590))
            window.center()
            onboardingWindowController = NSWindowController(window: window)
            logger.info("Created onboarding window controller")
        }

        logger.info("Opening onboarding window")
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }

    func dismissOnboarding() {
        logger.info("Closing onboarding window")
        isOnboardingPresentedManually = false
        onboardingWindowController?.close()
    }

    func dismissMenu() {
        panelController.closePanel()
    }
}

@MainActor
final class MenuBarPanelController: NSObject, NSWindowDelegate {
    private let store: CommandFlowStore
    private let rootViewProvider: () -> AnyView
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private var panel: AttachedMenuPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var appStateObservers = Set<AnyCancellable>()
    private var detachedOrigin: CGPoint?

    init(store: CommandFlowStore, rootViewProvider: @escaping () -> AnyView) {
        self.store = store
        self.rootViewProvider = rootViewProvider
        super.init()
    }

    func start() {
        configureStatusItem()
        configureObservers()
    }

    func closePanel() {
        panel?.orderOut(nil)
        statusItem.button?.state = .off
        removeEventMonitors()
    }

    @objc
    private func togglePanel() {
        if panel?.isVisible == true {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        let panel = makePanelIfNeeded()
        if store.attachToMenuBar || detachedOrigin == nil {
            positionPanel(animated: false)
        } else if let detachedOrigin {
            panel.setFrameOrigin(detachedOrigin)
        }

        panel.isMovableByWindowBackground = !store.attachToMenuBar

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        positionPanel(animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.positionPanel(animated: false)
        }
        statusItem.button?.state = .on
        installEventMonitors()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp])
        button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "CommandFlow")
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.toolTip = "CommandFlow"
    }

    private func makePanelIfNeeded() -> AttachedMenuPanel {
        if let panel {
            return panel
        }

        let rect = NSRect(x: 0, y: 0, width: LiquidGlassTheme.menuWidth, height: LiquidGlassTheme.menuHeight)
        let panel = AttachedMenuPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self
        panel.animationBehavior = .utilityWindow

        let hostingController = NSHostingController(rootView: rootViewProvider())
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController

        self.panel = panel
        return panel
    }

    private func configureObservers() {
        store.$attachToMenuBar
            .receive(on: RunLoop.main)
            .sink { [weak self] attach in
                guard let self, let panel = self.panel else {
                    return
                }

                panel.isMovableByWindowBackground = !attach
                if attach, panel.isVisible {
                    self.positionPanel(animated: true)
                }
            }
            .store(in: &appStateObservers)

        store.$isDragInteractionActive
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                guard let self else {
                    return
                }

                if !isActive, !store.disableAutoClose, !NSApp.isActive {
                    self.closePanel()
                }
            }
            .store(in: &appStateObservers)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, store.attachToMenuBar, panel?.isVisible == true else {
                    return
                }
                self.positionPanel(animated: true)
            }
            .store(in: &appStateObservers)

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }

                dismissTransientPanels()

                if !store.shouldKeepMenuPresented {
                    self.closePanel()
                }
            }
            .store(in: &appStateObservers)
    }

    private func positionPanel(animated: Bool) {
        guard let panel, let button = statusItem.button, let buttonWindow = button.window else {
            return
        }

        let buttonRect = button.convert(button.bounds, to: nil)
        let buttonFrame = buttonWindow.convertToScreen(buttonRect)
        let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var origin = CGPoint(
            x: buttonFrame.midX - (panel.frame.width / 2),
            y: buttonFrame.minY - panel.frame.height - 8
        )

        origin.x = min(max(origin.x, screen.minX + 10), screen.maxX - panel.frame.width - 10)
        origin.y = min(max(origin.y, screen.minY + 12), screen.maxY - panel.frame.height - 12)

        if animated {
            panel.setFrameOrigin(origin)
        } else {
            panel.setFrame(panel.frame.offsetBy(dx: origin.x - panel.frame.minX, dy: origin.y - panel.frame.minY), display: false)
        }
    }

    private func installEventMonitors() {
        removeEventMonitors()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            guard let self else {
                return event
            }

            if event.type == .keyDown {
                if event.keyCode == 53 {
                    self.closePanel()
                    return nil
                }

                return event
            }

            guard self.panel?.isVisible == true else {
                return event
            }

            if self.shouldIgnoreDismiss(for: event) {
                return event
            }

            self.closePanel()
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self, self.panel?.isVisible == true else {
                return
            }

            if self.shouldIgnoreDismiss(for: event) {
                return
            }

            self.closePanel()
        }
    }

    private func removeEventMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func dismissTransientPanels() {
        if NSColorPanel.sharedColorPanelExists {
            NSColorPanel.shared.close()
        }
    }

    private func shouldIgnoreDismiss(for event: NSEvent) -> Bool {
        if store.shouldKeepMenuPresented {
            return true
        }

        let screenPoint = eventScreenLocation(event)
        if let panel, panel.frame.contains(screenPoint) {
            return true
        }

        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonFrame.contains(screenPoint) {
                return true
            }
        }

        return false
    }

    private func eventScreenLocation(_ event: NSEvent) -> CGPoint {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return event.locationInWindow
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel, panel.isVisible, !store.attachToMenuBar else {
            return
        }
        detachedOrigin = panel.frame.origin
    }
}

final class AttachedMenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
