import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: CommandFlowStore
    let onDismiss: () -> Void

    private var automationSummary: AutomationPermissionSummary {
        store.permissionSnapshot.automationPermission.summary
    }

    private var automationStateLabel: String {
        switch automationSummary {
        case .granted:
            return "Enabled"
        case .partiallyGranted:
            return "Review"
        case .requiresConsent:
            return "Required"
        case .denied:
            return "Open Privacy"
        case .unknown:
            return "Review"
        }
    }

    private var automationDetail: String {
        switch automationSummary {
        case .granted:
            return "Finder and System Events automation are already available."
        case .partiallyGranted:
            return "At least one automation target already works. CommandFlow can request the remaining target the next time it is needed."
        case .requiresConsent:
            return "Ask once for Finder or System Events automation so CommandFlow appears in Privacy & Security > Automation."
        case .denied:
            return "Automation was denied for at least one target. Open Privacy & Security > Automation to review it."
        case .unknown:
            return "Automation could not be fully verified. If it already works, macOS may simply not be exposing one target right now."
        }
    }

    private var automationPrimaryActionTitle: String {
        switch automationSummary {
        case .granted, .denied:
            return "Open Privacy"
        case .partiallyGranted:
            return "Request Again"
        case .requiresConsent, .unknown:
            return "Request Access"
        }
    }

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()

            VStack(alignment: .leading, spacing: 18) {
                header

                stepCard(
                    title: "Accessibility",
                    detail: "Needed for keyboard-driven actions like Spotlight, switching apps, and frontmost app controls.",
                    stateLabel: store.permissionSnapshot.accessibilityGranted ? "Enabled" : "Required",
                    isComplete: store.permissionSnapshot.accessibilityGranted,
                    primaryActionTitle: store.permissionSnapshot.accessibilityGranted ? "Open Settings" : "Enable",
                    primaryAction: {
                        if store.permissionSnapshot.accessibilityGranted {
                            store.openAccessibilitySettings()
                        } else {
                            store.requestAccessibilityPrompt()
                        }
                    },
                    secondaryActionTitle: "Privacy Pane",
                    secondaryAction: store.openAccessibilitySettings
                )

                stepCard(
                    title: "Automation",
                    detail: automationDetail,
                    stateLabel: automationStateLabel,
                    isComplete: store.permissionSnapshot.automationPermission.hasAnyGrantedTarget || store.automationGuidanceAcknowledged,
                    primaryActionTitle: automationPrimaryActionTitle,
                    primaryAction: {
                        if automationSummary == .granted || automationSummary == .denied {
                            store.openAutomationSettings()
                        } else {
                            store.requestAutomationPrompt()
                        }
                    },
                    secondaryActionTitle: "Open Privacy",
                    secondaryAction: store.openAutomationSettings
                )

                GlassSurface(cornerRadius: 22, padding: 18, glowColor: store.palette.glow) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready When You Are")
                            .font(.system(size: 15.5, weight: .semibold))

                        Text("Use Refresh Permissions after changing access in System Settings. macOS permissions are capricious, so if a prompt disappears or a pane does not update, open the privacy pane by hand, keep it open, relaunch the app if needed, and then refresh again.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Refusing a prompt does not revoke an already-approved accessibility entry.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button("Refresh Permissions") {
                                store.refreshPermissions()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(GlassPillBackground())

                            Button("Later") {
                                onDismiss()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(GlassPillBackground())

                            Button("Finish Setup") {
                                store.completeOnboarding()
                                onDismiss()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(GlassPillBackground())
                            .opacity(store.permissionSnapshot.onboardingReady ? 1 : 0.55)
                            .disabled(!store.permissionSnapshot.onboardingReady)
                        }
                    }
                }
            }
            .padding(22)
        }
        .frame(width: 490, height: 590)
        .background(FloatingWindowConfigurator())
        .onAppear {
            store.refreshPermissions()
        }
    }

    private var header: some View {
        GlassSurface(cornerRadius: 24, padding: 22, glowColor: store.palette.glow) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CommandFlowBrandSymbol(size: 42, enclosed: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CommandFlow")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Minimal setup for real system actions.")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("The interface stays nearly invisible. The permissions are the only visible part, and only when they matter.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stepCard(
        title: String,
        detail: String,
        stateLabel: String,
        isComplete: Bool,
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: String,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        GlassSurface(cornerRadius: 22, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15.5, weight: .semibold))
                        Text(detail)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 10)

                    Text(stateLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(GlassPillBackground())
                }

                HStack(spacing: 10) {
                    Button(primaryActionTitle) {
                        primaryAction()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GlassPillBackground())
                    .opacity(isComplete && primaryActionTitle == "Reviewed" ? 0.72 : 1)

                    Button(secondaryActionTitle) {
                        secondaryAction()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(GlassPillBackground())
                }
            }
        }
    }
}
