import SwiftUI

struct FocusNoiseView: View {
    @ObservedObject var store: CommandFlowStore

    private var masterVolumeBinding: Binding<Double> {
        Binding(
            get: { store.focusNoiseMasterVolume },
            set: { store.setFocusNoiseMasterVolume($0) }
        )
    }

    private var pauseWithOtherAudioBinding: Binding<Bool> {
        Binding(
            get: { store.pauseFocusNoiseWithOtherAudio },
            set: { store.setPauseFocusNoiseWithOtherAudio($0) }
        )
    }

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "Focus Noise",
            detail: "Layer one or several ambient loops, mix them from the equalizer, and decide whether they pause when other media starts."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                summaryRow
                equalizerCard
                masterVolumeCard
                otherMediaToggleCard

                if store.focusNoiseTracks.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mixer")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(store.focusNoiseTracks) { track in
                            FocusNoiseTrackRow(
                                store: store,
                                track: track
                            )
                        }
                    }
                }
            }
        }
    }

    private var activeTracks: [FocusNoiseTrackDescriptor] {
        store.focusNoiseTracks.filter { store.isFocusNoiseEnabled($0.id) }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeFocusNoiseCount == 0 ? "Nothing is playing" : "\(store.activeFocusNoiseCount) ambient loop\(store.activeFocusNoiseCount == 1 ? "" : "s") playing")
                    .font(.system(size: 11.5, weight: .semibold))

                Text("Each sound keeps its own level, so you can build a small soundscape.")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Button("Stop all") {
                store.stopAllFocusNoise()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(store.activeFocusNoiseCount == 0 ? .secondary : store.palette.accentSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                GlassPillBackground()
                    .opacity(store.activeFocusNoiseCount == 0 ? 0.7 : 1)
            )
            .disabled(store.activeFocusNoiseCount == 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(store.palette.accent.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 0.7)
                )
        )
    }

    private var equalizerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Equalizer")
                    .font(.system(size: 11.5, weight: .semibold))

                Spacer(minLength: 8)

                if activeTracks.isEmpty {
                    Text("Start a sound to mix it")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(activeTracks.count) live")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if activeTracks.isEmpty {
                Text("Per-sound volume lives here now. Once you enable a few sounds, you can balance them from this panel without opening each row.")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(activeTracks) { track in
                        FocusNoiseEqualizerRow(store: store, track: track)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(store.palette.accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 0.7)
                )
        )
    }

    private var masterVolumeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Master volume")
                    .font(.system(size: 11.5, weight: .semibold))

                Spacer(minLength: 8)

                Text("\(Int(store.focusNoiseMasterVolume * 100))%")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            NativeGlassSlider(value: masterVolumeBinding, palette: store.palette)
        }
    }

    private var otherMediaToggleCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pause for other media")
                    .font(.system(size: 11.5, weight: .semibold))

                Text("Turn this on if you want Focus Noise to step aside when music, YouTube, or another audio app starts playing.")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: pauseWithOtherAudioBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(store.palette.accent.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 0.7)
                )
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No bundled sounds found")
                .font(.system(size: 11.5, weight: .semibold))

            Text("Drop some files into CommandFlow/Resources/Sounds/FocusNoise and rebuild the app.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

private struct FocusNoiseTrackRow: View {
    @ObservedObject var store: CommandFlowStore
    let track: FocusNoiseTrackDescriptor

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { store.isFocusNoiseEnabled(track.id) },
            set: { store.setFocusNoiseEnabled($0, for: track.id) }
        )
    }

    private var isEnabled: Bool {
        store.isFocusNoiseEnabled(track.id)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(store.palette.accent.opacity(isEnabled ? 0.16 : 0.06))
                    )

                Image(systemName: track.systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(isEnabled ? store.palette.accentSecondary : .primary.opacity(0.78))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(track.displayName)
                    .font(.system(size: 11.5, weight: .semibold))

                Text(isEnabled ? "Looping" : "Ready")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: enabledBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .fill(isEnabled ? store.palette.accent.opacity(0.08) : .white.opacity(0.01))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .strokeBorder(.white.opacity(isEnabled ? 0.08 : 0.05), lineWidth: 0.7)
                )
        )
    }
}

private struct FocusNoiseEqualizerRow: View {
    @ObservedObject var store: CommandFlowStore
    let track: FocusNoiseTrackDescriptor

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { store.focusNoiseVolume(for: track.id) },
            set: { store.setFocusNoiseTrackVolume($0, for: track.id) }
        )
    }

    private var volume: Double {
        store.focusNoiseVolume(for: track.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: track.systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(store.palette.accentSecondary)
                    .frame(width: 14)

                Text(track.displayName)
                    .font(.system(size: 10.5, weight: .semibold))

                Spacer(minLength: 8)

                Text("\(Int(volume * 100))%")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            NativeGlassSlider(value: volumeBinding, palette: store.palette)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                .fill(.white.opacity(0.018))
                .overlay(
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 0.6)
                )
        )
    }
}
