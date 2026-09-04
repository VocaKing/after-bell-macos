import SwiftUI

enum AfterBellTheme {
    static let bg = Color(red: 8 / 255, green: 8 / 255, blue: 9 / 255)
    static let surface = Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255)
    static let raised = Color(red: 28 / 255, green: 28 / 255, blue: 32 / 255)
    static let fg = Color(red: 242 / 255, green: 241 / 255, blue: 238 / 255)
    static let muted = Color(red: 142 / 255, green: 141 / 255, blue: 136 / 255)
    static let accent = Color(red: 200 / 255, green: 204 / 255, blue: 212 / 255)
    static let accentFg = Color(red: 12 / 255, green: 12 / 255, blue: 13 / 255)
    static let danger = Color(red: 201 / 255, green: 137 / 255, blue: 128 / 255)
    static let warn = Color(red: 196 / 255, green: 180 / 255, blue: 154 / 255)

    static func brick(_ order: Int) -> Color {
        palette[abs(order) % palette.count]
    }

    static func brick(_ subject: Subject) -> Color {
        color(hex: subject.fill) ?? brick(subject.order)
    }

    static func brickNSColor(_ order: Int) -> NSColor {
        NSColor(brick(order))
    }

    static func brickNSColor(_ subject: Subject) -> NSColor {
        NSColor(brick(subject))
    }

    static let palette: [Color] = [
        Color(red: 0.46, green: 0.78, blue: 0.64),
        Color(red: 0.92, green: 0.72, blue: 0.34),
        Color(red: 0.46, green: 0.64, blue: 0.86),
        Color(red: 0.88, green: 0.52, blue: 0.54),
        Color(red: 0.90, green: 0.80, blue: 0.48),
        Color(red: 0.82, green: 0.76, blue: 0.64),
        Color(red: 0.72, green: 0.58, blue: 0.86),
        Color(red: 0.94, green: 0.62, blue: 0.42),
        Color(red: 0.40, green: 0.72, blue: 0.78),
        Color(red: 0.96, green: 0.74, blue: 0.78),
    ]

    static func brickHex(_ order: Int) -> String {
        hex(from: brick(order))
    }

    static func color(hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let value = UInt32(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    static func hex(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", max(0, min(r, 255)), max(0, min(g, 255)), max(0, min(b, 255)))
    }
}

struct GlassSurface: View {
    var tint: Color = Color.white
    var radius: CGFloat = 14
    var capsule: Bool = false

    init(tint: Color = Color.white, radius: CGFloat = 14, capsule: Bool = false) {
        self.tint = tint
        self.radius = radius
        self.capsule = capsule
    }

    init(radius: CGFloat, tint: Color, capsule: Bool = false) {
        self.tint = tint
        self.radius = radius
        self.capsule = capsule
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: capsule ? 999 : radius, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.42),
                        tint.opacity(0.28),
                        Color.white.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.82), Color.white.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
            Ellipse()
                .fill(Color.white.opacity(0.38))
                .frame(height: 16)
                .offset(y: -22)
                .blur(radius: 7)
                .mask(shape)
        }
        .shadow(color: tint.opacity(0.28), radius: 14, y: 8)
    }
}

struct LiquidGlass: ViewModifier {
    var tint: Color? = nil
    var radius: CGFloat = 14
    var capsule: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                GlassSurface(tint: tint ?? Color.white, radius: radius, capsule: capsule)
            }
    }
}

extension View {
    func liquidGlass(radius: CGFloat = 14, tint: Color? = nil) -> some View {
        modifier(LiquidGlass(tint: tint, radius: radius))
    }

    func liquidCapsule(tint: Color? = nil) -> some View {
        modifier(LiquidGlass(tint: tint, capsule: true))
    }
}

struct HomeworkGlyph: View {
    var code: String
    var color: Color
    var hovered: Bool

    var body: some View {
        Text(code)
            .font(.custom("MarkerFelt-Wide", size: 21))
            .tracking(0.6)
            .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.12))
            .frame(width: 52, height: 52)
            .background { GlassSurface(tint: color, radius: 16) }
            .scaleEffect(hovered ? 1.08 : 1)
            .offset(y: hovered ? -4 : 0)
            .animation(.easeOut(duration: 0.16), value: hovered)
    }
}
