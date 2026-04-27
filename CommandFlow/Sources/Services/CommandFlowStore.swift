import AppKit
import Combine
import OSLog
import SwiftUI

struct PermissionSnapshot: Equatable {
    let accessibilityGranted: Bool
    let automationPermission: AutomationPermissionSnapshot
    let automationGuidanceAcknowledged: Bool
    let inputMonitoringGranted: Bool

    var onboardingReady: Bool {
        accessibilityGranted && (automationPermission.hasAnyGrantedTarget || automationGuidanceAcknowledged)
    }
}

struct ActionGroup: Identifiable {
    let category: ActionCategory
    let actions: [SystemAction]

    var id: String { category.id }
}

enum ActionRowStatus: Equatable {
    case idle
    case running
    case success
    case failure
    case confirm
}

struct FeedbackBanner: Identifiable, Equatable {
    enum Style: Equatable {
        case success
        case warning
        case error
    }

    let id = UUID()
    let style: Style
    let title: String
    let detail: String
}

@MainActor
final class CommandFlowStore: ObservableObject {
    private enum DefaultsKey {
        static let favoriteIDs = "CommandFlow.favoriteIDs"
        static let disabledIDs = "CommandFlow.disabledIDs"
        static let showsDisabledActions = "CommandFlow.showsDisabledActions"
        static let confirmsDestructiveActions = "CommandFlow.confirmsDestructiveActions"
        static let animatedFeedbackEnabled = "CommandFlow.animatedFeedbackEnabled"
        static let didCompleteOnboarding = "CommandFlow.didCompleteOnboarding"
        static let automationGuidanceAcknowledged = "CommandFlow.automationGuidanceAcknowledged"
        static let disableAutoClose = "CommandFlow.disableAutoClose"
        static let attachToMenuBar = "CommandFlow.attachToMenuBar"
        static let accentTheme = "CommandFlow.accentTheme"
        static let density = "CommandFlow.density"
        static let preferredBrowser = "CommandFlow.preferredBrowser"
        static let preferredMailApp = "CommandFlow.preferredMailApp"
        static let launchAtStartupEnabled = "CommandFlow.launchAtStartupEnabled"
        static let autoCopyColor = "CommandFlow.autoCopyColor"
        static let keyboardSoundEnabled = "CommandFlow.keyboardSoundEnabled"
        static let keyboardSoundVolume = "CommandFlow.keyboardSoundVolume"
        static let focusNoiseMasterVolume = "CommandFlow.focusNoiseMasterVolume"
        static let focusNoiseTrackVolumes = "CommandFlow.focusNoiseTrackVolumes"
        static let activeFocusNoiseIDs = "CommandFlow.activeFocusNoiseIDs"
        static let pauseFocusNoiseWithOtherAudio = "CommandFlow.pauseFocusNoiseWithOtherAudio"
        static let lastUsedActionID = "CommandFlow.lastUsedActionID"
        static let hasPresentedOnboardingOnce = "CommandFlow.hasPresentedOnboardingOnce"
    }

