import SwiftUI

struct CommandFlowMenuView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var clipboardStore: ClipboardHistoryStore
    @ObservedObject var savedURLStore: SavedURLStore
    @ObservedObject var quickNoteStore: QuickNoteStore
    @ObservedObject var dragDropStore: DragDropStore
    @ObservedObject var updateService: AppUpdateService
    let onOpenSettings: () -> Void
    let onRelaunchApplication: () -> Void
    let onOpenOnboarding: () -> Void
    let onDismissMenu: () -> Void

    @State private var activeTool: MenuToolPanel?
    @State private var isKeyboardSoundPopoverPresented = false

    private var toolStripColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8), count: 3)
    }

    private var visibleActions: [SystemAction] {
        store.groupedActions.flatMap(\.actions)
    }

    private var favoriteActions: [SystemAction] {
        visibleActions.filter { store.isFavorite($0) }
    }

    private var categorizedActions: [MenuCategorySection] {
        let grouped = Dictionary(grouping: visibleActions, by: MenuPresentationCategory.init(action:))

        return MenuPresentationCategory.orderedCases.compactMap { category in
            guard let actions = grouped[category], !actions.isEmpty else {
                return nil
            }
            return MenuCategorySection(category: category, actions: actions)
        }
    }

    private var keyboardSoundEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.keyboardSoundEnabled },
            set: { store.setKeyboardSoundEnabled($0) }
        )
    }

    private var keyboardSoundVolumeBinding: Binding<Double> {
        Binding(
            get: { store.keyboardSoundVolume },
            set: { store.setKeyboardSoundVolume($0) }
        )
    }

    private var keyboardSoundStatusText: String {
        if !store.keyboardSoundEnabled {
            return "Off"
        }

        return store.permissionSnapshot.inputMonitoringGranted ? "On" : "Pending"
    }

    private var keyboardSoundDetailText: String {
        if store.permissionSnapshot.inputMonitoringGranted {
            return "Mechanical feedback stays mixed behind your audio."
        }

        if store.keyboardSoundEnabled {
            return "Keyboard sound is enabled, but macOS still has to confirm Input Monitoring before playback can start."
        }

        return "Input Monitoring is required for global keyboard feedback. Toggle once to request access, then update permissions in Settings."
    }

    var body: some View {
        ZStack {
            Color.clear
            VisionGlassPanel(store: store)

            VStack(spacing: store.densityMetrics.stackSpacing) {
                header
                SearchFieldView(store: store, text: $store.searchText)
                toolStrip

                if store.disableAutoClose || store.isDragInteractionActive || store.isDragDropToolActive {
                    keepOpenBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if store.shouldShowSetupPrompt {
                    setupPrompt
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let availableRelease = updateService.availableRelease {
                    updatePrompt(for: availableRelease)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let banner = store.feedbackBanner {
                    feedbackBanner(banner)
                        .transition(.opacity)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let activeTool {
                            featurePanel(for: activeTool)
                                .transition(.scale(scale: 0.985).combined(with: .opacity))
                                .padding(.top, 2)
                        } else {
                            if !store.quickActions.isEmpty {
                                quickAccessSection
                                    .padding(.bottom, store.densityMetrics.sectionSpacing)
                            }

                            if let lastUsed = store.lastUsedAction, !store.isDisabled(lastUsed) {
                                listSection(title: "Last Used Action", actions: [lastUsed])
                            }

                            if !favoriteActions.isEmpty {
                                listSection(title: "Favorites", actions: favoriteActions)
                            }

                            ForEach(categorizedActions) { section in
                                listSection(title: section.category.rawValue, actions: section.actions)
                            }

                            if visibleActions.isEmpty {
                                emptyState
                                    .padding(.top, 12)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(width: LiquidGlassTheme.menuWidth, height: LiquidGlassTheme.menuHeight)
        .background(Color.clear)
        .animation(LiquidGlassTheme.panelSpring, value: activeTool)
        .onAppear {
            store.refreshPermissions()
            store.setDragDropToolActive(activeTool == .dragDrop)
        }
        .onChange(of: activeTool) { _, tool in
            store.setDragDropToolActive(tool == .dragDrop)
            if tool != nil {
                isKeyboardSoundPopoverPresented = false
            }
        }
        .onDisappear {
            store.setDragDropToolActive(false)
            isKeyboardSoundPopoverPresented = false
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            CommandFlowBrandSymbol(size: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text("CommandFlow")
                    .font(.system(size: 14, weight: .semibold))

                Text(activeTool == nil ? "\(store.activeActionCount) actions ready" : "\(activeTool?.rawValue ?? "") panel")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if activeTool != nil {
                toolbarButton(systemImage: "chevron.backward", tint: store.palette.accentSecondary)
                    .onTapGesture {
                        withAnimation(LiquidGlassTheme.panelSpring) {
                            activeTool = nil
                        }
                    }
                    .help("Back to actions")
            }

            if !store.permissionSnapshot.accessibilityGranted {
                toolbarButton(systemImage: "hand.raised", tint: store.palette.accentSecondary)
                    .onTapGesture {
                        onOpenOnboarding()
                    }
                    .help("Finish permissions setup")
            }

            toolbarButton(systemImage: "gearshape", tint: store.palette.accentSecondary)
                .onTapGesture {
                    onOpenSettings()
                }
                .help("Open settings")

            toolbarButton(systemImage: "arrow.clockwise", tint: store.palette.accentSecondary)
                .onTapGesture {
                    onRelaunchApplication()
                }
                .help("Restart CommandFlow")

            toolbarButton(systemImage: "xmark", tint: .secondary)
                .onTapGesture {
                    onDismissMenu()
                }
                .help("Dismiss")
        }
        .padding(.horizontal, 2)
    }

    private var toolStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: toolStripColumns, spacing: 8) {
                ForEach(MenuToolPanel.allCases) { tool in
                    ToolStripButton(store: store, tool: tool, isActive: activeTool == tool) {
                        withAnimation(LiquidGlassTheme.panelSpring) {
                            isKeyboardSoundPopoverPresented = false
                            activeTool = activeTool == tool ? nil : tool
                        }
                    }
                }

                KeyboardSoundStripButton(
                    store: store,
                    isActive: isKeyboardSoundPopoverPresented,
                    isEnabled: store.keyboardSoundEnabled
                ) {
                    withAnimation(LiquidGlassTheme.panelSpring) {
                        isKeyboardSoundPopoverPresented.toggle()
                    }
                }
            }
            .padding(.vertical, 1)

            if isKeyboardSoundPopoverPresented {
                HStack {
                    Spacer(minLength: 0)
                    keyboardSoundPopover
                        .frame(width: 246)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var keyboardSoundPopover: some View {
        GlassSurface(cornerRadius: 18, padding: 14, glowColor: store.palette.glow) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard Sound")
                            .font(.system(size: 12.5, weight: .semibold))

                        Text(keyboardSoundStatusText)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Toggle("", isOn: keyboardSoundEnabledBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume")
                            .font(.system(size: 11.5, weight: .semibold))

                        Spacer(minLength: 8)

                        Text("\(Int(store.keyboardSoundVolume * 100))%")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    NativeGlassSlider(value: keyboardSoundVolumeBinding, palette: store.palette)
                }

                Text(keyboardSoundDetailText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var keepOpenBanner: some View {
        GlassInlineNote(
            store: store,
            symbol: store.disableAutoClose ? "pin.fill" : "arrow.down.doc",
            title: store.disableAutoClose ? "Disable auto close is on" : "Drag & drop keeps the menu open",
            detail: store.disableAutoClose ? "Click the close button when you want to dismiss CommandFlow." : "Outside clicks are ignored while the Drag & Drop tool is active."
        )
    }

    private var setupPrompt: some View {
        GlassInlineNote(store: store, symbol: "hand.raised", title: "Finish setup", detail: "Enable Accessibility to unlock system-level actions.") {
            Button("Open") {
                onOpenOnboarding()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(store.palette.accentSecondary)
        }
    }

    private func feedbackBanner(_ banner: FeedbackBanner) -> some View {
        GlassInlineNote(
            store: store,
            symbol: bannerSymbol(for: banner.style),
            title: banner.title,
            detail: banner.detail
        )
    }

    private func updatePrompt(for release: AppUpdateRelease) -> some View {
        GlassInlineNote(
            store: store,
            symbol: "arrow.down.circle",
            title: "Update available",
            detail: updatePromptDetail(for: release)
        ) {
            if case .downloaded = updateService.downloadState {
                Button("Reveal") {
                    updateService.revealDownloadedFile()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.palette.accentSecondary)
            } else {
                Button(updatePromptButtonTitle) {
                    Task {
                        await updateService.downloadLatestRelease()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.palette.accentSecondary)
                .disabled(isDownloadingUpdate)
                .opacity(isDownloadingUpdate ? 0.6 : 1)
            }
        }
    }

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Quick Actions")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.quickActions) { action in
                        QuickAccessOrb(store: store, action: action, status: store.rowStatus(for: action)) {
                            withAnimation(LiquidGlassTheme.rowSpring) {
                                store.perform(action)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func listSection(title: String, actions: [SystemAction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title)
                .padding(.bottom, 5)

            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                ActionRowView(store: store, action: action)

                if index < actions.count - 1 {
                    Divider()
                        .overlay(.white.opacity(0.035))
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.bottom, store.densityMetrics.sectionSpacing)
    }

    @ViewBuilder
    private func featurePanel(for tool: MenuToolPanel) -> some View {
        switch tool {
        case .color:
            ColorPaletteView(store: store)
        case .focusNoise:
            FocusNoiseView(store: store)
        case .dragDrop:
            DragDropView(store: store, dragDropStore: dragDropStore)
        case .clipboard:
            ClipboardHistoryView(store: clipboardStore, preferences: store)
        case .savedURLs:
            SavedURLsView(store: store, savedURLStore: savedURLStore)
        case .quickNote:
            QuickNoteView(store: store, quickNoteStore: quickNoteStore)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No matching actions")
                .font(.system(size: 13, weight: .semibold))

            Text("Try a broader search or re-enable actions in Settings.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 16)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.42)
            .padding(.horizontal, 2)
    }

    private func toolbarButton(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint.opacity(0.92))
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(store.palette.accent.opacity(0.08))
                    )
            )
    }

    private func bannerSymbol(for style: FeedbackBanner.Style) -> String {
        switch style {
        case .success:
            return "checkmark"
        case .warning:
            return "exclamationmark"
        case .error:
            return "xmark"
        }
    }

    private func updatePromptDetail(for release: AppUpdateRelease) -> String {
        var message = "CommandFlow \(release.version) is ready."

        if let asset = release.preferredAsset {
            message += " Download the latest \(asset.kindLabel) to Downloads."
        }

        switch updateService.downloadState {
        case let .downloading(filename):
            message = "Downloading \(filename) to Downloads."
        case let .downloaded(fileURL):
            message = "Downloaded \(fileURL.lastPathComponent). Reveal it and replace the app."
        case let .failed(error):
            message = "Download failed. \(error)"
        case .idle:
            break
        }

        return message
    }

    private var updatePromptButtonTitle: String {
        switch updateService.downloadState {
        case .downloading:
            return "Downloading"
        case .downloaded:
            return "Reveal"
        case .failed:
            return "Retry"
        case .idle:
            return "Download"
        }
    }

    private var isDownloadingUpdate: Bool {
        if case .downloading = updateService.downloadState {
            return true
        }

        return false
    }
}

private struct MenuCategorySection: Identifiable {
    let category: MenuPresentationCategory
    let actions: [SystemAction]

    var id: String { category.rawValue }
}

private enum MenuPresentationCategory: String, Identifiable {
    case system = "System"
    case finder = "Finder"
    case apps = "Apps"
    case text = "Text"
    case navigation = "Navigation"
    case windows = "Windows"
    case screen = "Screen"
    case audio = "Audio"

    static let orderedCases: [MenuPresentationCategory] = [
        .system,
        .finder,
        .apps,
        .text,
        .navigation,
        .windows,
        .screen,
        .audio,
    ]

    var id: String { rawValue }

    init(action: SystemAction) {
        switch action.id {
        case "finder", "downloads", "new-folder", "open-file", "duplicate-file", "delete-file", "empty-trash", "empty-trash-force":
            self = .finder
        case "safari", "terminal", "applications", "activity-monitor", "system-settings", "bluetooth-settings", "display-settings", "network-settings", "app-preferences", "spotify", "apple-music", "mail", "clock-timer":
            self = .apps
        case "copy", "paste", "cut", "undo", "redo", "select-all", "find", "replace", "bold", "italic", "underline", "emoji-picker":
            self = .text
        case "new-tab", "reload", "back", "forward", "focus-url", "spotlight":
            self = .navigation
        case "close-window", "switch-window", "switch-app", "quit-app", "hide-front-app", "full-screen", "minimize", "minimize-all", "zoom-in", "zoom-out":
            self = .windows
        case "screenshot", "screenshot-full", "screenshot-selection", "screen-saver":
            self = .screen
        case "mute", "volume-down", "volume-up":
            self = .audio
        default:
            self = .system
        }
    }
}

private enum MenuToolPanel: String, CaseIterable, Identifiable {
    case color = "Color"
    case focusNoise = "Focus Noise"
    case dragDrop = "Drop"
    case clipboard = "Clipboard"
    case savedURLs = "Saved URLs"
    case quickNote = "Notes"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .color:
            return "eyedropper.halffull"
        case .focusNoise:
            return "speaker.wave.3"
        case .dragDrop:
            return "square.and.arrow.down"
        case .clipboard:
            return "list.clipboard"
        case .savedURLs:
            return "link"
        case .quickNote:
            return "note.text"
        }
    }
}

private struct VisionGlassPanel: View {
    @ObservedObject var store: CommandFlowStore

    var body: some View {
        RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous)
            .fill(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.72)
            }
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.07),
                                store.palette.accent.opacity(0.055),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                store.palette.accent.opacity(0.08),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 110)
                    .blur(radius: 12)
                    .offset(x: -18, y: -16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.05), lineWidth: 0.8)
            )
    }
}

private struct GlassInlineNote<Trailing: View>: View {
    @ObservedObject var store: CommandFlowStore
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder var trailing: () -> Trailing

    init(
        store: CommandFlowStore,
        symbol: String,
        title: String,
        detail: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.store = store
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(store.palette.accentSecondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))

                Text(detail)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(store.palette.accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.7)
                )
        )
    }
}

private struct QuickAccessOrb: View {
    @ObservedObject var store: CommandFlowStore
    let action: SystemAction
    let status: ActionRowStatus
    let perform: () -> Void

    @State private var isHovered = false

    private var actionIsDisabled: Bool {
        !store.canPerform(action)
    }

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 5) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(store.palette.accent.opacity(isHovered ? 0.18 : 0.08))
                    }
                    .overlay {
                        Image(systemName: statusSymbol)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.92))
                    }
                .frame(width: 32, height: 32)

                Text(action.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
            .padding(.horizontal, 2)
            .scaleEffect(isHovered ? 1.025 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(actionIsDisabled)
        .opacity(actionIsDisabled ? 0.46 : 1.0)
        .onHover { hovering in
            withAnimation(LiquidGlassTheme.rowSpring) {
                isHovered = hovering
            }
        }
        .help(store.displayName(for: action))
    }

    private var statusSymbol: String {
        switch status {
        case .idle:
            return action.systemImage
        case .running:
            return "hourglass"
        case .success:
            return "checkmark"
        case .failure:
            return "exclamationmark"
        case .confirm:
            return "questionmark"
        }
    }
}

private struct ToolStripButton: View {
    @ObservedObject var store: CommandFlowStore
    let tool: MenuToolPanel
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 11, weight: .semibold))

                Text(tool.rawValue)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, store.densityMetrics.toolButtonVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(buttonBackground)
            .scaleEffect(isHovered || isActive ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                    .fill(isActive ? store.palette.accent.opacity(0.14) : .white.opacity(isHovered ? 0.04 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                    .strokeBorder(.white.opacity(isActive ? 0.08 : 0.04), lineWidth: 0.7)
            )
    }
}

private struct KeyboardSoundStripButton: View {
    @ObservedObject var store: CommandFlowStore
    let isActive: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .semibold))

                Text("Keyboard")
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, store.densityMetrics.toolButtonVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(buttonBackground)
            .scaleEffect(isHovered || isActive ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
        .help("Keyboard sound")
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                    .fill((isActive || isEnabled) ? store.palette.accent.opacity(0.14) : .white.opacity(isHovered ? 0.04 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                    .strokeBorder(.white.opacity((isActive || isEnabled) ? 0.08 : 0.04), lineWidth: 0.7)
            )
    }
}
