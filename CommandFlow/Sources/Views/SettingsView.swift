import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Environment") {
                    LabeledContent("App name", value: appState.appName)
                    LabeledContent("Development bundle ID", value: appState.developmentBundleIdentifier)
                    LabeledContent("Legacy bundle ID", value: appState.legacyBundleIdentifier)
                }

                Section("What this clean rebuild fixes") {
                    Text("The app now lives outside Playground, uses a separate bundle identifier, and can be rebuilt from reproducible project files.")
                    Text("Old local installs and preferences are cleaned up separately so they do not pollute testing.")
                    Text("The full feature rebuild will now happen from this clean base.")
                }

                Section("Beginner note") {
                    Text("A build log comes from Xcode or xcodebuild while the app is compiling.")
                    Text("A runtime log comes from the app while it is running.")
                    Text("System logs come from macOS itself and can be inspected in Console.")
                }
            }
            .navigationTitle("Settings")
            .frame(minWidth: 640, minHeight: 420)
        }
    }
}

