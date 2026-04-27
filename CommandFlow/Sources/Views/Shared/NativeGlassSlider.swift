import AppKit
import SwiftUI

struct NativeGlassSlider: View {
    @Binding var value: Double
    let palette: AccentPalette
    let range: ClosedRange<Double>
    let step: Double

    init(
        value: Binding<Double>,
        palette: AccentPalette,
        range: ClosedRange<Double> = 0...1,
        step: Double = 0.01
    ) {
        _value = value
        self.palette = palette
        self.range = range
        self.step = step
    }

    var body: some View {
        NativeSliderControl(value: $value, range: range, step: step)
            .frame(height: 20)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                            .fill(palette.accent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.controlRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.05), lineWidth: 0.7)
                    )
            )
    }
}

private struct NativeSliderControl: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.controlSize = .small
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.focusRingType = .default
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        if abs(nsView.doubleValue - value) > 0.0001 {
            nsView.doubleValue = value
        }
    }

    final class Coordinator: NSObject {
        private let parent: NativeSliderControl

        init(_ parent: NativeSliderControl) {
            self.parent = parent
        }

        @objc
        func valueChanged(_ sender: NSSlider) {
            let steppedValue = (round(sender.doubleValue / parent.step) * parent.step)
                .clamped(to: parent.range)
            parent.value = steppedValue
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
