import CritterKit
import SwiftUI

private enum ParkGame {
    case fetch, dig
}

private struct Flight {
    let id = UUID()
    let start: Date
    let from: CGPoint
    let to: CGPoint
    static let duration: TimeInterval = 1.8

    func point(at date: Date) -> CGPoint {
        let t = min(1, max(0, date.timeIntervalSince(start) / Self.duration))
        let x = from.x + (to.x - from.x) * t
        let arc = -sin(t * .pi) * 260
        let y = from.y + (to.y - from.y) * t + arc
        return CGPoint(x: x, y: y)
    }
}

private struct Mound: Identifiable {
    let id: Int
    let point: CGPoint
    var reward: Int?
}

struct ParkView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    @State private var game = ParkGame.fetch
    @State private var flight: Flight?
    @State private var catches = 0
    @State private var combo = 0
    @State private var coinsFound = 0
    @State private var petX: CGFloat = 560
    @State private var petHop = false
    @State private var petWalking = false
    @State private var petFacingRight = true
    @State private var bubble: String? = "Let's play!"
    @State private var floating: [FloatingText] = []
    @State private var mounds: [Mound] = []
    @State private var digsLeft = 3
    @State private var friend = Genome.random()

    private let shadow = Color(hex: 0xA9D4F0)

    var body: some View {
        DesignCanvas(background: Color(hex: 0xCDEBFF)) { size in
            if let pet = store.pet {
                scene(pet: pet, size: size)
            }
        }
        .onAppear { if mounds.isEmpty { mounds = Self.makeMounds() } }
    }

    private func groundY(_ size: CGSize) -> CGFloat { size.height * 0.78 }

    private func scene(pet: Pet, size: CGSize) -> some View {
        let ground = groundY(size)
        return ZStack(alignment: .topLeading) {
            ParkBackdrop(size: size)

            if game == .dig {
                ForEach(mounds) { mound in
                    Button { dig(mound) } label: {
                        MoundView(reward: mound.reward)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .disabled(mound.reward != nil || digsLeft == 0)
                    .position(x: mound.point.x, y: size.height * mound.point.y)
                    .accessibilityLabel(mound.reward == nil ? "Dirt mound. Tap to dig." : "Dug up")
                }
            }

            LiveCritterView(genome: friend, expression: .happy)
                .frame(width: 150, height: 150)
                .position(x: 1000, y: ground - 120)
                .allowsHitTesting(false)
            SpeechBubble(text: "\(NameGenerator.name(seed: friend.seed).split(separator: " ")[0]) wants to play!", tailOnLeft: false)
                .position(x: 940, y: ground - 230)

            LiveCritterView(genome: pet.genome, expression: petHop || petWalking ? .excited : .happy, weight: pet.weight, walking: petWalking, facingRight: petFacingRight, blissful: petHop, shine: pet.shine(at: store.now))
                .frame(width: 240, height: 240)
                .offset(y: petHop ? -60 : 0)
                .position(x: petX, y: ground - 110)
                .allowsHitTesting(false)

            if let bubble {
                SpeechBubble(text: bubble)
                    .position(x: petX + 170, y: ground - 270)
                    .transition(.opacity)
            }

            if let flight {
                TimelineView(.animation) { timeline in
                    let point = flight.point(at: timeline.date)
                    Button { catchFrisbee(flight, at: point) } label: {
                        Frisbee().frame(width: 110, height: 60).contentShape(Rectangle().inset(by: -30))
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .position(point)
                    .accessibilityLabel("Frisbee. Tap to catch!")
                }
            }

            FloatingTextLayer(items: floating)

            hud(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private func hud(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "Back home", shadow: shadow) { goHome() }
                Spacer()
                TitlePill(title: "Sunny Meadow Park", shadow: shadow)
                Spacer()
                CoinPill(coins: store.state.coins + coinsFound, shadow: shadow)
            }
            .frame(width: size.width - 48)
            .position(x: size.width / 2, y: 24 + 30)

            VStack(alignment: .leading, spacing: 8) {
                if game == .fetch {
                    Text("Fetch!").font(.cute(20, .bold))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(catches)").font(.cute(44, .bold))
                        Text("catches").font(.cute(16, .medium)).foregroundStyle(Color.inkSoft)
                    }
                    if combo >= 2 {
                        Text("Combo ×\(combo)").font(.cute(16, .bold)).padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.pinkLight))
                    }
                    Text("Throw it, then tap the frisbee to catch it!").font(.cute(15, .medium)).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Dig!").font(.cute(20, .bold))
                    Text("\(digsLeft) digs left").font(.cute(28, .bold))
                    Text("Tap a dirt mound to dig for treasure.").font(.cute(15, .medium)).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Found: \(coinsFound) coins").font(.cute(15)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color.butterLight))
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .frame(width: 230, alignment: .leading)
            .card(shadow: shadow)
            .position(x: 24 + 115, y: 130 + 110)

            Dock(shadow: shadow) {
                DockButton(title: flight == nil ? "Throw" : "Flying!", systemName: "circle.circle.fill", fill: .pinkLight, highlighted: game == .fetch, width: 110) {
                    game = .fetch
                    throwFrisbee()
                }
                DockButton(title: "Dig", systemName: "sparkle.magnifyingglass", fill: Color(hex: 0xF3E6D4), highlighted: game == .dig, width: 110) {
                    game = .dig
                    flight = nil
                    say(digsLeft > 0 ? "I smell treasure!" : "All dug out!")
                }
                DockButton(title: "Go home", systemName: "house.fill", fill: Color(hex: 0xE3F7DC), width: 110) { goHome() }
            }
            .position(x: size.width / 2, y: size.height - 72)
        }
    }

    // MARK: Fetch

    private func throwFrisbee() {
        guard flight == nil else { return }
        let launch = Flight(start: .now, from: CGPoint(x: 120, y: 520), to: CGPoint(x: .random(in: 520...880), y: .random(in: 480...560)))
        flight = launch
        run(to: launch.to.x - 60, duration: Flight.duration)
        Task {
            try? await Task.sleep(for: .seconds(Flight.duration))
            guard flight?.id == launch.id else { return }
            flight = nil
            combo = 0
            say("Aww, missed it!")
        }
    }

    private func catchFrisbee(_ caught: Flight, at point: CGPoint) {
        guard flight?.id == caught.id else { return }
        flight = nil
        catches += 1
        combo += 1
        let reward = 1 + (combo >= 3 ? 1 : 0)
        coinsFound += reward
        floating.append(FloatingText(text: "+\(reward)", point: point))
        Haptics.success()
        SoundFX.play(.squeak)
        run(to: point.x - 40, duration: 0.3)
        withAnimation(.spring(duration: 0.3)) { petHop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(duration: 0.3)) { petHop = false }
            try? await Task.sleep(for: .seconds(1))
            floating.removeAll()
        }
        say(combo >= 3 ? "Combo ×\(combo)! I'm the best!" : "Got it!")
    }

    // MARK: Dig

    private static func makeMounds() -> [Mound] {
        [(330.0, 0.84), (470, 0.92), (640, 0.86), (790, 0.94), (900, 0.84), (240, 0.94)]
            .enumerated()
            .map { Mound(id: $0.offset, point: CGPoint(x: $0.element.0, y: $0.element.1)) }
    }

    private func dig(_ mound: Mound) {
        guard digsLeft > 0, let index = mounds.firstIndex(where: { $0.id == mound.id }) else { return }
        digsLeft -= 1
        let reward = [0, 2, 3, 4, 5, 8].randomElement()!
        mounds[index].reward = reward
        coinsFound += reward
        Haptics.tap()
        SoundFX.play(reward > 0 ? .coin : .boop)
        run(to: mound.point.x, duration: 0.6)
        say(reward == 0 ? "Just a flower. Pretty!" : (reward >= 5 ? "Treasure!!" : "Ooh, coins!"))
    }

    private func run(to x: CGFloat, duration: Double) {
        petFacingRight = x > petX
        petWalking = true
        withAnimation(.easeInOut(duration: duration)) { petX = x }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            petWalking = false
        }
    }

    // MARK: Leaving

    private func goHome() {
        let found = coinsFound
        store.perform { state, now in state.finishPark(coinsFound: found, now: now) }
        if found > 0 { toaster.show("What a walk! +\(found) coins") }
        navigate(.home)
    }

    private func say(_ text: String) {
        withAnimation { bubble = text }
    }
}

