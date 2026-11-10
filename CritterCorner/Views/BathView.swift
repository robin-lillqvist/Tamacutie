import CritterKit
import SwiftUI

enum BathStep: Int, CaseIterable {
    case fill, scrub, rinse, dry, done

    var title: String {
        switch self {
        case .fill: "Fill"
        case .scrub: "Scrub"
        case .rinse: "Rinse"
        case .dry: "Dry"
        case .done: "Done"
        }
    }

    var hint: String {
        switch self {
        case .fill: "Tap the tap to fill the tub!"
        case .scrub: "Rub the sponge all over!"
        case .rinse: "Shower the bubbles away!"
        case .dry: "Pat dry with the towel!"
        case .done: "Squeaky clean!"
        }
    }
}

struct BathView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    @State private var step = BathStep.fill
    @State private var progress: Double = 0
    @State private var water: Double = 0
    @State private var bubbles: [Bubble] = []
    @State private var tool: CGPoint?
    @State private var lastPoint: CGPoint?
    @State private var useShampoo = false
    @State private var bubble: String?

    private let shadow = Color(hex: 0xA3DCCB)

    var body: some View {
        DesignCanvas(background: .mintLight) { size in
            if let pet = store.pet {
                scene(pet: pet, size: size)
            }
        }
    }

    private func petCenter(_ size: CGSize) -> CGPoint { CGPoint(x: 600, y: size.height * 0.62 - 90) }

    private func scene(pet: Pet, size: CGSize) -> some View {
        let center = petCenter(size)
        let tubTop = size.height * 0.62
        return ZStack(alignment: .topLeading) {
            BathBackdrop(size: size)

            LiveCritterView(
                genome: pet.genome,
                expression: step == .done ? .excited : (pet.genome.has(.lovesBaths) || step == .fill ? .happy : .content),
                weight: pet.weight,
                look: tool.map { CGVector(dx: max(-1, min(1, ($0.x - center.x) / 200)), dy: max(-1, min(1, ($0.y - center.y + 30) / 200))) } ?? .zero,
                wiggle: tool != nil && step == .dry,
                blissful: tool != nil && step == .scrub,
                shine: step == .done ? pet.shine(at: store.now) : 0
            )
                .frame(width: 300, height: 300)
                .position(center)
                .allowsHitTesting(false)

            ForEach(bubbles) { item in
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(item.tint.opacity(0.6), lineWidth: 3))
                    .frame(width: item.size, height: item.size)
                    .position(item.point)
                    .transition(.scale.combined(with: .opacity))
            }
            .allowsHitTesting(false)

            Tub(width: 720, water: water)
                .frame(width: 720, height: 170)
                .position(x: 600, y: tubTop + 85)
                .allowsHitTesting(false)

            Color.clear
                .frame(width: 520, height: 420)
                .contentShape(Rectangle())
                .gesture(scrubbing(center: center))
                .position(x: center.x, y: center.y + 20)

            if let tool, step != .fill, step != .done {
                Image(systemName: toolSymbol)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(toolColor)
                    .shadow(color: .ink.opacity(0.2), radius: 0, y: 4)
                    .position(tool)
                    .allowsHitTesting(false)
            }

            if let bubble {
                SpeechBubble(text: bubble, tailOnLeft: false)
                    .position(x: center.x + 230, y: center.y - 170)
            }

            hud(pet: pet, size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private func hud(pet: Pet, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "Back home", shadow: shadow) { navigate(.home) }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(BathStep.allCases.dropLast(), id: \.self) { candidate in
                        Text("\(candidate.rawValue + 1) \(candidate.title)")
                            .font(.cute(17))
                            .foregroundStyle(candidate == step ? .white : (candidate.rawValue < step.rawValue ? Color.ink : Color.inkSoft))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(candidate == step ? Color.ink : (candidate.rawValue < step.rawValue ? Color.mintLight : .clear)))
                    }
                }
                .padding(8)
                .card(shadow: shadow, radius: 30)
                Spacer()
                CoinPill(coins: store.state.coins, shadow: shadow)
            }
            .frame(width: size.width - 48)
            .position(x: size.width / 2, y: 24 + 30)

            VStack(alignment: .leading, spacing: 10) {
                Text("Sparkle meter").font(.cute(18, .bold))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xEAF3F0))
                        Capsule().fill(Color.mint).frame(width: max(16, geo.size.width * sparkle))
                    }
                }
                .frame(height: 16)
                Text(step.hint).font(.cute(15, .medium)).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                Text("+\(Rules.bathReward) coins when sparkly").font(.cute(15)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color.butterLight))
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .frame(width: 220)
            .card(shadow: shadow)
            .position(x: 24 + 110, y: size.height * 0.42)

            Group {
                switch step {
                case .fill:
                    Button { fillTub() } label: { Label("Turn on the tap", systemImage: "drop.fill") }
                        .buttonStyle(ChunkyButtonStyle(fill: .sky, shadow: .skyDeep))
                case .done:
                    Button("All clean! Back home") { navigate(.home) }
                        .buttonStyle(ChunkyButtonStyle())
                default:
                    Dock(shadow: shadow) {
                        DockButton(title: "Sponge", systemName: "hands.and.sparkles.fill", fill: .butterLight, highlighted: step == .scrub, width: 110) {}
                        DockButton(title: useShampoo ? "Shampoo ✓" : "Shampoo ×\(store.state.count(of: "shampoo"))", systemName: "sparkles", fill: Color(hex: 0xECE4FF), highlighted: useShampoo, width: 110) { toggleShampoo() }
                        DockButton(title: "Shower", systemName: "shower.fill", fill: .skyLight, highlighted: step == .rinse, width: 110) {}
                        DockButton(title: "Towel", systemName: "wind", fill: .pinkLight, highlighted: step == .dry, width: 110) {}
                    }
                }
            }
            .position(x: size.width / 2, y: size.height - 72)
        }
    }

    private var sparkle: Double {
        switch step {
        case .fill: 0
        case .scrub: progress * 0.34
        case .rinse: 0.34 + progress * 0.33
        case .dry: 0.67 + progress * 0.33
        case .done: 1
        }
    }

    private var toolSymbol: String {
        switch step {
        case .rinse: "shower.fill"
        case .dry: "wind"
        default: "hands.and.sparkles.fill"
        }
    }

    private var toolColor: Color {
        switch step {
        case .rinse: .skyDeep
        case .dry: .coral
        default: .butterDeep
        }
    }

    private func scrubbing(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard step == .scrub || step == .rinse || step == .dry else { return }
                let point = CGPoint(x: center.x - 260 + value.location.x, y: center.y + 20 - 210 + value.location.y)
                tool = point
                if let last = lastPoint {
                    let distance = hypot(point.x - last.x, point.y - last.y)
                    progress = min(1, progress + distance / 2600)
                    switch step {
                    case .scrub:
                        if Int.random(in: 0..<3) == 0 {
                            if Int.random(in: 0..<4) == 0 { SoundFX.play(.pop) }
                            bubbles.append(Bubble(point: point, size: .random(in: 18...54), tint: [.lavender, .sky, .pink, .mint].randomElement()!))
                        }
                    case .rinse:
                        if !bubbles.isEmpty, Int.random(in: 0..<2) == 0 {
                            _ = withAnimation(.easeOut(duration: 0.2)) { bubbles.removeFirst() }
                        }
                    default:
                        break
                    }
                }
                lastPoint = point
                if progress >= 1 { advance() }
            }
            .onEnded { _ in
                lastPoint = nil
                tool = nil
            }
    }

    private func fillTub() {
        SoundFX.play(.splash)
        withAnimation(.easeInOut(duration: 1.2)) { water = 1 }
        say("Ooh, warm water!")
        step = .scrub
        progress = 0
    }

    private func toggleShampoo() {
        if useShampoo { useShampoo = false; return }
        if store.state.count(of: "shampoo") > 0 {
            useShampoo = true
            say("Bubbly!")
        } else {
            toaster.show("No shampoo. Find it in the market's bath aisle.")
        }
    }

    private func advance() {
        progress = 0
        lastPoint = nil
        switch step {
        case .scrub:
            step = .rinse
            say("Hee hee, that tickles!")
        case .rinse:
            withAnimation { bubbles.removeAll() }
            step = .dry
            say("Brrr… towel please!")
        case .dry:
            step = .done
            tool = nil
            withAnimation(.easeInOut(duration: 1)) { water = 0 }
            let coins = store.perform { state, now in state.finishBath(useShampoo: useShampoo, now: now) }
            SoundFX.play(.coin)
            Haptics.success()
            say(useShampoo ? "Extra sparkly!! Look at me shine!" : "Look how shiny I am!")
            toaster.show("Bath done: +\(coins) coins!")
        default:
            break
        }
    }

    private func say(_ text: String) {
        withAnimation(.spring) { bubble = text }
    }
}

