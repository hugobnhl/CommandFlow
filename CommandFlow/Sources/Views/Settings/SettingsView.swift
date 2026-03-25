import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: CommandFlowStore
    @ObservedObject var clipboardStore: ClipboardHistoryStore
    @ObservedObject var savedURLStore: SavedURLStore
    @ObservedObject var quickNoteStore: QuickNoteStore
    let showOnboarding: () -> Void

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    generalSection
                    appearanceSection
                    behaviorSection
                    clipboardSection
                    savedURLsSection
                    quickNoteSection
                    advancedSection
                }
                .padding(22)
            }
        }
        .frame(width: 620, height: 760)
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
                    detail: "Finder and System Events prompts are handled by macOS on first use.",
                    buttonTitle: "Open Privacy",
                    action: store.openAutomationSettings
                )

                GlassSurface(cornerRadius: 18, padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permission help")
                            .font(.system(size: 12.5, weight: .semibold))

                        Text("If macOS does not jump directly to the exact pane, open System Settings, then go to Privacy & Security > Accessibility.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Automation entries only appear after you trigger an action that asks for Finder or System Events access at least once.")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

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

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        GlassSurface(cornerRadius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(title)
                content()
            }
        }
    }

    private func settingRow<Accessory: View>(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)
            accessory()
        }
    }

    private func permissionRow(title: String, detail: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

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