private struct Frisbee: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            SketchView(width: 110, height: 60) { c in
                c.oval(55, 30, 46, 13, .coral)
                c.oval(55, 26, 30, 7, .pink)
            }
            .rotationEffect(.degrees(sin(timeline.date.timeIntervalSinceReferenceDate * 8) * 10))
        }
    }
}

private struct MoundView: View {
    let reward: Int?

    var body: some View {
        ZStack {
            SketchView(width: 120, height: 60) { c in
                c.oval(60, 44, 56, 18, reward == nil ? .woodDeep : Color(hex: 0x8B6B5A))
                if reward == nil {
                    c.oval(60, 38, 40, 12, .wood)
                    c.dot(44, 34, 4, Color(hex: 0xE5B585))
                    c.dot(74, 36, 3, Color(hex: 0xE5B585))
                }
            }
            .frame(width: 120, height: 60)
            if let reward {
                if reward > 0 {
                    HStack(spacing: 2) {
                        CoinIcon(size: 30)
                        Text("+\(reward)").font(.cute(18, .bold)).foregroundStyle(Color.ink)
                    }
                    .offset(y: -36)
                } else {
                    SketchView(width: 40, height: 50) { c in
                        c.line(.leafDeep, width: 4) { p in p.move(to: CGPoint(x: 20, y: 50)); p.addLine(to: CGPoint(x: 20, y: 22)) }
                        for angle in stride(from: 0.0, to: 360, by: 72) {
                            let r = angle * .pi / 180
                            c.dot(20 + cos(r) * 9, 16 + sin(r) * 9, 7, .pink)
                        }
                        c.dot(20, 16, 6, .butter)
                    }
                    .frame(width: 40, height: 50)
                    .offset(y: -36)
                }
            }
        }
        .frame(width: 130, height: 110)
        .contentShape(Rectangle())
    }
}

