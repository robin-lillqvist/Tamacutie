import CritterKit
import SwiftUI

/// Lays a screen out in the 1194-point-wide design space from the mockups and scales it to the iPad.
/// The height follows the device's aspect ratio, so every iPad fills edge to edge.
struct DesignCanvas<Content: View>: View {
    var background: Color = .cream
    @ViewBuilder var content: (CGSize) -> Content

    static var designWidth: CGFloat { 1194 }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / Self.designWidth
            let size = CGSize(width: Self.designWidth, height: max(600, geo.size.height / scale))
            content(size)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(background.ignoresSafeArea())
    }
}

/// Sound on or off, for the whole game.
struct MuteButton: View {
    @AppStorage(SoundFX.mutedKey) private var muted = false
    var shadow = Color(hex: 0xF3D3DC)

    var body: some View {
        Button {
            muted.toggle()
            if !muted { SoundFX.play(.boop) }
        } label: {
            Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(muted ? Color.inkSoft : Color.ink)
                .frame(width: 58, height: 58)
                .card(shadow: shadow, radius: 29)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityIdentifier("mute")
        .accessibilityLabel(muted ? "Ljudet är av. Tryck för att slå på." : "Ljudet är på. Tryck för att stänga av.")
    }
}

struct CoinPill: View {
    let coins: Int
    var shadow = Color(hex: 0xF3D3DC)

    var body: some View {
        HStack(spacing: 10) {
            CoinIcon(size: 38)
            Text("\(coins)")
                .font(.cute(24, .bold))
                .contentTransition(.numericText())
                .animation(.spring, value: coins)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .frame(height: 58)
        .card(shadow: shadow, radius: 29)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(coins) mynt")
    }
}

struct RoundIconButton: View {
    let systemName: String
    let label: String
    var shadow = Color(hex: 0xF3D3DC)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.ink)
                .frame(width: 60, height: 60)
                .card(shadow: shadow, radius: 30)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(label)
    }
}

struct TitlePill: View {
    let title: String
    var shadow = Color(hex: 0xF3D3DC)

    var body: some View {
        Text(title)
            .font(.cute(30, .bold))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 30)
            .frame(height: 60)
            .card(shadow: shadow, radius: 30)
    }
}

struct DockButton: View {
    let title: String
    let systemName: String
    let fill: Color
    /// Selected state, e.g. the toy currently in hand.
    var highlighted = false
    /// "Press me": a thin spinning rainbow border.
    var nudge = false
    /// A bit larger and bouncing, for the one button that matters right now.
    var bouncy = false
    var width: CGFloat = 92
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(title)
                    .font(.cute(16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.ink)
            .frame(width: width, height: 84)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.ink, lineWidth: highlighted ? 3 : 0))
            .overlay { if nudge { RainbowBorder(cornerRadius: 26) } }
            .modifier(Bounce(active: bouncy))
        }
        .buttonStyle(SquishyButtonStyle())
    }
}

/// A thin rainbow outline whose colours rotate around the shape.
struct RainbowBorder: View {
    var cornerRadius: CGFloat
    var lineWidth: CGFloat = 2
    /// Seconds per full turn.
    var period: Double = 2.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let colors: [Color] = [
        Color(hex: 0xFF5E7E), Color(hex: 0xFFA24C), Color(hex: 0xFFD84D), Color(hex: 0x6ED98A),
        Color(hex: 0x52B8FF), Color(hex: 0x9A7BFF), Color(hex: 0xFF5E7E),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(colors: Self.colors, center: .center, angle: .degrees(turn * 360)),
                    lineWidth: lineWidth
                )
        }
        .allowsHitTesting(false)
    }
}

