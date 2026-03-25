import AppKit
import SwiftUI

struct ColorPaletteView: View {
    @ObservedObject var store: CommandFlowStore

    @State private var selectedColor = Color(red: 0.21, green: 0.57, blue: 0.96)
    @State private var copiedValue: String?

    var body: some View {
        ToolGlassContainer(
            store: store,
            title: "Color Palette",
            detail: store.autoCopyColor ? "Pick a color and its HEX value copies automatically." : "Pick a color, inspect its codes, and copy the value you need."
        ) {
            VStack(alignment: .leading, spacing: store.densityMetrics.stackSpacing) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                        .fill(selectedColor)
                        .frame(width: 86, height: 86)
                        .overlay(
                            RoundedRectangle(cornerRadius: LiquidGlassTheme.sectionRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.18), lineWidth: 0.7)
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        ColorPicker("Pick Color", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)

                        CodeValueRow(title: "HEX", value: hexValue, store: store) {
                            copy(hexValue)
                        }

                        CodeValueRow(title: "RGB", value: rgbValue, store: store) {
                            copy(rgbValue)
                        }
                    }
                }

                if let copiedValue {
                    Text("\(copiedValue) copied")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .onChange(of: selectedColor) { _, _ in
                guard store.autoCopyColor else {
                    return
                }
                copy(hexValue)
            }
        }
    }

    private var nsColor: NSColor {
        let resolved = NSColor(selectedColor)
        return resolved.usingColorSpace(.extendedSRGB) ?? resolved
    }

    private var hexValue: String {
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private var rgbValue: String {
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return "RGB(\(red), \(green), \(blue))"
    }

    private func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        withAnimation(.easeOut(duration: 0.18)) {
            copiedValue = value
        }

        Task {
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.18)) {
                    copiedValue = nil
                }
            }
        }
    }
}

private struct CodeValueRow: View {
    let title: String
    let value: String
    @ObservedObject var store: CommandFlowStore
    let copyAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Copy") {
                copyAction()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(store.palette.accentSecondary)
        }
    }
}