    @Published var searchText = ""
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var disabledIDs: Set<String>
    @Published var showsDisabledActions: Bool {
        didSet { defaults.set(showsDisabledActions, forKey: DefaultsKey.showsDisabledActions) }
    }
    @Published var confirmsDestructiveActions: Bool {
        didSet { defaults.set(confirmsDestructiveActions, forKey: DefaultsKey.confirmsDestructiveActions) }
    }
    @Published var animatedFeedbackEnabled: Bool {
        didSet { defaults.set(animatedFeedbackEnabled, forKey: DefaultsKey.animatedFeedbackEnabled) }
    }
    @Published var disableAutoClose: Bool {
        didSet { defaults.set(disableAutoClose, forKey: DefaultsKey.disableAutoClose) }
    }
    @Published var attachToMenuBar: Bool {
        didSet { defaults.set(attachToMenuBar, forKey: DefaultsKey.attachToMenuBar) }
    }
    @Published var autoCopyColor: Bool {
        didSet { defaults.set(autoCopyColor, forKey: DefaultsKey.autoCopyColor) }
    }
    @Published var accentTheme: AccentThemeChoice {
        didSet { defaults.set(accentTheme.rawValue, forKey: DefaultsKey.accentTheme) }
    }
    @Published var density: DensityOption {
        didSet { defaults.set(density.rawValue, forKey: DefaultsKey.density) }
    }
    @Published var preferredBrowser: BrowserPreference {
        didSet { defaults.set(preferredBrowser.rawValue, forKey: DefaultsKey.preferredBrowser) }
    }
    @Published var preferredMailApp: MailPreference {
        didSet { defaults.set(preferredMailApp.rawValue, forKey: DefaultsKey.preferredMailApp) }
    }
    @Published var launchAtStartupEnabled: Bool {
        didSet {
            guard launchAtStartupEnabled != oldValue, !suppressLaunchAtStartupSync else {
                return
            }

            defaults.set(launchAtStartupEnabled, forKey: DefaultsKey.launchAtStartupEnabled)
            syncLaunchAtStartup()
        }
    }
    @Published private(set) var keyboardSoundEnabled: Bool {
        didSet { defaults.set(keyboardSoundEnabled, forKey: DefaultsKey.keyboardSoundEnabled) }
    }
    @Published private(set) var keyboardSoundVolume: Double {
        didSet { defaults.set(keyboardSoundVolume, forKey: DefaultsKey.keyboardSoundVolume) }
    }
    @Published private(set) var focusNoiseMasterVolume: Double {
        didSet { defaults.set(focusNoiseMasterVolume, forKey: DefaultsKey.focusNoiseMasterVolume) }
    }
    @Published private(set) var focusNoiseTrackVolumes: [String: Double] {
        didSet { defaults.set(focusNoiseTrackVolumes, forKey: DefaultsKey.focusNoiseTrackVolumes) }
    }
    @Published private(set) var activeFocusNoiseIDs: Set<String> {
        didSet { defaults.set(Array(activeFocusNoiseIDs).sorted(), forKey: DefaultsKey.activeFocusNoiseIDs) }
    }
    @Published var pauseFocusNoiseWithOtherAudio: Bool {
        didSet { defaults.set(pauseFocusNoiseWithOtherAudio, forKey: DefaultsKey.pauseFocusNoiseWithOtherAudio) }
    }
    @Published private(set) var availableBrowserPreferences: [BrowserPreference]
    @Published private(set) var availableMailPreferences: [MailPreference]
    @Published private(set) var permissionSnapshot: PermissionSnapshot
    @Published private(set) var actionTargetContext: FrontmostApplicationContext?
    @Published private(set) var inputMonitoringRequestPending = false
    @Published private(set) var feedbackBanner: FeedbackBanner?
    @Published private(set) var activeActionID: String?
    @Published private(set) var lastSucceededActionID: String?
    @Published private(set) var lastFailedActionID: String?
    @Published private(set) var pendingConfirmationActionID: String?
    @Published private(set) var didCompleteOnboarding: Bool
    @Published private(set) var menuBarPulseToken = 0
    @Published private(set) var lastUsedActionID: String?
    @Published private(set) var isDragInteractionActive = false
    @Published private(set) var isDragDropToolActive = false
    @Published private(set) var hasPresentedOnboardingOnce: Bool
    @Published var automationGuidanceAcknowledged: Bool {
        didSet {
            defaults.set(automationGuidanceAcknowledged, forKey: DefaultsKey.automationGuidanceAcknowledged)
            refreshPermissions()
        }
    }

    let allActions = ActionCatalog.all
    let focusNoiseTracks: [FocusNoiseTrackDescriptor]

