import SwiftUI

struct CommandFlowBrandSymbol: View {
    let size: CGFloat
    var enclosed = false

    var body: some View {
        Group {
            if enclosed {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .fill(.white.opacity(0.12))

                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)

                    glyph
                }
                .frame(width: size, height: size)
            } else {
                glyph
                    .frame(width: size, height: size)
            }
        }
    }

    private var glyph: some View {
        Image(systemName: "command")
            .font(.system(size: size * 0.64, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.92))
    }
}

struct MenuBarLabelView: View {
    let pulseToken: Int

    var body: some View {
        CommandFlowBrandSymbol(size: 14)
            .symbolEffect(.bounce, value: pulseToken)
            .accessibilityLabel("CommandFlow")
    }
}