private struct ParkBackdrop: View {
    let size: CGSize

    var body: some View {
        Canvas { c, _ in
            let h = size.height
            let w = size.width
            c.dot(1040, 150, 64, Color(hex: 0xFFE59A))
            c.dot(1040, 150, 46, .butter)
            c.oval(220, 150, 70, 26, .white); c.oval(260, 130, 46, 30, .white); c.oval(180, 136, 34, 22, .white)
            c.oval(700, 110, 56, 20, .white); c.oval(730, 94, 36, 24, .white)

            c.shape(Color(hex: 0xA8E3B8)) { p in
                p.move(to: CGPoint(x: 0, y: h * 0.5))
                p.addQuadCurve(to: CGPoint(x: 420, y: h * 0.48), control: CGPoint(x: 200, y: h * 0.37))
                p.addQuadCurve(to: CGPoint(x: 880, y: h * 0.49), control: CGPoint(x: 640, y: h * 0.34))
                p.addQuadCurve(to: CGPoint(x: w, y: h * 0.46), control: CGPoint(x: 1060, y: h * 0.4))
                p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
            }
            c.shape(Color(hex: 0x8ED6A2)) { p in
                p.move(to: CGPoint(x: 0, y: h * 0.6))
                p.addQuadCurve(to: CGPoint(x: 600, y: h * 0.59), control: CGPoint(x: 300, y: h * 0.5))
                p.addQuadCurve(to: CGPoint(x: w, y: h * 0.6), control: CGPoint(x: 920, y: h * 0.5))
                p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
            }

            for (x, y, r) in [(140.0, 0.42, 56.0), (1080, 0.47, 62), (870, 0.41, 36)] {
                let base = h * y
                c.box(x - 8, base + 30, 16, r * 1.4, radius: 8, .poopLight)
                c.dot(x, base, r, .leafDeep)
                c.dot(x - r * 0.4, base - r * 0.25, r * 0.28, .leaf)
            }

            c.oval(160, h * 0.86, 150, 36, .sky)
            c.oval(140, h * 0.855, 90, 16, Color(hex: 0xBFE6FF))

            c.box(780, h * 0.64, 160, 16, radius: 8, .wood)
            c.box(780, h * 0.64 + 24, 160, 16, radius: 8, .wood)
            c.box(792, h * 0.64 + 40, 12, 40, radius: 6, .woodDeep)
            c.box(916, h * 0.64 + 40, 12, 40, radius: 6, .woodDeep)

            for (x, y, color) in [(80.0, 0.7, Color.pink), (420, 0.73, .lavender), (1120, 0.74, .pink), (760, 0.95, .white), (120, 0.97, .lavender)] {
                c.dot(x, h * y, 8, color)
                c.dot(x, h * y, 3, .butter)
            }

            let flutter = CGPoint(x: 480, y: 220)
            c.oval(flutter.x - 10, flutter.y - 6, 12, 9, .pink)
            c.oval(flutter.x + 10, flutter.y - 6, 12, 9, .lavender)
            c.box(flutter.x - 2, flutter.y - 14, 4, 18, radius: 2, .ink)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
