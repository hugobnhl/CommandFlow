import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var clipboardStore: ClipboardHistoryStore
    @ObservedObject var savedURLStore: SavedURLStore
    @ObservedObject var quickNoteStore: QuickNoteStore
    @ObservedObject var updateService: AppUpdateService
    let showOnboarding: () -> Void

    private let releaseInfo = AppReleaseInfo.current

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

    private var automationPermissionSummary: AutomationPermissionSummary {
        store.permissionSnapshot.automationPermission.summary
    }

    private var automationPermissionDetail: String {
        switch automationPermissionSummary {
        case .granted:
            return "Finder and System Events automation are already allowed."
        case .partiallyGranted:
            return "Automation is partially verified. At least one target already works, and the remaining target can request access the next time it is needed."
        case .requiresConsent:
            return "Automation has not been granted yet. CommandFlow can request Finder and System Events access when needed."
        case .denied:
            return "Automation was denied for at least one target. Review Privacy & Security > Automation."
        case .unknown:
            return "Automation could not be verified completely. If it already works, macOS may simply not be exposing one target right now."
        }
    }

    private var automationPrimaryButtonTitle: String {
        switch automationPermissionSummary {
        case .granted, .denied:
            return "Open Pane"
        case .partiallyGranted:
            return "Request Again"
        case .requiresConsent, .unknown:
            return "Request Access"
        }
    }

    private var inputMonitoringPrimaryButtonTitle: String {
        if store.permissionSnapshot.inputMonitoringGranted {
            return "Open Pane"
        }

        return store.inputMonitoringRequestPending ? "Open Pane" : "Request Access"
    }

    private var inputMonitoringDetail: String {
        if store.permissionSnapshot.inputMonitoringGranted {
            return "Enabled. CommandFlow can listen for global key events."
        }

        if store.inputMonitoringRequestPending {
            return "CommandFlow is waiting for macOS to confirm Input Monitoring. Keep the privacy pane open, allow the app if it appears, then click Update Permissions."
        }

        return "Not enabled yet. Request access once so CommandFlow appears in Privacy & Security > Input Monitoring."
    }

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    generalSection
                    appearanceSection
                    behaviorSection
                    keyboardSoundSection
                    clipboardSection
                    savedURLsSection
                    quickNoteSection
                    advancedSection
                    updatesSection
                    aboutSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 22)
            }
        }
        .frame(width: 680, height: 820)
        .background(FloatingWindowConfigurator())
        .background(ForegroundWindowConfigurator())
        .onAppear {
            store.refreshPermissions()
        }
    }

    private var header: some View {
        GlassSurface(cornerRadius: 24, padding: 20, glowColor: store.palette.glow) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    CommandFlowBrandSymbol(size: 36, enclosed: true)
                    Text("Settings")
                        .font(.system(size: 24, weight: .semibold))
                }

                Text("Tune the anchored menu, choose your preferred apps, and keep CommandFlow tailored to the way you work.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var generalSection: some View {
        settingsSection("General") {
            settingRow(title: "Launch at startup", detail: "Use the modern macOS login item flow.") {
                Toggle("", isOn: Binding(
                    get: { store.launchAtStartupEnabled },
                    set: { store.setLaunchAtStartup($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            settingRow(title: "Preferred browser", detail: "Used when opening saved URLs.") {
                Picker("", selection: $store.preferredBrowser) {
                    ForEach(store.availableBrowserPreferences) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180)
            }

            settingRow(title: "Preferred mail app", detail: "Used by the Open Mail action.") {
                Picker("", selection: $store.preferredMailApp) {
                    ForEach(store.availableMailPreferences) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 180)
            }
        }
    }

    private var appearanceSection: some View {
        settingsSection("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                sectionSubtitle("Accent theme")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                    ForEach(AccentThemeChoice.allCases) { choice in
                        ThemeOptionButton(choice: choice, isSelected: store.accentTheme == choice, store: store) {
                            store.accentTheme = choice
                        }
                    }
                }
            }

            Divider().overlay(.white.opacity(0.04))

            settingRow(title: "Density", detail: "Adjust row height, spacing, and list compactness.") {
                Picker("", selection: $store.density) {
                    ForEach(DensityOption.allCases) { density in
                        Text(density.title).tag(density)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            settingRow(title: "Auto copy color", detail: "When enabled, picking a color copies its HEX value immediately.") {
                Toggle("", isOn: $store.autoCopyColor)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }

    private var behaviorSection: some View {
        settingsSection("Behavior") {
            Toggle("Animated feedback", isOn: $store.animatedFeedbackEnabled)
                .toggleStyle(.switch)

            Toggle("Show disabled actions in the menu", isOn: $store.showsDisabledActions)
                .toggleStyle(.switch)

            Toggle("Confirm disruptive actions", isOn: $store.confirmsDestructiveActions)
                .toggleStyle(.switch)

            Toggle("Disable auto close", isOn: $store.disableAutoClose)
                .toggleStyle(.switch)

            Toggle("Attach to menu bar", isOn: $store.attachToMenuBar)
                .toggleStyle(.switch)
        }
    }

    private var clipboardSection: some View {
        settingsSection("Clipboard") {
            settingRow(
                title: "Keep history on disk",
                detail: clipboardStore.isPersistedOnDisk
                    ? "Clipboard entries are written to disk so they survive relaunches."
                    : "Clipboard entries stay in memory for this session only."
            ) {
                Toggle("", isOn: Binding(
                    get: { clipboardStore.isPersistedOnDisk },
                    set: { clipboardStore.setPersistenceEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            Divider().overlay(.white.opacity(0.04))

            settingRow(title: "History size", detail: "CommandFlow keeps the latest \(clipboardStore.limit) copied text items.") {
                Text("\(clipboardStore.items.count) saved")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            settingRow(title: "Clear clipboard history", detail: "Delete all stored clipboard entries immediately.") {
                Button("Clear") {
                    clipboardStore.clear()
                    store.publishSuccess(title: "Clipboard cleared", detail: "All saved clipboard items were removed.")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(GlassPillBackground())
            }
        }
    }

    private var keyboardSoundSection: some View {
        settingsSection("Keyboard Sound") {
            settingRow(
                title: "Enable keyboard sound",
                detail: store.permissionSnapshot.inputMonitoringGranted
                    ? "Global keyboard feedback stays mixed behind your audio."
                    : store.keyboardSoundEnabled
                        ? "Keyboard sound is enabled, but playback stays paused until Input Monitoring is confirmed by macOS."
                    : "Requires Input Monitoring to capture keystrokes outside CommandFlow."
            ) {
                Toggle("", isOn: keyboardSoundEnabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Divider().overlay(.white.opacity(0.04))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Volume")
                            .font(.system(size: 13.5, weight: .semibold))

                        Text("Adjust the loudness of the mechanical keyboard profile.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 10)

                    Text("\(Int(store.keyboardSoundVolume * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                NativeGlassSlider(value: keyboardSoundVolumeBinding, palette: store.palette)
            }

            Divider().overlay(.white.opacity(0.04))

            settingRow(
                title: "Input Monitoring",
                detail: inputMonitoringDetail
            ) {
                HStack(spacing: 10) {
                    Button(inputMonitoringPrimaryButtonTitle) {
                        if store.permissionSnapshot.inputMonitoringGranted {
                            store.openInputMonitoringSettings()
                        } else if store.inputMonitoringRequestPending {
                            store.openInputMonitoringSettings()
                        } else {
                            store.requestInputMonitoringPrompt()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GlassPillBackground())

                    Button("Update Permissions") {
                        store.updateKeyboardSoundPermissions()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GlassPillBackground())
                }
            }
        }
    }

    private var savedURLsSection: some View {
        settingsSection("Saved URLs") {
            settingRow(title: "List order", detail: "Choose how saved links are sorted in the panel.") {
                Picker("", selection: $savedURLStore.sortOrder) {
                    ForEach(SavedURLSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 190)
            }

            settingRow(title: "Saved links", detail: "Open, rename, or delete links from the Saved URLs panel.") {
                Text("\(savedURLStore.orderedItems.count) items")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickNoteSection: some View {
        settingsSection("QuickNote") {
            settingRow(title: "Stored notes", detail: "Notes persist until you explicitly delete them.") {
                Text("\(quickNoteStore.notes.count) notes")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var advancedSection: some View {
        settingsSection("Advanced") {
            VStack(alignment: .leading, spacing: 16) {
                sectionSubtitle("Permissions")

                permissionRow(
                    title: "Accessibility",
                    detail: store.permissionSnapshot.accessibilityGranted ? "Enabled for keyboard-driven actions." : "Required for global shortcuts and frontmost-app commands.",
                    buttonTitle: store.permissionSnapshot.accessibilityGranted ? "Open Pane" : "Enable",
                    action: {
                        if store.permissionSnapshot.accessibilityGranted {
                            store.openAccessibilitySettings()
                        } else {
                            store.requestAccessibilityPrompt()
                        }
                    }
                )

                permissionRow(
                    title: "Automation",
                    detail: automationPermissionDetail,
                    buttonTitle: automationPrimaryButtonTitle,
                    action: {
                        if automationPermissionSummary == .granted || automationPermissionSummary == .denied {
                            store.openAutomationSettings()
                        } else {
                            store.requestAutomationPrompt()
                        }
                    }
                )

                permissionRow(
                    title: "Input Monitoring",
                    detail: inputMonitoringDetail,
                    buttonTitle: inputMonitoringPrimaryButtonTitle,
                    action: {
                        if store.permissionSnapshot.inputMonitoringGranted {
                            store.openInputMonitoringSettings()
                        } else if store.inputMonitoringRequestPending {
                            store.openInputMonitoringSettings()
                        } else {
                            store.requestInputMonitoringPrompt()
                        }
                    }
                )

                GlassSurface(cornerRadius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permission help")
                            .font(.system(size: 12.5, weight: .semibold))

                        Text("macOS permissions can be capricious. If a prompt disappears, a pane does not refresh, or System Settings acts stuck, open the right privacy pane by hand, keep it open, relaunch the app if needed, then press Refresh Status.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("If macOS does not jump directly to the exact pane, open System Settings, then go to Privacy & Security > Accessibility.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Automation entries only appear after you trigger an action that asks for Finder or System Events access at least once.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("If Automation already works, CommandFlow now reflects that instead of treating it like a simple onboarding checkbox.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Input Monitoring requests can fail silently on macOS. If CommandFlow still does not appear, keep the privacy pane open, relaunch the app, then try Request Access again and Update Permissions.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Open Automation in System Settings") {
                    store.openAutomationSettings()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(GlassPillBackground())

                HStack(spacing: 10) {
                    Button("Show Setup Again") {
                        store.resetOnboarding()
                        showOnboarding()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GlassPillBackground())

                    Button("Refresh Status") {
                        store.refreshPermissions()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GlassPillBackground())
                }
            }

            Divider().overlay(.white.opacity(0.04))

            VStack(alignment: .leading, spacing: 14) {
                sectionSubtitle("Actions")

                ForEach(store.allActions) { action in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.name)
                                .font(.system(size: 13.5, weight: .semibold))

                            Text(action.detail)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        if let requirement = action.permissionRequirement {
                            Text(requirement.rawValue.capitalized)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        Toggle(
                            "",
                            isOn: Binding(
                                get: { !store.isDisabled(action) },
                                set: { store.setActionEnabled($0, for: action) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var aboutSection: some View {
        settingsSection("About") {
            settingRow(
                title: "Release",
                detail: "\(releaseInfo.name) \(releaseInfo.version) (build \(releaseInfo.build))"
            ) {
                Text(releaseInfo.bundleIdentifier)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider().overlay(.white.opacity(0.04))

            settingRow(
                title: "Website",
                detail: "Primary product site and future download hub."
            ) {
                actionPill("Open") {
                    openExternalURL("https://getcommandflow.app")
                }
            }

            settingRow(
                title: "Support",
                detail: "Customer support and outreach inbox."
            ) {
                actionPill("Email") {
                    openExternalURL("mailto:support@getcommandflow.app")
                }
            }

            settingRow(
                title: "Privacy",
                detail: "Public privacy page for the release site."
            ) {
                actionPill("Open") {
                    openExternalURL("https://getcommandflow.app/privacy")
                }
            }

            settingRow(
                title: "Terms",
                detail: "Public terms page for the release site."
            ) {
                actionPill("Open") {
                    openExternalURL("https://getcommandflow.app/terms")
                }
            }
        }
    }

    private var updatesSection: some View {
        settingsSection("Updates") {
            settingRow(
                title: "Current version",
                detail: "You are running \(releaseInfo.version) (build \(releaseInfo.build))."
            ) {
                if updateService.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(updateService.latestVersionLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().overlay(.white.opacity(0.04))

            settingRow(
                title: updatesHeadline,
                detail: updatesDetail
            ) {
                HStack(spacing: 8) {
                    actionPill(updateService.isChecking ? "Checking" : "Check Now") {
                        Task {
                            await updateService.checkForUpdates(source: .manual)
                        }
                    }
                    .disabled(updateService.isChecking)
                    .opacity(updateService.isChecking ? 0.6 : 1)

                    if updateService.availableRelease != nil {
                        actionPill(downloadButtonTitle) {
                            Task {
                                await updateService.downloadLatestRelease()
                            }
                        }
                        .disabled(isDownloadingLatestRelease)
                        .opacity(isDownloadingLatestRelease ? 0.6 : 1)
                    }

                    if latestReleasePageURL != nil {
                        actionPill("Notes") {
                            openLatestReleasePage()
                        }
                    }
                }
            }

            if case let .downloaded(fileURL) = updateService.downloadState {
                Divider().overlay(.white.opacity(0.04))

                settingRow(
                    title: "Downloaded",
                    detail: "Saved to \(fileURL.lastPathComponent) in Downloads."
                ) {
                    actionPill("Reveal") {
                        updateService.revealDownloadedFile()
                    }
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        GlassSurface(cornerRadius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(title)
                content()
            }
        }
    }

    private func settingRow<Accessory: View>(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 10)
            accessory()
        }
    }

    private func permissionRow(title: String, detail: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 10)

            Button(buttonTitle) {
                action()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GlassPillBackground())
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func sectionSubtitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private func actionPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(GlassPillBackground())
    }

    private func openExternalURL(_ rawValue: String) {
        guard let url = URL(string: rawValue) else {
            return
        }

        openURL(url)
    }

    private var updatesHeadline: String {
        if let release = updateService.availableRelease {
            return "Version \(release.version) is available"
        }

        if updateService.latestRelease != nil {
            return "You are up to date"
        }

        if updateService.isChecking {
            return "Checking for updates"
        }

        if updateService.checkErrorMessage != nil {
            return "Couldn’t check for updates"
        }

        return "Updates are not checked yet"
    }

    private var updatesDetail: String {
        if let release = updateService.availableRelease {
            var parts: [String] = []

            if let asset = release.preferredAsset {
                parts.append("Latest \(asset.kindLabel) will download inside CommandFlow.")
                parts.append("Current asset downloads: \(asset.downloadCount).")
            } else {
                parts.append("A release exists, but no DMG or ZIP asset is published yet.")
            }

            if case let .failed(message) = updateService.downloadState {
                parts.append("Download failed: \(message)")
            } else if case let .downloading(filename) = updateService.downloadState {
                parts.append("Downloading \(filename) to Downloads.")
            }

            return parts.joined(separator: " ")
        }

        if let latestRelease = updateService.latestRelease {
            if let lastCheckDate = updateService.lastCheckDate {
                return "GitHub Releases says \(latestRelease.version) is the latest version. Last checked \(updatesDateFormatter.string(from: lastCheckDate))."
            }

            return "GitHub Releases says \(latestRelease.version) is the latest version."
        }

        if updateService.isChecking {
            return "CommandFlow is checking GitHub Releases right now."
        }

        if let error = updateService.checkErrorMessage {
            return "\(error) Use Check Now to try again."
        }

        return "CommandFlow can check GitHub Releases and download the latest DMG or ZIP without opening a browser."
    }

    private var latestReleasePageURL: URL? {
        updateService.latestRelease?.releasePageURL
    }

    private var isDownloadingLatestRelease: Bool {
        if case .downloading = updateService.downloadState {
            return true
        }

        return false
    }

    private var downloadButtonTitle: String {
        switch updateService.downloadState {
        case .downloading:
            return "Downloading"
        case .downloaded:
            return "Redownload"
        case .failed:
            return "Retry"
        case .idle:
            return "Download"
        }
    }

    private func openLatestReleasePage() {
        guard let latestReleasePageURL else {
            return
        }

        openURL(latestReleasePageURL)
    }

    private var updatesDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

private struct ThemeOptionButton: View {
    let choice: AccentThemeChoice
    let isSelected: Bool
    @ObservedObject var store: CommandFlowStore
    let action: () -> Void

    private var palette: AccentPalette {
        LiquidGlassTheme.palette(for: choice)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(palette.accentSecondary)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(.white.opacity(0.72))
                        .frame(width: 12, height: 12)
                }

                Text(choice.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? palette.accent.opacity(0.14) : .white.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? palette.accent.opacity(0.35) : .white.opacity(0.05), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
