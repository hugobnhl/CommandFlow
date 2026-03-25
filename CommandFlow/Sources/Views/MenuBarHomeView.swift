import AppKit
import SwiftUI

struct MenuBarHomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CommandFlow")
                .font(.title2.weight(.semibold))

            Text("Fresh macOS rebuild workspace")
                .font(.headline)

            Text(appState.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if appState.legacyReferenceAvailable {
                Label("Legacy reference imported", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Divider()

            SettingsLink {
                Label("Open Settings", systemImage: "gearshape")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit CommandFlow", systemImage: "xmark.circle")
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

