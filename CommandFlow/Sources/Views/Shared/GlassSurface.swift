import AppKit
import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct FloatingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }
            configure(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }
            configure(window)
        }
    }

    private func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
}

struct ForegroundWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.makeKeyAndOrderFront(nil)
        }
    }
}

struct LiquidGlassBackdrop: View {
    var body: some View {
        Color.clear
            .overlay {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.78)
            }
            .overlay {
                RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.12),
                                .white.opacity(0.035),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.03),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 100)
                    .blur(radius: 12)
                    .offset(x: -18, y: -18)
            }
        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.panelRadius, style: .continuous))
        .background(Color.clear)
    }
}

struct GlassSurface<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let glowColor: Color?
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = LiquidGlassTheme.sectionRadius,
        padding: CGFloat = 18,
        glowColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.glowColor = glowColor
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(Color.clear)
            .background {
                Color.clear
                    .overlay {
                        VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.68)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.08),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    }
                    .overlay {
                        if let glowColor {
                            RadialGradient(
                                colors: [glowColor.opacity(0.12), .clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 160
                            )
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct GlassPillBackground: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.clear)
            .overlay(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.72)
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.035))
            )
    }
}