struct Bubble: Identifiable {
    let id = UUID()
    let point: CGPoint
    let size: CGFloat
    let tint: Color
}

private struct Tub: View {
    let width: CGFloat
    let water: Double

    var body: some View {
        Canvas { c, size in
            let w = size.width
            if water > 0 {
                c.box(30, 28 - CGFloat(water) * 26, w - 60, 40, radius: 16, Color.sky.opacity(0.7))
                for x in stride(from: 60.0, to: Double(w) - 40, by: 60) {
                    c.dot(x, 26 - CGFloat(water) * 26, 22, .white)
                }
            }
            c.shape(.white) { p in
                p.move(to: CGPoint(x: 20, y: 20))
                p.addLine(to: CGPoint(x: w - 20, y: 20))
                p.addLine(to: CGPoint(x: w - 20, y: 70))
                p.addQuadCurve(to: CGPoint(x: w - 130, y: 160), control: CGPoint(x: w - 20, y: 160))
                p.addLine(to: CGPoint(x: 130, y: 160))
                p.addQuadCurve(to: CGPoint(x: 20, y: 70), control: CGPoint(x: 20, y: 160))
                p.closeSubpath()
            }
            c.box(0, 0, w, 34, radius: 17, .white)
            c.outline(Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: 34), cornerRadius: 17), Color(hex: 0xD6ECFF), width: 4)
            c.box(60, 150, 40, 20, radius: 10, .butterDeep)
            c.box(w - 100, 150, 40, 20, radius: 10, .butterDeep)
        }
    }
}

