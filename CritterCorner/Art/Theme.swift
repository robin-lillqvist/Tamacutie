import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let ink = Color(hex: 0x3B2C4A)
    static let inkSoft = Color(hex: 0x6B5A78)
    static let cream = Color(hex: 0xFFF7EE)
    static let coral = Color(hex: 0xFF7A8A)
    static let coralDeep = Color(hex: 0xE0566A)
    static let blush = Color(hex: 0xFF6F91)
    static let pink = Color(hex: 0xFF9EB5)
    static let pinkLight = Color(hex: 0xFFE3EC)
    static let mint = Color(hex: 0x7ED9C3)
    static let mintDeep = Color(hex: 0x5CC2A8)
    static let mintLight = Color(hex: 0xDDF4EE)
    static let butter = Color(hex: 0xFFD66B)
    static let butterDeep = Color(hex: 0xF5B83D)
    static let butterLight = Color(hex: 0xFFF1C4)
    static let sky = Color(hex: 0x8EC9FF)
    static let skyDeep = Color(hex: 0x5AA9F0)
    static let skyLight = Color(hex: 0xDDEEFF)
    static let lavender = Color(hex: 0xC3A8FF)
    static let lavenderDeep = Color(hex: 0xA98BFF)
    static let lavenderLight = Color(hex: 0xF1EAFF)
    static let peach = Color(hex: 0xFFB38A)
    static let peachLight = Color(hex: 0xFFE2CC)
    static let leaf = Color(hex: 0x7BC96F)
    static let leafDeep = Color(hex: 0x5CB85C)
    static let wood = Color(hex: 0xC9966A)
    static let woodDeep = Color(hex: 0xA87A52)
    static let poop = Color(hex: 0xA0704C)
    static let poopLight = Color(hex: 0xB07A4F)
}

extension Font {
    static func cute(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Chunky pastel button with the soft "pressed into the page" shadow from the mockups.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = .coral
    var shadow: Color = .coralDeep
    var foreground: Color = .ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cute(20, .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 26)
            .frame(minHeight: 56)
            .background(Capsule().fill(fill))
            .background(Capsule().fill(shadow).offset(y: configuration.isPressed ? 1 : 5))
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(duration: 0.15), value: configuration.isPressed)
    }
}

struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

struct CardBackground: ViewModifier {
    var fill: Color = .white
    var shadow: Color = Color(hex: 0xF3D3DC)
    var radius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(shadow).offset(y: 6))
    }
}

extension View {
    func card(fill: Color = .white, shadow: Color = Color(hex: 0xF3D3DC), radius: CGFloat = 28) -> some View {
        modifier(CardBackground(fill: fill, shadow: shadow, radius: radius))
    }
}
