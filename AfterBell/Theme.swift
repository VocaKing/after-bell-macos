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
        let palette: [Color] = [
            Color(red: 0.55, green: 0.78, blue: 0.68),
            Color(red: 0.86, green: 0.76, blue: 0.52),
            Color(red: 0.58, green: 0.70, blue: 0.84),
            Color(red: 0.86, green: 0.66, blue: 0.66),
            Color(red: 0.88, green: 0.82, blue: 0.68),
            Color(red: 0.90, green: 0.88, blue: 0.82),
        ]
        return palette[abs(order) % palette.count]
    }

    static func brickNSColor(_ order: Int) -> NSColor {
        NSColor(brick(order))
    }
}
