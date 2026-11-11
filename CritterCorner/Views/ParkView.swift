import CritterKit
import SwiftUI

enum ParkGame {
    case fetch, dig
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

    @State private var game: ParkGame

    init(game: ParkGame = .fetch) {
        _game = State(initialValue: game)
    }
    @State private var fetch: ParkFetch?
    @State private var t = ParkView.clock()
    @State private var coinsFound = 0
    @State private var bubble: String? = "Kom, vi leker!"
    @State private var friendBubble: String?
    @State private var floating: [FloatingText] = []
    @State private var mounds: [Mound] = []
    @State private var digsLeft = 3
    @State private var friend = Genome.random()
    @State private var hugUntil = 0.0

    private let shadow = Color(hex: 0xA9D4F0)
    private static let friendSize: CGFloat = 170
    private static let petSize: CGFloat = 240

    static func clock() -> Double { Date().timeIntervalSinceReferenceDate }

    private var friendName: String { String(NameGenerator.name(seed: friend.seed).split(separator: " ")[0]) }

    var body: some View {
        DesignCanvas(background: Color(hex: 0xCDEBFF)) { size in
            if let pet = store.pet {
                scene(pet: pet, size: size)
                    .onAppear { setUp(size: size) }
            }
        }
        .onAppear { if mounds.isEmpty { mounds = Self.makeMounds() } }
        .task { await loop() }
    }

    private func groundY(_ size: CGSize) -> CGFloat { size.height * 0.78 }

    private func setUp(size: CGSize) {
        guard fetch == nil else { return }
        let ground = groundY(size)
        let layout = ParkFetch.Layout(
            groundY: ground, hand: Point2(150, ground - 120),
            minX: 360, maxX: 1060, friendX: 1040, catchHeight: 190
        )
        fetch = ParkFetch(layout: layout, petX: 560, now: Self.clock())
        friendBubble = "\(friendName) vill leka! Tryck på mig."
    }