/// Grows slightly and hops up and down while active.
private struct Bounce: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // A hop every 1.2 s: quick rise, soft landing, then rest.
                let phase = t.truncatingRemainder(dividingBy: 1.2) / 1.2
                let hop = phase < 0.45 ? sin(phase / 0.45 * .pi) : 0
                let squash = phase >= 0.45 && phase < 0.6 ? sin((phase - 0.45) / 0.15 * .pi) : 0
                content
                    .scaleEffect(x: 1.12 + squash * 0.05, y: 1.12 - squash * 0.06, anchor: .bottom)
                    .offset(y: -hop * 9)
            }
        } else {
            content
        }
    }
}

struct Dock<Content: View>: View {
    var shadow = Color(hex: 0xF3D3DC)
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .padding(10)
            .card(shadow: shadow, radius: 36)
    }
}

struct SpeechBubble: View {
    let text: String
    var tailOnLeft = true
    /// Wrap onto several lines instead of growing wider than this.
    var maxWidth: CGFloat?

    var body: some View {
        Text(text)
            .font(.cute(21))
            .foregroundStyle(Color.ink)
            .multilineTextAlignment(.leading)
            .frame(width: wrapWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 22,
                    bottomLeadingRadius: tailOnLeft ? 6 : 22,
                    bottomTrailingRadius: tailOnLeft ? 22 : 6,
                    topTrailingRadius: 22,
                    style: .continuous
                ).fill(.white)
                .shadow(color: Color(hex: 0xF3D3DC), radius: 0, y: 6)
            )
            .fixedSize(horizontal: maxWidth == nil, vertical: true)
    }

    /// A fixed text width, only when the line is too long to fit on one row.
    private var wrapWidth: CGFloat? {
        guard let maxWidth else { return nil }
        let base = UIFont.systemFont(ofSize: 21, weight: .semibold)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 21) } ?? base
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return width > maxWidth - 36 ? maxWidth - 36 : nil
    }
}

/// A short floating message, e.g. "+2 coins".
struct FloatingText: Identifiable {
    let id = UUID()
    let text: String
    let point: CGPoint
}

struct FloatingTextLayer: View {
    let items: [FloatingText]

    var body: some View {
        ZStack {
            ForEach(items) { item in
                FloatUp(text: item.text)
                    .position(item.point)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FloatUp: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(.cute(20, .bold))
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.butter))
            .offset(y: risen ? -70 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { risen = true }
            }
    }
}

struct HeartBurst: Identifiable {
    let id = UUID()
    let point: CGPoint
    let drift: CGFloat
}

struct HeartLayer: View {
    let hearts: [HeartBurst]

    var body: some View {
        ZStack {
            ForEach(hearts) { heart in
                RisingHeart(drift: heart.drift).position(heart.point)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RisingHeart: View {
    let drift: CGFloat
    @State private var risen = false

    var body: some View {
        HeartIcon(size: 40, color: drift > 0 ? .coral : .pink)
            .scaleEffect(risen ? 1.2 : 0.4)
            .offset(x: risen ? drift : 0, y: risen ? -120 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) { risen = true }
            }
    }
}

/// A toast at the top of the screen, owned by the root view.
@MainActor
@Observable
final class Toaster {
    private(set) var message: String?
    private var token = UUID()

    func show(_ text: String) {
        let current = UUID()
        token = current
        withAnimation(.spring) { message = text }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard token == current else { return }
            withAnimation(.easeOut) { message = nil }
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.cute(21, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.ink))
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

extension Pet {
    var pronounName: String { name.split(separator: " ").first.map(String.init) ?? name }
}

/// A small eager grid; lazy grids render nothing in snapshot renders and these lists are short.
struct VGrid<TItem: Identifiable, TCell: View>: View {
    let columns: Int
    let spacing: CGFloat
    let items: [TItem]
    @ViewBuilder let cell: (TItem) -> TCell

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(items[start..<min(start + columns, items.count)]) { item in
                        cell(item).frame(maxWidth: .infinity)
                    }
                    ForEach(0..<(columns - min(columns, items.count - start)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }
}