    private let defaults = UserDefaults.standard
    private let permissionCenter = PermissionCenter()
    private let applicationRouter = ApplicationRouter()
    private let startupManager = LaunchAtStartupManager()
    private let performer: SystemActionPerformer
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "store"
    )

    private var cancellables = Set<AnyCancellable>()
    private var bannerResetTask: Task<Void, Never>?
    private var rowStateResetTask: Task<Void, Never>?
    private var confirmationResetTask: Task<Void, Never>?
    private var permissionPollingTask: Task<Void, Never>?
    private var suppressLaunchAtStartupSync = false
    private var pendingKeyboardSoundEnable = false

    init() {
        let persistedAutomationAcknowledged = defaults.object(forKey: DefaultsKey.automationGuidanceAcknowledged) as? Bool ?? false

        favoriteIDs = Set(defaults.stringArray(forKey: DefaultsKey.favoriteIDs) ?? [])
        disabledIDs = Set(defaults.stringArray(forKey: DefaultsKey.disabledIDs) ?? [])
        automationGuidanceAcknowledged = persistedAutomationAcknowledged
        didCompleteOnboarding = defaults.object(forKey: DefaultsKey.didCompleteOnboarding) as? Bool ?? false
        showsDisabledActions = defaults.object(forKey: DefaultsKey.showsDisabledActions) as? Bool ?? false
        confirmsDestructiveActions = defaults.object(forKey: DefaultsKey.confirmsDestructiveActions) as? Bool ?? true
        animatedFeedbackEnabled = defaults.object(forKey: DefaultsKey.animatedFeedbackEnabled) as? Bool ?? true
        disableAutoClose = defaults.object(forKey: DefaultsKey.disableAutoClose) as? Bool ?? false
        attachToMenuBar = defaults.object(forKey: DefaultsKey.attachToMenuBar) as? Bool ?? true
        autoCopyColor = defaults.object(forKey: DefaultsKey.autoCopyColor) as? Bool ?? false
        accentTheme = AccentThemeChoice(rawValue: defaults.string(forKey: DefaultsKey.accentTheme) ?? "") ?? .guardianNavy
        density = DensityOption(rawValue: defaults.string(forKey: DefaultsKey.density) ?? "") ?? .normal
        preferredBrowser = BrowserPreference(rawValue: defaults.string(forKey: DefaultsKey.preferredBrowser) ?? "") ?? .systemDefault
        preferredMailApp = MailPreference(rawValue: defaults.string(forKey: DefaultsKey.preferredMailApp) ?? "") ?? .systemDefault
        launchAtStartupEnabled = defaults.object(forKey: DefaultsKey.launchAtStartupEnabled) as? Bool ?? startupManager.isEnabled()
        keyboardSoundEnabled = defaults.object(forKey: DefaultsKey.keyboardSoundEnabled) as? Bool ?? false
        keyboardSoundVolume = Self.clampedKeyboardSoundVolume(defaults.object(forKey: DefaultsKey.keyboardSoundVolume) as? Double ?? 0.34)
        let bundledFocusNoiseTracks = FocusNoiseCatalog.bundledTracks()
        focusNoiseTracks = bundledFocusNoiseTracks
        let bundledFocusNoiseTrackIDs = Set(bundledFocusNoiseTracks.map(\.id))
        let persistedFocusNoiseTrackVolumes = Self.persistedDoubleDictionary(
            from: defaults.dictionary(forKey: DefaultsKey.focusNoiseTrackVolumes)
        )
        focusNoiseTrackVolumes = bundledFocusNoiseTracks.reduce(into: [:]) { volumes, track in
            volumes[track.id] = Self.clampedFocusNoiseVolume(persistedFocusNoiseTrackVolumes[track.id] ?? 0.62)
        }
        activeFocusNoiseIDs = Set(defaults.stringArray(forKey: DefaultsKey.activeFocusNoiseIDs) ?? [])
            .intersection(bundledFocusNoiseTrackIDs)
        focusNoiseMasterVolume = Self.clampedFocusNoiseVolume(
            defaults.object(forKey: DefaultsKey.focusNoiseMasterVolume) as? Double ?? 0.52
        )
        pauseFocusNoiseWithOtherAudio = defaults.object(forKey: DefaultsKey.pauseFocusNoiseWithOtherAudio) as? Bool ?? false
        let legacyOnboardingStateExists = defaults.object(forKey: DefaultsKey.didCompleteOnboarding) != nil
            || defaults.object(forKey: DefaultsKey.automationGuidanceAcknowledged) != nil
        hasPresentedOnboardingOnce = defaults.object(forKey: DefaultsKey.hasPresentedOnboardingOnce) as? Bool
            ?? legacyOnboardingStateExists
        availableBrowserPreferences = applicationRouter.availableBrowserPreferences()
        availableMailPreferences = applicationRouter.availableMailPreferences()
        lastUsedActionID = defaults.string(forKey: DefaultsKey.lastUsedActionID)
        actionTargetContext = nil
        permissionSnapshot = PermissionSnapshot(
            accessibilityGranted: permissionCenter.accessibilityGranted(),
            automationPermission: permissionCenter.automationPermissionSnapshot(),
            automationGuidanceAcknowledged: persistedAutomationAcknowledged,
            inputMonitoringGranted: permissionCenter.inputMonitoringGranted()
        )
        performer = SystemActionPerformer(
            permissionCenter: permissionCenter,
            applicationRouter: applicationRouter
        )
        inputMonitoringRequestPending = keyboardSoundEnabled && !permissionSnapshot.inputMonitoringGranted

        reconcilePreferredApps()
        configureObservers()
        refreshPermissions()
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<18:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    var activeActionCount: Int {
        allActions.filter { !disabledIDs.contains($0.id) }.count
    }

    var shouldShowSetupPrompt: Bool {
        !hasPresentedOnboardingOnce && !permissionSnapshot.accessibilityGranted
    }

    var quickActions: [SystemAction] {
        let source = favoriteActions.isEmpty ? allActions.filter { ActionCatalog.defaultQuickActionIDs.contains($0.id) } : favoriteActions
        return source
            .filter { !disabledIDs.contains($0.id) }
            .prefix(4)
            .map { $0 }
    }

    var groupedActions: [ActionGroup] {
        ActionCategory.allCases.compactMap { category in
            let actions = visibleActions.filter { $0.category == category }
            guard !actions.isEmpty else {
                return nil
            }
            return ActionGroup(category: category, actions: actions)
        }
    }

    var lastUsedAction: SystemAction? {
        guard let lastUsedActionID else {
            return nil
        }
        return allActions.first(where: { $0.id == lastUsedActionID })
    }

    var palette: AccentPalette {
        LiquidGlassTheme.palette(for: accentTheme)
    }

    var densityMetrics: DensityMetrics {
        density.metrics
    }

    var activeFocusNoiseCount: Int {
        activeFocusNoiseIDs.count
    }

    var shouldKeepMenuPresented: Bool {
        disableAutoClose || isDragInteractionActive || isDragDropToolActive
    }

    func isFavorite(_ action: SystemAction) -> Bool {
        favoriteIDs.contains(action.id)
    }

    func isDisabled(_ action: SystemAction) -> Bool {
        disabledIDs.contains(action.id)
    }

    func isUnavailable(_ action: SystemAction) -> Bool {
        unavailableReason(for: action) != nil
    }

    func canPerform(_ action: SystemAction) -> Bool {
        !isDisabled(action) && !isUnavailable(action)
    }

    func displayName(for action: SystemAction) -> String {
        guard action.usesFrontmostApplicationName, let actionTargetContext else {
            return action.name
        }
        return "\(action.name) (\(actionTargetContext.name))"
    }

    func secondaryLabel(for action: SystemAction) -> String? {
        if let reason = unavailableReason(for: action) {
            return reason
        }

        if let shortcut = action.shortcut?.trimmingCharacters(in: .whitespacesAndNewlines), !shortcut.isEmpty {
            return shortcut
        }

        if action.usesFrontmostApplicationName, let actionTargetContext {
            return "Targets \(actionTargetContext.name)"
        }

        return nil
    }

    func captureActionContextBeforePresentation() {
        var excludedBundleIdentifiers: Set<String> = []
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            excludedBundleIdentifiers.insert(bundleIdentifier)
        }
        actionTargetContext = applicationRouter.frontmostApplicationContext(excluding: excludedBundleIdentifiers)
    }

    func rowStatus(for action: SystemAction) -> ActionRowStatus {
        if activeActionID == action.id {
            return .running
        }
        if pendingConfirmationActionID == action.id {
            return .confirm
        }
        if lastSucceededActionID == action.id {
            return .success
        }
        if lastFailedActionID == action.id {
            return .failure
        }
        return .idle
    }

    func toggleFavorite(for action: SystemAction) {
        withAnimation(LiquidGlassTheme.panelSpring) {
            if favoriteIDs.contains(action.id) {
                favoriteIDs.remove(action.id)
            } else {
                favoriteIDs.insert(action.id)
            }
        }
        persistFavoriteIDs()
    }

    func setActionEnabled(_ enabled: Bool, for action: SystemAction) {
        withAnimation(LiquidGlassTheme.panelSpring) {
            if enabled {
                disabledIDs.remove(action.id)
            } else {
                disabledIDs.insert(action.id)
            }
        }
        persistDisabledIDs()
    }

    func setDragInteractionActive(_ active: Bool) {
        guard isDragInteractionActive != active else {
            return
        }
        isDragInteractionActive = active
    }

    func setDragDropToolActive(_ active: Bool) {
        guard isDragDropToolActive != active else {
            return
        }
        isDragDropToolActive = active
    }

    func refreshPermissions(reason: String = "manual") {
        let previousSnapshot = permissionSnapshot
        let wasKeyboardSoundEnabled = keyboardSoundEnabled

        let nextSnapshot = PermissionSnapshot(
            accessibilityGranted: permissionCenter.accessibilityGranted(),
            automationPermission: permissionCenter.automationPermissionSnapshot(),
            automationGuidanceAcknowledged: automationGuidanceAcknowledged,
            inputMonitoringGranted: permissionCenter.inputMonitoringGranted()
        )
        permissionSnapshot = nextSnapshot

        inputMonitoringRequestPending = keyboardSoundEnabled && !nextSnapshot.inputMonitoringGranted

        if nextSnapshot != previousSnapshot {
            logger.info(
                """
                Permission snapshot changed (\(reason, privacy: .public)): \
                accessibility=\(nextSnapshot.accessibilityGranted), \
                automation=\(nextSnapshot.automationPermission.summary.rawValue, privacy: .public), \
                inputMonitoring=\(nextSnapshot.inputMonitoringGranted)
                """
            )
        } else {
            logger.debug(
                """
                Permission snapshot unchanged (\(reason, privacy: .public)): \
                accessibility=\(nextSnapshot.accessibilityGranted), \
                automation=\(nextSnapshot.automationPermission.summary.rawValue, privacy: .public), \
                inputMonitoring=\(nextSnapshot.inputMonitoringGranted)
                """
            )
        }

        refreshAvailableApplications()
        syncKeyboardSoundPermissionState(previousSnapshot: previousSnapshot, wasEnabled: wasKeyboardSoundEnabled)
    }

    func requestAccessibilityPrompt() {
        permissionCenter.requestAccessibilityPrompt()
        startPermissionPolling()
    }

    func openAccessibilitySettings() {
        permissionCenter.openAccessibilitySettings()
        startPermissionPolling()
    }

    func openAutomationSettings() {
        permissionCenter.openAutomationSettings()
        startPermissionPolling()
    }

    func requestAutomationPrompt() {
        logger.info("Automation request initiated from CommandFlow")
        permissionCenter.requestAutomationPrompt()
        markAutomationGuidanceAcknowledged()
        refreshPermissions(reason: "automation_request")
        startPermissionPolling()
    }

    func requestInputMonitoringPrompt() {
        let result = permissionCenter.requestInputMonitoringPrompt()
        logger.info(
            """
            Input monitoring request result: \
            cgBefore=\(result.cgGrantedBeforeRequest), \
            hidBefore=\(result.hidAccessBeforeRequest.rawValue, privacy: .public), \
            cgResult=\(result.cgApiReportedGranted), \
            hidResult=\(result.hidApiReportedGranted), \
            tapProbe=\(result.eventTapProbeSucceeded), \
            after=\(result.isGrantedAfterRequest)
            """
        )

        inputMonitoringRequestPending = keyboardSoundEnabled && !result.isGrantedAfterRequest
        refreshPermissions(reason: "input_monitoring_request")

        if result.isGrantedAfterRequest {
            if !pendingKeyboardSoundEnable {
                publishBanner(
                    style: .success,
                    title: "Input Monitoring enabled",
                    detail: "CommandFlow can now listen for global keyboard events."
                )
            }
        } else {
            permissionCenter.openInputMonitoringSettings()
            publishBanner(
                style: .warning,
                title: "Review Input Monitoring",
                detail: "macOS has not confirmed access yet. Review Privacy & Security > Input Monitoring, then refresh."
            )
        }

        startPermissionPolling()
    }

    func openInputMonitoringSettings() {
        permissionCenter.openInputMonitoringSettings()
        startPermissionPolling()
    }

    func markAutomationGuidanceAcknowledged() {
        guard !automationGuidanceAcknowledged else {
            return
        }
        automationGuidanceAcknowledged = true
    }

    func completeOnboarding() {
        guard permissionSnapshot.onboardingReady else {
            return
        }

        didCompleteOnboarding = true
        defaults.set(true, forKey: DefaultsKey.didCompleteOnboarding)
    }

    func markOnboardingPresented() {
        guard !hasPresentedOnboardingOnce else {
            return
        }

        hasPresentedOnboardingOnce = true
        defaults.set(true, forKey: DefaultsKey.hasPresentedOnboardingOnce)
    }

    func resetOnboarding() {
        didCompleteOnboarding = false
        automationGuidanceAcknowledged = false
        defaults.set(false, forKey: DefaultsKey.didCompleteOnboarding)
        refreshPermissions()
    }

    func setLaunchAtStartup(_ enabled: Bool) {
        launchAtStartupEnabled = enabled
    }

    func setKeyboardSoundEnabled(_ enabled: Bool) {
        let wasEnabled = keyboardSoundEnabled

        if enabled {
            if !wasEnabled {
                keyboardSoundEnabled = true
            }

            guard permissionSnapshot.inputMonitoringGranted else {
                pendingKeyboardSoundEnable = true
                inputMonitoringRequestPending = true
                requestInputMonitoringPrompt()
                return
            }

            pendingKeyboardSoundEnable = false
            inputMonitoringRequestPending = false

            if !wasEnabled {
                publishBanner(
                    style: .success,
                    title: "Keyboard sound enabled",
                    detail: "Mechanical feedback is ready."
                )
            }
            return
        }

        pendingKeyboardSoundEnable = false
        inputMonitoringRequestPending = false
        guard keyboardSoundEnabled else {
            return
        }

        keyboardSoundEnabled = false
        publishBanner(
            style: .success,
            title: "Keyboard sound disabled",
            detail: "Mechanical feedback is off."
        )
    }

    func setKeyboardSoundVolume(_ value: Double) {
        let clampedValue = Self.clampedKeyboardSoundVolume(value)
        guard abs(clampedValue - keyboardSoundVolume) > 0.0001 else {
            return
        }
        keyboardSoundVolume = clampedValue
    }

    func isFocusNoiseEnabled(_ trackID: String) -> Bool {
        activeFocusNoiseIDs.contains(trackID)
    }

    func focusNoiseVolume(for trackID: String) -> Double {
        focusNoiseTrackVolumes[trackID] ?? 0.62
    }

    func setFocusNoiseEnabled(_ enabled: Bool, for trackID: String) {
        guard focusNoiseTracks.contains(where: { $0.id == trackID }) else {
            return
        }

        var nextActiveTrackIDs = activeFocusNoiseIDs
        if enabled {
            nextActiveTrackIDs.insert(trackID)
        } else {
            nextActiveTrackIDs.remove(trackID)
        }

        guard nextActiveTrackIDs != activeFocusNoiseIDs else {
            return
        }

        activeFocusNoiseIDs = nextActiveTrackIDs
    }

    func toggleFocusNoise(for trackID: String) {
        setFocusNoiseEnabled(!isFocusNoiseEnabled(trackID), for: trackID)
    }

    func setFocusNoiseTrackVolume(_ value: Double, for trackID: String) {
        guard focusNoiseTrackVolumes[trackID] != nil else {
            return
        }

        let clampedValue = Self.clampedFocusNoiseVolume(value)
        guard abs((focusNoiseTrackVolumes[trackID] ?? clampedValue) - clampedValue) > 0.0001 else {
            return
        }

        var nextVolumes = focusNoiseTrackVolumes
        nextVolumes[trackID] = clampedValue
        focusNoiseTrackVolumes = nextVolumes
    }

    func setFocusNoiseMasterVolume(_ value: Double) {
        let clampedValue = Self.clampedFocusNoiseVolume(value)
        guard abs(clampedValue - focusNoiseMasterVolume) > 0.0001 else {
            return
        }

        focusNoiseMasterVolume = clampedValue
    }

    func setPauseFocusNoiseWithOtherAudio(_ enabled: Bool) {
        guard pauseFocusNoiseWithOtherAudio != enabled else {
            return
        }

        pauseFocusNoiseWithOtherAudio = enabled
    }

    func stopAllFocusNoise() {
        guard !activeFocusNoiseIDs.isEmpty else {
            return
        }

        activeFocusNoiseIDs = []
        publishBanner(
            style: .success,
            title: "Focus noise stopped",
            detail: "All ambient layers are off."
        )
    }

    func updateKeyboardSoundPermissions() {
        refreshPermissions(reason: "keyboard_sound_update")
    }

    func perform(_ action: SystemAction) {
        guard !isDisabled(action) else {
            return
        }

        if let reason = unavailableReason(for: action) {
            activeActionID = nil
            lastFailedActionID = action.id
            lastSucceededActionID = nil
            publishBanner(
                style: .warning,
                title: "\(displayName(for: action)) isn’t available",
                detail: reason
            )
            scheduleRowStateReset()
            return
        }

        if confirmsDestructiveActions, action.requiresConfirmation, pendingConfirmationActionID != action.id {
            pendingConfirmationActionID = action.id
            publishBanner(
                style: .warning,
                title: "Confirm \(displayName(for: action))",
                detail: "Press the action again to continue."
            )
            scheduleConfirmationReset()
            return
        }

        pendingConfirmationActionID = nil
        activeActionID = action.id
        lastSucceededActionID = nil
        lastFailedActionID = nil

        let preferences = ActionExecutionPreferences(
            preferredBrowser: preferredBrowser,
            preferredMailApp: preferredMailApp
        )
        let actionTargetContext = actionTargetContext

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let outcome = try await performer.execute(
                    action,
                    preferences: preferences,
                    frontmostApplicationContext: actionTargetContext
                )
                handleExecutionSuccess(outcome, for: action)
            } catch let error as ActionExecutionError {
                handleExecutionFailure(error, for: action)
            } catch {
                handleExecutionFailure(.commandFailed(error.localizedDescription), for: action)
            }
        }
    }

    func publishSuccess(title: String, detail: String) {
        publishBanner(style: .success, title: title, detail: detail)
    }

    func publishError(title: String, detail: String) {
        publishBanner(style: .error, title: title, detail: detail)
    }

    private var favoriteActions: [SystemAction] {
        allActions.filter { favoriteIDs.contains($0.id) }
    }

    private var visibleActions: [SystemAction] {
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return allActions.filter { action in
            let passesEnabledFilter = showsDisabledActions || !disabledIDs.contains(action.id)
            guard passesEnabledFilter else {
                return false
            }

            guard !normalizedQuery.isEmpty else {
                return true
            }

            let terms = normalizedQuery.split(separator: " ").map(String.init)
            return terms.allSatisfy { action.searchableText.contains($0) }
        }
    }

    private func persistFavoriteIDs() {
        defaults.set(Array(favoriteIDs).sorted(), forKey: DefaultsKey.favoriteIDs)
    }

    private func persistDisabledIDs() {
        defaults.set(Array(disabledIDs).sorted(), forKey: DefaultsKey.disabledIDs)
    }

    private func persistLastUsedActionID() {
        defaults.set(lastUsedActionID, forKey: DefaultsKey.lastUsedActionID)
    }

    private func configureObservers() {
        NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)
            .merge(with: NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPermissions()
            }
            .store(in: &cancellables)
    }

    private func reconcilePreferredApps() {
        if !availableBrowserPreferences.contains(preferredBrowser) {
            preferredBrowser = .systemDefault
        }

        if !availableMailPreferences.contains(preferredMailApp) {
            preferredMailApp = .systemDefault
        }
    }

    private func refreshAvailableApplications() {
        availableBrowserPreferences = applicationRouter.availableBrowserPreferences()
        availableMailPreferences = applicationRouter.availableMailPreferences()
        reconcilePreferredApps()
    }

    private func syncLaunchAtStartup() {
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try startupManager.setEnabled(launchAtStartupEnabled)
                publishBanner(
                    style: .success,
                    title: launchAtStartupEnabled ? "Launch at startup enabled" : "Launch at startup disabled",
                    detail: launchAtStartupEnabled ? "CommandFlow will start when you sign in." : "CommandFlow will stay manual."
                )
            } catch {
                suppressLaunchAtStartupSync = true
                launchAtStartupEnabled.toggle()
                defaults.set(launchAtStartupEnabled, forKey: DefaultsKey.launchAtStartupEnabled)
                suppressLaunchAtStartupSync = false
                publishBanner(
                    style: .error,
                    title: "Couldn’t update launch at startup",
                    detail: error.localizedDescription
                )
            }
        }
    }

    private func publishBanner(style: FeedbackBanner.Style, title: String, detail: String) {
        withAnimation(LiquidGlassTheme.panelSpring) {
            feedbackBanner = FeedbackBanner(style: style, title: title, detail: detail)
        }

        bannerResetTask?.cancel()
        bannerResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            await MainActor.run {
                withAnimation(LiquidGlassTheme.rowSpring) {
                    self?.feedbackBanner = nil
                }
            }
        }
    }

    private func scheduleConfirmationReset() {
        confirmationResetTask?.cancel()
        confirmationResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            await MainActor.run {
                withAnimation(LiquidGlassTheme.rowSpring) {
                    self?.pendingConfirmationActionID = nil
                }
            }
        }
    }

    private func scheduleRowStateReset() {
        rowStateResetTask?.cancel()
        rowStateResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.75))
            await MainActor.run {
                withAnimation(LiquidGlassTheme.rowSpring) {
                    self?.lastSucceededActionID = nil
                    self?.lastFailedActionID = nil
                }
            }
        }
    }

    private func schedulePermissionRefresh() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.85))
            await MainActor.run {
                self?.refreshPermissions()
            }
        }
    }

    private func startPermissionPolling() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task { [weak self] in
            guard let self else {
                return
            }

            for _ in 0..<20 {
                try? await Task.sleep(for: .seconds(1))

                await MainActor.run {
                    self.refreshPermissions()
                }
            }
        }
    }

    private func syncKeyboardSoundPermissionState(previousSnapshot: PermissionSnapshot, wasEnabled: Bool) {
        if pendingKeyboardSoundEnable, permissionSnapshot.inputMonitoringGranted {
            pendingKeyboardSoundEnable = false
            publishBanner(
                style: .success,
                title: "Keyboard sound ready",
                detail: "Mechanical feedback is active."
            )
            return
        }

        if previousSnapshot.inputMonitoringGranted && !permissionSnapshot.inputMonitoringGranted && wasEnabled {
            inputMonitoringRequestPending = true
            publishBanner(
                style: .warning,
                title: "Keyboard sound is waiting",
                detail: "Input Monitoring is no longer granted, so playback is paused until macOS allows it again."
            )
        }
    }

    private static func clampedKeyboardSoundVolume(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func clampedFocusNoiseVolume(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func persistedDoubleDictionary(from dictionary: [String: Any]?) -> [String: Double] {
        guard let dictionary else {
            return [:]
        }

        return dictionary.reduce(into: [:]) { result, entry in
            switch entry.value {
            case let value as Double:
                result[entry.key] = value
            case let value as NSNumber:
                result[entry.key] = value.doubleValue
            default:
                break
            }
        }
    }

    private func unavailableReason(for action: SystemAction) -> String? {
        if case let .openApplication(bundleID) = action.transport, !applicationRouter.isInstalled(bundleID: bundleID) {
            return "This app is not installed on your Mac."
        }

        if action.permissionRequirement == .accessibility, !permissionSnapshot.accessibilityGranted {
            return "Enable Accessibility in Settings first."
        }

        if let automationTargetBundleIdentifier = action.automationTargetBundleIdentifier {
            let state: AutomationTargetPermissionState = switch automationTargetBundleIdentifier {
            case "com.apple.finder":
                permissionSnapshot.automationPermission.finder
            case "com.apple.systemevents":
                permissionSnapshot.automationPermission.systemEvents
            default:
                .unknown(0)
            }

            if case .denied = state {
                return "Review Automation permission for this action."
            }
        }

        if action.requiresFrontmostApplicationContext, actionTargetContext == nil {
            return "Open another app first, then reopen CommandFlow."
        }

        if action.requiresBrowserLikeApplication, actionTargetContext?.isBrowserLike != true {
            return "Open a browser first, then reopen CommandFlow."
        }

        return nil
    }

    private func handleExecutionSuccess(_ outcome: ActionExecutionOutcome, for action: SystemAction) {
        activeActionID = nil
        lastSucceededActionID = action.id
        lastFailedActionID = nil
        lastUsedActionID = action.id
        persistLastUsedActionID()
        menuBarPulseToken += 1

        if animatedFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }

        publishBanner(style: .success, title: outcome.title, detail: outcome.detail)
        scheduleRowStateReset()
    }

    private func handleExecutionFailure(_ error: ActionExecutionError, for action: SystemAction) {
        activeActionID = nil
        lastFailedActionID = action.id
        lastSucceededActionID = nil

        if case .missingPermission = error {
            refreshPermissions()
        }

        let detail: String
        switch error {
        case .missingPermission(.accessibility):
            detail = "Enable Accessibility to unlock keyboard-driven actions."
        case .missingPermission(.automation):
            detail = "Review Finder and System Events under Privacy & Security > Automation."
        default:
            detail = error.errorDescription ?? "The action could not complete."
        }

        publishBanner(style: .error, title: "Couldn’t run \(displayName(for: action))", detail: detail)
        scheduleRowStateReset()
    }
}