private struct BathBackdrop: View {
    let size: CGSize

    var body: some View {
        Canvas { c, _ in
            let floorTop = size.height * 0.72
            var y: CGFloat = 3
            while y < floorTop {
                var x: CGFloat = 3
                while x < size.width {
                    c.box(x, y, 54, 54, radius: 10, Color(hex: 0xE9FAF5))
                    x += 60
                }
                y += 60
            }
            c.box(0, floorTop, size.width, size.height - floorTop, Color(hex: 0xB8E8DA))
            c.dot(120, 210, 56, .white)
            c.dot(120, 210, 44, Color(hex: 0xBFE6FF))
            c.box(1010, 200, 130, 10, radius: 5, .wood)
            c.shape(.pink) { p in
                p.move(to: CGPoint(x: 1030, y: 210)); p.addLine(to: CGPoint(x: 1120, y: 210)); p.addLine(to: CGPoint(x: 1120, y: 360))
                p.addQuadCurve(to: CGPoint(x: 1030, y: 360), control: CGPoint(x: 1075, y: 378)); p.closeSubpath()
            }
            c.line(.white, width: 6, dash: [10, 10]) { p in p.move(to: CGPoint(x: 1030, y: 330)); p.addLine(to: CGPoint(x: 1120, y: 330)) }
            c.line(Color(hex: 0xB7C4CC), width: 14) { p in p.move(to: CGPoint(x: 760, y: 90)); p.addLine(to: CGPoint(x: 760, y: 180)); p.addLine(to: CGPoint(x: 700, y: 180)) }
            c.shape(Color(hex: 0xD5DEE3)) { $0.addLines([CGPoint(x: 660, y: 180), CGPoint(x: 750, y: 180), CGPoint(x: 738, y: 206), CGPoint(x: 672, y: 206)]) }
            // Rubber duck.
            let duck = CGPoint(x: 900, y: floorTop - 70)
            c.oval(duck.x, duck.y + 40, 36, 20, .butter)
            c.dot(duck.x + 22, duck.y + 16, 18, .butter)
            c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: duck.x + 36, y: duck.y + 18), CGPoint(x: duck.x + 52, y: duck.y + 22), CGPoint(x: duck.x + 36, y: duck.y + 28)]) }
            c.dot(duck.x + 26, duck.y + 12, 3, .ink)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
