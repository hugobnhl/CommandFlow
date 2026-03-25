import AppKit
import Combine
import SwiftUI

struct PermissionSnapshot: Equatable {
    let accessibilityGranted: Bool
    let automationGuidanceAcknowledged: Bool

    var onboardingReady: Bool {
        accessibilityGranted && automationGuidanceAcknowledged
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
        static let lastUsedActionID = "CommandFlow.lastUsedActionID"
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
    @Published private(set) var availableBrowserPreferences: [BrowserPreference]
    @Published private(set) var availableMailPreferences: [MailPreference]
    @Published private(set) var permissionSnapshot: PermissionSnapshot
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
    @Published var automationGuidanceAcknowledged: Bool {
        didSet {
            defaults.set(automationGuidanceAcknowledged, forKey: DefaultsKey.automationGuidanceAcknowledged)
            refreshPermissions()
        }
    }

    let allActions = ActionCatalog.all

    private let defaults = UserDefaults.standard
    private let permissionCenter = PermissionCenter()
    private let applicationRouter = ApplicationRouter()
    private let startupManager = LaunchAtStartupManager()
    private let performer: SystemActionPerformer

    private var cancellables = Set<AnyCancellable>()
    private var bannerResetTask: Task<Void, Never>?
    private var rowStateResetTask: Task<Void, Never>?
    private var confirmationResetTask: Task<Void, Never>?
    private var suppressLaunchAtStartupSync = false

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
        availableBrowserPreferences = applicationRouter.availableBrowserPreferences()
        availableMailPreferences = applicationRouter.availableMailPreferences()
        lastUsedActionID = defaults.string(forKey: DefaultsKey.lastUsedActionID)
        permissionSnapshot = PermissionSnapshot(
            accessibilityGranted: permissionCenter.accessibilityGranted(),
            automationGuidanceAcknowledged: persistedAutomationAcknowledged
        )
        performer = SystemActionPerformer(
            permissionCenter: permissionCenter,
            applicationRouter: applicationRouter
        )

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
        !permissionSnapshot.accessibilityGranted
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

    var shouldKeepMenuPresented: Bool {
        disableAutoClose || isDragInteractionActive || isDragDropToolActive
    }

    func isFavorite(_ action: SystemAction) -> Bool {
        favoriteIDs.contains(action.id)
    }

    func isDisabled(_ action: SystemAction) -> Bool {
        disabledIDs.contains(action.id)
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

    func refreshPermissions() {
        permissionSnapshot = PermissionSnapshot(
            accessibilityGranted: permissionCenter.accessibilityGranted(),
            automationGuidanceAcknowledged: automationGuidanceAcknowledged
        )
        refreshAvailableApplications()
    }

    func requestAccessibilityPrompt() {
        permissionCenter.requestAccessibilityPrompt()
        schedulePermissionRefresh()
    }

    func openAccessibilitySettings() {
        permissionCenter.openAccessibilitySettings()
        schedulePermissionRefresh()
    }

    func openAutomationSettings() {
        permissionCenter.openAutomationSettings()
    }

    func requestAutomationPrompt() {
        permissionCenter.requestAutomationPrompt()
    }

    func markAutomationGuidanceAcknowledged() {
        automationGuidanceAcknowledged = true
    }

    func completeOnboarding() {
        guard permissionSnapshot.onboardingReady else {
            return
        }

        didCompleteOnboarding = true
        defaults.set(true, forKey: DefaultsKey.didCompleteOnboarding)
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

    func perform(_ action: SystemAction) {
        guard !isDisabled(action) else {
            return
        }

        if confirmsDestructiveActions, action.requiresConfirmation, pendingConfirmationActionID != action.id {
            pendingConfirmationActionID = action.id
            publishBanner(
                style: .warning,
                title: "Confirm \(action.name)",
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

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let outcome = try await performer.execute(action, preferences: preferences)
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
            detail = "Allow automation for CommandFlow in Privacy & Security."
        default:
            detail = error.errorDescription ?? "The action could not complete."
        }

        publishBanner(style: .error, title: "Couldn’t run \(action.name)", detail: detail)
        scheduleRowStateReset()
    }
}