    private func scene(pet: Pet, size: CGSize) -> some View {
        let ground = groundY(size)
        let hugging = t < hugUntil
        let hugHop = hugging ? abs(sin((hugUntil - t) * 9)) * 40 : 0
        return ZStack(alignment: .topLeading) {
            ParkBackdrop(size: size)

            // Taps anywhere on the field: throw, catch, or invite the friend.
            Color.clear
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { tap($0.location) })
                .accessibilityIdentifier("park-field")

            if game == .dig {
                ForEach(mounds) { mound in
                    Button { dig(mound, width: size.width) } label: {
                        MoundView(reward: mound.reward)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .disabled(mound.reward != nil || digsLeft == 0)
                    .position(x: size.width * mound.point.x, y: size.height * mound.point.y)
                    .accessibilityLabel(mound.reward == nil ? "Jordhög. Tryck för att gräva." : "Uppgrävd")
                }
            }

            if let fetch {
                LiveCritterView(genome: friend, expression: fetch.friendJoined ? .excited : .happy, facingRight: false, blissful: hugging)
                    .frame(width: Self.friendSize, height: Self.friendSize)
                    .offset(y: -(fetch.hop(.friend, at: t) + hugHop))
                    .position(x: fetch.friendX, y: ground - Self.friendSize / 2 + 10)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("Kompisen \(friendName)")
                    .accessibilityIdentifier("park-friend")
                if let friendBubble {
                    SpeechBubble(text: friendBubble, tailOnLeft: false, maxWidth: 240)
                        .position(x: fetch.friendX - 70, y: ground - 250)
                        .allowsHitTesting(false)
                }

                let petHop = fetch.hop(.pet, at: t) + hugHop
                LiveCritterView(genome: pet.genome, expression: petHop > 0 || fetch.isRunning(.pet) ? .excited : .happy, weight: pet.weight, walking: fetch.isRunning(.pet), facingRight: fetch.petFacingRight, blissful: hugging, shine: pet.shine(at: store.now), condition: pet.condition(at: store.now), coat: .everyday(for: pet), style: pet.appearance)
                    .frame(width: Self.petSize, height: Self.petSize)
                    .offset(y: -petHop)
                    .position(x: fetch.petX, y: ground - 110)
                    .allowsHitTesting(false)

                if let bubble {
                    SpeechBubble(text: bubble, maxWidth: 260)
                        .position(x: min(fetch.petX + 150, 880), y: ground - 290)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if game == .fetch {
                    hand(fetch)
                }
                ball(fetch)
            }

            FloatingTextLayer(items: floating)

            hud(size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    /// Your hand in the corner: the ball sits in it when it's your turn.
    private func hand(_ fetch: ParkFetch) -> some View {
        Image(systemName: "hand.raised.fill")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(Color.peach)
            .frame(width: 96, height: 96)
            .background(Circle().fill(.white.opacity(0.85)))
            .overlay { if fetch.canThrow { RainbowBorder(cornerRadius: 48, lineWidth: 3) } }
            .position(x: fetch.layout.hand.x, y: fetch.layout.hand.y + 40)
            .allowsHitTesting(false)
    }

    private func ball(_ fetch: ParkFetch) -> some View {
        let position = fetch.ballPosition(at: t)
        let coming = fetch.isComingToYou(at: t)
        return ZStack {
            if coming {
                let pulse = 1 + sin(t * 10) * 0.08
                Circle()
                    .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 5, dash: [10, 8]))
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulse)
                Text("Fånga!")
                    .font(.cute(22, .bold))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(.white))
                    .offset(y: -86)
            }
            BallView()
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(t * 360))
        }
        .position(x: position.x, y: position.y)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Boll")
        .accessibilityValue(coming ? "fånga" : "")
        .accessibilityIdentifier("park-ball")
    }

    private func hud(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "Tillbaka hem", shadow: shadow) { goHome() }
                Spacer()
                TitlePill(title: "Parken på Solängen", shadow: shadow)
                Spacer()
                CoinPill(coins: store.state.coins + coinsFound, shadow: shadow)
            }
            .frame(width: size.width - 48)
            .position(x: size.width / 2, y: 24 + 30)

            VStack(alignment: .leading, spacing: 8) {
                if game == .fetch {
                    Text("Apport!").font(.cute(20, .bold))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(fetch?.catches ?? 0)").font(.cute(44, .bold))
                            .accessibilityIdentifier("park-score")
                        Text("fångade").font(.cute(16, .medium)).foregroundStyle(Color.inkSoft)
                    }
                    if let streak = fetch?.streak, streak >= 2 {
                        Text("Kombo ×\(streak)").font(.cute(16, .bold)).padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.pinkLight))
                    }
                    Text("Tryck på gräset för att kasta. Tryck på bollen när den kommer tillbaka!").font(.cute(15, .medium)).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Gräv!").font(.cute(20, .bold))
                    Text("\(digsLeft) kvar").font(.cute(28, .bold))
                    Text("Tryck på en jordhög för att gräva efter skatter.").font(.cute(15, .medium)).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Hittat: \(coinsFound) mynt").font(.cute(15)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color.butterLight))
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .frame(width: 230, alignment: .leading)
            .card(shadow: shadow)
            .position(x: 24 + 115, y: 130 + 110)

            Dock(shadow: shadow) {
                DockButton(title: "Kasta", systemName: "tennisball.fill", fill: .pinkLight, highlighted: game == .fetch, nudge: game == .fetch && fetch?.canThrow == true, width: 110) {
                    game = .fetch
                    throwBall(towardX: .random(in: 420...1000))
                }
                .accessibilityIdentifier("park-throw")
                DockButton(title: "Gräv", systemName: "sparkle.magnifyingglass", fill: Color(hex: 0xF3E6D4), highlighted: game == .dig, width: 110) {
                    game = .dig
                    say(digsLeft > 0 ? "Jag luktar skatter!" : "Allt är uppgrävt!")
                }
                DockButton(title: "Gå hem", systemName: "house.fill", fill: Color(hex: 0xE3F7DC), width: 110) { goHome() }
            }
            .position(x: Self.dockFrame(in: size).midX, y: Self.dockFrame(in: size).midY)
        }
    }

    /// Where the dock sits, so nothing you need to tap ends up behind it.
    static func dockFrame(in size: CGSize) -> CGRect {
        CGRect(x: size.width / 2 - 190, y: size.height - 132, width: 380, height: 120)
    }

    // MARK: Fetch

    private func loop() async {
        var last = Self.clock()
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Self.clock()
            let dt = min(0.05, now - last)
            last = now
            t = now
            guard var game = fetch else { continue }
            let events = game.update(to: now, dt: dt)
            fetch = game
            for event in events { react(to: event, in: game) }
        }
    }

    private func tap(_ point: CGPoint) {
        guard var game = fetch else { return }
        let now = Self.clock()
        if game.tryCatch(at: Point2(point.x, point.y), at: now) {
            fetch = game
            yourCatch(at: point, streak: game.streak)
            return
        }
        let friendFrame = CGRect(x: game.friendX - Self.friendSize / 2, y: game.layout.groundY - Self.friendSize - 30, width: Self.friendSize, height: Self.friendSize + 40)
        if friendFrame.insetBy(dx: -20, dy: -20).contains(point) {
            playWithFriend()
            return
        }
        if self.game == .fetch, point.y > 180, point.y < game.layout.groundY + 60, point.x > 300 {
            throwBall(towardX: point.x)
        }
    }

    private func throwBall(towardX x: CGFloat) {
        guard var game = fetch, game.throwBall(towardX: x, at: Self.clock()) else { return }
        fetch = game
        SoundFX.play(.boop)
        Haptics.tap()
        say("Jag tar den!")
    }

    private func playWithFriend() {
        guard var game = fetch else { return }
        if game.joinFriend() {
            fetch = game
            friendBubble = "Ja! Vi leker apport!"
            say("En kompis!")
        } else {
            friendBubble = "Kram!"
            say("Kompisar!")
        }
        hugUntil = Self.clock() + 1.2
        SoundFX.play(.squeak)
        Haptics.success()
        let ground = game.layout.groundY
        addFloat("♥", at: CGPoint(x: game.friendX, y: ground - 200))
        addFloat("♥", at: CGPoint(x: game.petX, y: ground - 240))
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if fetch?.friendJoined == true { friendBubble = nil }
        }
    }

    private func react(to event: ParkFetch.Event, in game: ParkFetch) {
        switch event {
        case .caught(by: .pet):
            reward(1, at: game.catchPoint(.pet))
            SoundFX.play(.squeak)
            Haptics.tap()
            say("Tog den!")
        case .caught(by: .friend):
            reward(1, at: game.catchPoint(.friend))
            SoundFX.play(.squeak)
            friendBubble = "Tog den!"
        case .caught(by: .you):
            break
        case .thrown(by: .pet):
            say(game.friendJoined ? "Till dig, \(friendName)!" : "Fånga!")
        case .thrown(by: .friend):
            friendBubble = "Fånga!"
            say("Fånga!")
        case .thrown(by: .you):
            break
        case .dropped:
            SoundFX.play(.boop)
            friendBubble = nil
            say("Oj! Kasta igen!")
        }
    }

    private func yourCatch(at point: CGPoint, streak: Int) {
        reward(1 + (streak >= 3 ? 1 : 0), at: Point2(point.x, point.y))
        Haptics.success()
        SoundFX.play(.coin)
        friendBubble = nil
        say(streak >= 3 ? "Kombo ×\(streak)! Du är bäst!" : "Bra fångat!")
    }

    private func reward(_ coins: Int, at point: Point2) {
        coinsFound += coins
        addFloat("+\(coins)", at: CGPoint(x: point.x, y: point.y - 40))
    }

    private func addFloat(_ text: String, at point: CGPoint) {
        let item = FloatingText(text: text, point: point)
        floating.append(item)
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            floating.removeAll { $0.id == item.id }
        }
    }

    // MARK: Dig

    /// Mounds on open grass, as fractions of the screen, since the dock stays centred whatever the width.
    /// Clear of the dock, the pond and the bench.
    static let moundSpots: [CGPoint] = [
        CGPoint(x: 0.28, y: 0.70), CGPoint(x: 0.22, y: 0.76), CGPoint(x: 0.59, y: 0.76),
        CGPoint(x: 0.74, y: 0.78), CGPoint(x: 0.75, y: 0.91), CGPoint(x: 0.88, y: 0.86),
    ]
    static let moundSize = CGSize(width: 120, height: 60)

    private static func makeMounds() -> [Mound] {
        moundSpots.enumerated().map { Mound(id: $0.offset, point: $0.element) }
    }

    private func dig(_ mound: Mound, width: CGFloat) {
        guard digsLeft > 0, let index = mounds.firstIndex(where: { $0.id == mound.id }) else { return }
        digsLeft -= 1
        let reward = [0, 2, 3, 4, 5, 8].randomElement()!
        mounds[index].reward = reward
        coinsFound += reward
        Haptics.tap()
        SoundFX.play(reward > 0 ? .coin : .boop)
        fetch?.walkPet(to: width * mound.point.x)
        say(reward == 0 ? "Bara en blomma. Så fin!" : (reward >= 5 ? "En skatt!!" : "Åh, mynt!"))
    }

    // MARK: Leaving

    private func goHome() {
        let found = coinsFound
        store.perform { state, now in state.finishPark(coinsFound: found, now: now) }
        if found > 0 { toaster.show("Vilken promenad! +\(found) mynt") }
        navigate(.home)
    }

    private func say(_ text: String) {
        withAnimation { bubble = text }
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
            .frame(width: ParkView.moundSize.width, height: ParkView.moundSize.height)
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
