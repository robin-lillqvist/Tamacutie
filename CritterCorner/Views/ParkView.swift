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

/// Something in the park your sötis is walking over to, to play with.
private enum ParkGoal: Equatable {
    case swing, slide, sandbox, kiosk, pond(CGFloat)
}

/// Where everything in the wide park is. The meadow (fetch, the friend, the bench) is the first screen,
/// then the playground (swings, slide, sandbox), then the pond (ducks, butterflies, the ice-cream kiosk).
struct ParkGeometry {
    let size: CGSize
    var ground: CGFloat { size.height * 0.78 }
    static let meadowEnd: CGFloat = 1194

    // Playground.
    var swingPivots: [CGPoint] { [CGPoint(x: 1480, y: ground - 330), CGPoint(x: 1620, y: ground - 330)] }
    var ropeLength: CGFloat { 250 }
    var swingArea: CGRect { CGRect(x: 1370, y: ground - 350, width: 360, height: 370) }
    var slideLadderX: CGFloat { 1840 }
    var slideTopY: CGFloat { ground - 210 }
    var rampStart: CGPoint { CGPoint(x: slideLadderX + 100, y: slideTopY) }
    var rampEnd: CGPoint { CGPoint(x: 2120, y: ground - 10) }
    var slideArea: CGRect { CGRect(x: 1790, y: slideTopY - 60, width: 380, height: ground - slideTopY + 80) }
    var sandbox: CGRect { CGRect(x: 2200, y: ground - 92, width: 190, height: 74) }
    var sandboxSpot: CGFloat { sandbox.minX - 30 }

    // Pond.
    var pondCenter: CGPoint { CGPoint(x: 2830, y: ground - 62) }
    var pondRadii: CGSize { CGSize(width: 300, height: 44) }
    var pondArea: CGRect { CGRect(x: pondCenter.x - pondRadii.width, y: pondCenter.y - pondRadii.height - 20, width: pondRadii.width * 2, height: pondRadii.height * 2 + 40) }
    var flowers: CGPoint { CGPoint(x: 3250, y: ground - 14) }
    var kiosk: CGRect { CGRect(x: 3400, y: ground - 270, width: 160, height: 262) }
    var kioskSpot: CGFloat { kiosk.minX - 120 }
    /// Where to stand to watch the ducks: at the water's edge on the side you tapped, not in the pond.
    func pondEdge(near x: CGFloat) -> CGFloat {
        x < pondCenter.x ? pondCenter.x - pondRadii.width - 70 : pondCenter.x + pondRadii.width + 70
    }
}

struct ParkView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    @State private var game: ParkGame
    @State private var fetch: ParkFetch?
    @State private var play: ParkPlay?
    @State private var t = ParkView.clock()
    @State private var coinsFound = 0
    @State private var bubble: String? = "Kom, vi leker!"
    @State private var friendBubble: String?
    @State private var floating: [FloatingText] = []
    @State private var mounds: [Mound] = []
    @State private var digsLeft = 4
    @State private var friend = Genome.random()
    @State private var hugUntil = 0.0

    // Wandering about the park.
    @State private var camera = WorldCamera(worldWidth: DesignCanvas<EmptyView>.designWidth * Rules.parkScreens, viewportWidth: DesignCanvas<EmptyView>.designWidth)
    @State private var cameraX: CGFloat = 0
    @State private var goal: ParkGoal?
    @State private var onSwing = false
    @State private var cheerUntil = 0.0
    @State private var iceCreamUntil = 0.0
    @State private var countedPushes = 0
    @State private var lastGeometry = ParkGeometry(size: CGSize(width: 3582, height: 834))
    // Picking your sötis up and carrying it somewhere.
    @State private var carryPoint: CGPoint?
    @State private var fall: (fromFeetY: CGFloat, start: Double)?

    private let shadow = Color(hex: 0xA9D4F0)
    private static let fallTime = 0.35
    private static let friendSize: CGFloat = 170
    private static let petSize: CGFloat = 240
    /// The sötis's feet are drawn this far above the bottom of its frame (14 of 200 canvas units).
    private static let feetInset = petSize * 14 / 200

    init(game: ParkGame = .fetch) {
        _game = State(initialValue: game)
    }

    static func clock() -> Double { Date().timeIntervalSinceReferenceDate }

    private var friendName: String { String(NameGenerator.name(seed: friend.seed).split(separator: " ")[0]) }

    var body: some View {
        DesignCanvas(background: Color(hex: 0xCDEBFF)) { size in
            if let pet = store.pet {
                let geometry = ParkGeometry(size: CGSize(width: size.width * Rules.parkScreens, height: size.height))
                ZStack(alignment: .topLeading) {
                    world(pet: pet, g: geometry)
                        .offset(x: -cameraX)
                    hud(size: size)
                    EdgeArrows(cameraX: cameraX, worldWidth: geometry.size.width, size: size, y: geometry.ground + 40) { right in
                        camera.camera.page(right: right)
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                .coordinateSpace(.named("screen"))
                .onAppear {
                    lastGeometry = geometry
                    camera.resize(worldWidth: geometry.size.width, viewportWidth: size.width)
                    setUp(g: geometry)
                }
            }
        }
        .onAppear { if mounds.isEmpty { mounds = Self.makeMounds() } }
        .task { await loop() }
        .task { await camera.run(follow: { followTarget() }, publish: { cameraX = $0 }) }
    }

    private func setUp(g: ParkGeometry) {
        guard fetch == nil else { return }
        let ground = g.ground
        let layout = ParkFetch.Layout(
            groundY: ground, hand: Point2(150, ground - 120),
            minX: 120, maxX: g.size.width - 120, throwMinX: 360, throwMaxX: 1060,
            friendX: 1040, catchHeight: 190
        )
        fetch = ParkFetch(layout: layout, petX: 560, now: Self.clock())
        play = ParkPlay(config: ParkPlay.Config(
            pondCenter: Point2(g.pondCenter.x, g.pondCenter.y),
            pondRadii: Point2(g.pondRadii.width, g.pondRadii.height),
            flowers: Point2(g.flowers.x, g.flowers.y)
        ))
        friendBubble = "\(friendName) vill leka! Tryck på mig."
    }

    // MARK: World

    private func world(pet: Pet, g: ParkGeometry) -> some View {
        let ground = g.ground
        let hugging = t < hugUntil
        let hugHop = hugging ? abs(sin((hugUntil - t) * 9)) * 40 : 0
        return ZStack(alignment: .topLeading) {
            ParkBackdrop(size: g.size)

            // Every tap and swipe on the park: look around, throw, catch, or go and play with something.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: g.size.width, height: g.size.height)
                .gesture(fieldGesture(g: g))
                .accessibilityIdentifier("park-field")

            if let play {
                ParkLiving(g: g, play: play, t: t)
            }
            hotspots(g: g)

            if game == .dig {
                ForEach(mounds) { mound in
                    Button { dig(mound) } label: {
                        MoundView(reward: mound.reward)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .disabled(mound.reward != nil || digsLeft == 0)
                    .position(x: mound.point.x, y: g.size.height * mound.point.y)
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

                petView(pet: pet, fetch: fetch, g: g, hugHop: hugHop, hugging: hugging)
                grabHandle(fetch: fetch, g: g)

                if t < iceCreamUntil {
                    ItemArt(id: "icecream")
                        .frame(width: 70, height: 70)
                        .position(x: fetch.petX + 70, y: ground - 120)
                        .allowsHitTesting(false)
                }

                if let bubble {
                    let pose = petPose(fetch: fetch, g: g)
                    SpeechBubble(text: bubble, maxWidth: 260)
                        .position(x: min(pose.center.x + 150, cameraX + DesignCanvas<EmptyView>.designWidth - 150), y: pose.center.y - 180)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                if game == .fetch {
                    hand(fetch)
                }
                ball(fetch)
            }

            FloatingTextLayer(items: floating)
        }
        .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
    }

    /// Invisible markers so VoiceOver (and UI tests) can find the things to play with.
    private func hotspots(g: ParkGeometry) -> some View {
        ZStack(alignment: .topLeading) {
            spot("park-swing", "Gungorna. Tryck för att gunga.", g.swingArea)
            spot("park-slide", "Rutschkanan.", g.slideArea)
            spot("park-sandbox", "Sandlådan. Tryck för att bygga ett sandslott.", g.sandbox.insetBy(dx: 0, dy: -20))
            spot("park-pond", "Ankdammen. Tryck på vattnet för att mata ankorna.", CGRect(x: g.pondCenter.x - 120, y: g.pondCenter.y - 30, width: 240, height: 60))
            spot("park-kiosk", "Glasskiosken. En glass kostar \(Catalog.item("icecream")?.price ?? 0) mynt.", g.kiosk)
            if let play {
                ForEach(0..<ParkPlay.butterflyCount, id: \.self) { index in
                    if play.isHere(index, at: t) {
                        let p = play.butterfly(index, at: t)
                        spot("butterfly-\(index)", "Fjäril", CGRect(x: p.x - 30, y: p.y - 30, width: 60, height: 60))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func spot(_ id: String, _ label: String, _ rect: CGRect) -> some View {
        Color.clear
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityElement()
            .accessibilityIdentifier(id)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: Your sötis

    private struct Pose {
        var center: CGPoint
        var tilt: Double = 0
        var walking = false
        var facingRight = true
    }

    /// The frame centre that puts the sötis's feet on `feet`.
    private func standing(on feet: CGPoint) -> CGPoint {
        CGPoint(x: feet.x, y: feet.y + Self.feetInset - Self.petSize / 2)
    }

    private func petPose(fetch: ParkFetch, g: ParkGeometry) -> Pose {
        if let carryPoint {
            return Pose(center: CGPoint(x: carryPoint.x, y: carryPoint.y + 85), tilt: sin(t * 6) * 5)
        }
        if let fall {
            let u = min(1, (t - fall.start) / Self.fallTime)
            let feetY = fall.fromFeetY + (g.ground - fall.fromFeetY) * u * u
            return Pose(center: standing(on: CGPoint(x: fetch.petX, y: feetY)))
        }
        if onSwing, let play {
            let angle = play.swingAngle(at: t) * .pi / 180
            let pivot = g.swingPivots[0]
            let seat = CGPoint(x: pivot.x + sin(angle) * g.ropeLength, y: pivot.y + cos(angle) * g.ropeLength)
            return Pose(center: standing(on: CGPoint(x: seat.x, y: seat.y - 6)), tilt: -play.swingAngle(at: t))
        }
        if let phase = play?.slidePhase(at: t) {
            switch phase {
            case .climbing(let u):
                let feetY = g.ground + (g.slideTopY - g.ground) * min(1, u * 1.15)
                let x = u < 0.87 ? g.slideLadderX : g.slideLadderX + (g.rampStart.x - g.slideLadderX - 20) * (u - 0.87) / 0.13
                return Pose(center: standing(on: CGPoint(x: x, y: feetY)))
            case .sliding(let u):
                let eased = u * u
                let feet = CGPoint(x: g.rampStart.x + (g.rampEnd.x - g.rampStart.x) * eased,
                                   y: g.rampStart.y + (g.rampEnd.y - g.rampStart.y) * eased - 16)
                return Pose(center: standing(on: feet), tilt: 12)
            case .landing(let u):
                let hop = sin(u * .pi) * 40
                return Pose(center: standing(on: CGPoint(x: g.rampEnd.x + 60 * u, y: g.ground - hop)))
            }
        }
        let cheer = t < cheerUntil ? abs(sin((cheerUntil - t) * 8)) * 36 : 0
        return Pose(center: standing(on: CGPoint(x: fetch.petX, y: g.ground - cheer)), walking: fetch.isRunning(.pet), facingRight: fetch.petFacingRight)
    }

    private func petView(pet: Pet, fetch: ParkFetch, g: ParkGeometry, hugHop: Double, hugging: Bool) -> some View {
        let pose = petPose(fetch: fetch, g: g)
        let petHop = fetch.hop(.pet, at: t) + hugHop
        let busy = onSwing || play?.slidePhase(at: t) != nil
        let excited = petHop > 0 || fetch.isRunning(.pet) || busy || t < cheerUntil
        return LiveCritterView(genome: pet.genome, expression: excited ? .excited : .happy, weight: pet.weight, walking: pose.walking, facingRight: pose.facingRight, blissful: hugging || t < iceCreamUntil, shine: pet.shine(at: store.now), condition: pet.condition(at: store.now), coat: .everyday(for: pet), style: pet.appearance)
            .frame(width: Self.petSize, height: Self.petSize)
            .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
            .offset(y: -petHop)
            .position(pose.center)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityIdentifier("park-pet")
            .accessibilityLabel(pet.name)
            .accessibilityValue(onSwing ? "gungar" : (play?.slidePhase(at: t) != nil ? "åker rutschkana" : ""))
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

    // MARK: HUD

    private func hud(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "Tillbaka hem", shadow: shadow) { goHome() }
                Spacer()
                TitlePill(title: "Parken på Solängen", shadow: shadow)
                Spacer()
                HStack(spacing: 12) {
                    MuteButton(shadow: shadow)
                    CoinPill(coins: store.state.coins + coinsFound, shadow: shadow)
                }
            }
            .frame(width: size.width - 48)
            .position(x: size.width / 2, y: 24 + 30)

            // The score sits under the title, clear of the sötis wherever it plays.
            HStack(spacing: 14) {
                if game == .fetch {
                    Text("\(fetch?.catches ?? 0)").font(.cute(30, .bold))
                        .accessibilityIdentifier("park-score")
                    Text("fångade").font(.cute(16, .medium)).foregroundStyle(Color.inkSoft)
                    if let streak = fetch?.streak, streak >= 2 {
                        Text("Kombo ×\(streak)").font(.cute(16, .bold)).padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Color.pinkLight))
                    }
                } else {
                    Text("\(digsLeft)").font(.cute(30, .bold))
                    Text("grävningar kvar").font(.cute(16, .medium)).foregroundStyle(Color.inkSoft)
                }
                Text("Hittat: \(coinsFound) mynt").font(.cute(15)).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.butterLight))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 18)
            .frame(height: 50)
            .card(shadow: shadow, radius: 25)
            .position(x: size.width / 2, y: 24 + 30 + 66)
            .allowsHitTesting(false)

            Dock(shadow: shadow) {
                DockButton(title: "Kasta", systemName: "tennisball.fill", fill: .pinkLight, highlighted: game == .fetch, nudge: game == .fetch && fetch?.canThrow == true, width: 110) {
                    game = .fetch
                    camera.camera.glide(toX: 0)
                    throwBall(towardX: .random(in: 420...1000))
                }
                .accessibilityIdentifier("park-throw")
                DockButton(title: "Gräv", systemName: "sparkle.magnifyingglass", fill: Color(hex: 0xF3E6D4), highlighted: game == .dig, width: 110) {
                    game = .dig
                    say(digsLeft > 0 ? "Jag luktar skatter! Leta i hela parken." : "Allt är uppgrävt!")
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

    // MARK: Time

    private func loop() async {
        var last = Self.clock()
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Self.clock()
            let dt = min(0.05, now - last)
            last = now
            t = now
            guard var game = fetch else { continue }
            if var activities = play {
                activities.stepSwing(dt)
                let ate = activities.stepDucks(dt, at: now)
                if let chased = activities.chasing {
                    game.walkPet(to: activities.butterfly(chased, at: now).x)
                }
                if let caught = activities.checkCatch(petX: game.petX, at: now) {
                    caughtButterfly(at: activities.butterfly(caught, at: now))
                }
                if activities.finishSlide(at: now) {
                    game.placePet(at: Double(lastGeometry.rampEnd.x + 60))
                    finishedSlide(at: CGPoint(x: lastGeometry.rampEnd.x + 60, y: lastGeometry.ground - 200))
                }
                play = activities
                for _ in ate { duckAte(total: activities.crumbsEaten) }
            }
            let events = game.update(to: now, dt: dt)
            fetch = game
            for event in events { react(to: event, in: game) }
            if let goal, !game.isRunning(.pet) { arrive(at: goal) }
            if let fall, now - fall.start >= Self.fallTime {
                self.fall = nil
                Haptics.thump()
                SoundFX.play(.bounce)
                cheerUntil = now + 0.5
            }
        }
    }

    /// The camera keeps your sötis in view (unless you scrolled off on purpose).
    private func followTarget() -> CGFloat? {
        guard let fetch, carryPoint == nil else { return nil }
        return petPose(fetch: fetch, g: lastGeometry).center.x
    }

    // MARK: Touches

    private func fieldGesture(g: ParkGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("screen"))
            .onChanged { value in
                let point = CGPoint(x: value.location.x + camera.x, y: value.location.y)
                _ = point
                _ = camera.drag(translation: value.translation.width)
            }
            .onEnded { value in
                let point = CGPoint(x: value.location.x + camera.x, y: value.location.y)
                if camera.endDrag(velocity: value.velocity.width) { return }
                tap(point, g: g)
            }
    }

    // MARK: Carrying

    /// An invisible handle on your sötis: tap it for a hello, or hold it to pick it up and carry it.
    private func grabHandle(fetch: ParkFetch, g: ParkGeometry) -> some View {
        let center = petPose(fetch: fetch, g: g).center
        return Color.clear
            .contentShape(Rectangle())
            .frame(width: 180, height: 220)
            .position(center)
            .onTapGesture {
                cheerUntil = Self.clock() + 0.6
                SoundFX.play(.boop)
                say(["Hej!", "Hihi!", "Bopp!"].randomElement()!)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45, maximumDistance: 14)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("screen")))
                    .onChanged { value in
                        guard case .second(true, let drag) = value else { return }
                        if carryPoint == nil { pickUp(at: CGPoint(x: center.x, y: center.y - 85)) }
                        if let drag { carry(to: CGPoint(x: drag.location.x + camera.x, y: drag.location.y), screenX: drag.location.x) }
                    }
                    .onEnded { value in
                        guard carryPoint != nil else { return }
                        if case .second(true, let drag?) = value {
                            drop(at: CGPoint(x: drag.location.x + camera.x, y: drag.location.y), g: g)
                        } else if let carryPoint {
                            drop(at: carryPoint, g: g)
                        }
                    }
            )
            .disabled(play?.slidePhase(at: t) != nil)
    }

    private func pickUp(at point: CGPoint) {
        leaveWhatItsDoing()
        if let x = fetch?.petX { fetch?.placePet(at: x) }
        fall = nil
        carryPoint = point
        Haptics.thump()
        SoundFX.play(.squeak)
        say(["Wiii! Jag flyger!", "Hoppla!", "Vart ska vi?"].randomElement()!)
    }

    private func carry(to point: CGPoint, screenX: CGFloat) {
        carryPoint = point
        // Carried to the edge of the screen, the park scrolls along.
        if screenX < 130 { camera.camera.pan(by: 16) }
        if screenX > DesignCanvas<EmptyView>.designWidth - 130 { camera.camera.pan(by: -16) }
    }

    /// Let go: it lands on whatever is underneath, or drops onto the grass.
    private func drop(at point: CGPoint, g: ParkGeometry) {
        carryPoint = nil
        guard var game = fetch, var activities = play else { return }
        let feet = CGPoint(x: point.x, y: point.y + 85 + Self.petSize / 2 - Self.feetInset)
        if g.swingArea.contains(feet) || g.swingArea.contains(point) {
            game.placePet(at: Double(g.swingPivots[0].x))
            fetch = game
            onSwing = true
            pushSwing()
            say("Gunga! Puffa mig!")
        } else if g.slideArea.contains(feet), feet.y < g.ground - 80 {
            game.placePet(at: Double(g.slideLadderX))
            fetch = game
            if activities.startSlide(at: Self.clock()) { play = activities }
            say("Upp på rutschkanan!")
        } else if activities.isInPond(Point2(feet.x, feet.y)) || g.pondArea.contains(feet) {
            game.placePet(at: Double(g.pondEdge(near: feet.x)))
            fetch = game
            SoundFX.play(.splash)
            Haptics.thump()
            addFloat("Plask!", at: CGPoint(x: feet.x, y: g.pondCenter.y - 40))
            say(["Plask! Blöta tassar!", "Hihi, kallt vatten!"].randomElement()!)
        } else if g.sandbox.insetBy(dx: -20, dy: -40).contains(feet) {
            game.placePet(at: Double(g.sandboxSpot))
            fetch = game
            buildCastle()
        } else {
            game.placePet(at: Double(feet.x))
            fetch = game
            if feet.y < g.ground - 10 { fall = (feet.y, Self.clock()) }
            say(["Hoppsan!", "Här är fint!", "Tack för skjutsen!"].randomElement()!)
        }
    }

    private func tap(_ point: CGPoint, g: ParkGeometry) {
        guard var game = fetch, var activities = play else { return }
        let now = Self.clock()
        let p = Point2(point.x, point.y)
        if game.tryCatch(at: p, at: now) {
            fetch = game
            yourCatch(at: point, streak: game.streak)
            return
        }
        let friendFrame = CGRect(x: game.friendX - Self.friendSize / 2, y: game.layout.groundY - Self.friendSize - 30, width: Self.friendSize, height: Self.friendSize + 40)
        if friendFrame.insetBy(dx: -20, dy: -20).contains(point) {
            playWithFriend()
            return
        }
        if let index = activities.butterfly(near: p, at: now) {
            leaveWhatItsDoing()
            activities.chase(index)
            play = activities
            say(["En fjäril!", "Vänta, fjärilen!", "Jag ska fånga dig!"].randomElement()!)
            return
        }
        if g.swingArea.contains(point) {
            if onSwing {
                pushSwing()
            } else {
                head(to: .swing, x: g.swingPivots[0].x, saying: "Gunga! Gunga!")
            }
            return
        }
        if g.slideArea.contains(point) {
            head(to: .slide, x: g.slideLadderX, saying: "Rutschkanan!")
            return
        }
        if g.sandbox.insetBy(dx: -10, dy: -30).contains(point) {
            if goal == nil, abs(game.petX - g.sandboxSpot) < 12, !onSwing {
                buildCastle()
            } else {
                head(to: .sandbox, x: g.sandboxSpot, saying: "Vi bygger ett slott!")
            }
            return
        }
        if activities.isInPond(p) || g.pondArea.contains(point) {
            let onWater = activities.isInPond(p) ? p : Point2(g.pondCenter.x + (point.x - g.pondCenter.x) * 0.8, g.pondCenter.y)
            if activities.toss(at: onWater) {
                play = activities
                SoundFX.play(.pop)
                addFloat("•", at: CGPoint(x: onWater.x, y: onWater.y - 20))
            }
            if abs(game.petX - g.pondEdge(near: point.x)) > 40 {
                head(to: .pond(point.x), x: g.pondEdge(near: point.x), saying: "Ankor!")
            }
            return
        }
        if g.kiosk.insetBy(dx: -20, dy: -20).contains(point) {
            head(to: .kiosk, x: g.kioskSpot, saying: "Glass?!")
            return
        }
        if self.game == .fetch, point.x > 300, point.x < ParkGeometry.meadowEnd - 40, point.y > 180, point.y < game.layout.groundY + 60 {
            leaveWhatItsDoing()
            throwBall(towardX: point.x)
            return
        }
        // Anywhere else on the grass: your sötis trots over to have a look.
        if point.y > g.ground - 260 {
            leaveWhatItsDoing()
            game.walkPet(to: point.x)
            fetch = game
        }
    }

    /// Gets off the swing and stops chasing, so it can go and do something else.
    private func leaveWhatItsDoing() {
        if onSwing, var game = fetch {
            onSwing = false
            game.placePet(at: Double(lastGeometry.swingPivots[0].x))
            fetch = game
        }
        play?.stopChasing()
        goal = nil
    }

    private func head(to target: ParkGoal, x: CGFloat, saying line: String) {
        guard play?.slidePhase(at: t) == nil else { return }
        leaveWhatItsDoing()
        goal = target
        fetch?.walkPet(to: Double(x))
        say(line)
        SoundFX.play(.boop)
    }

    private func arrive(at target: ParkGoal) {
        goal = nil
        switch target {
        case .swing:
            onSwing = true
            pushSwing()
            say("Puffa mig! Tryck på gungan!")
        case .slide:
            if play?.startSlide(at: Self.clock()) == true {
                say("Wiiiii!")
                SoundFX.play(.giggle)
            }
        case .sandbox:
            buildCastle()
        case .kiosk:
            buyIceCream()
        case .pond:
            say(["Hej, ankorna!", "Kvack kvack!", "Mata dem!"].randomElement()!)
        }
    }

    // MARK: Playground

    private func pushSwing() {
        guard var activities = play else { return }
        let counted = activities.push(at: Self.clock())
        play = activities
        SoundFX.play(.boing)
        Haptics.soft()
        guard counted else { return }
        countedPushes += 1
        store.perform { state, now in _ = state.pet?.play(at: now, fun: 2, energy: 0.5) }
        if countedPushes.isMultiple(of: 5) {
            reward(1, at: Point2(Double(lastGeometry.swingPivots[0].x), Double(lastGeometry.ground - 220)))
            say(["Högre! Högre!", "Jag flyger!", "Wiii!"].randomElement()!)
        }
    }

    private func finishedSlide(at point: CGPoint) {
        Haptics.thump()
        SoundFX.play(.bounce)
        store.perform { state, now in _ = state.pet?.play(at: now, fun: 6, energy: 2) }
        reward(1, at: Point2(point.x, point.y))
        say(["Igen! Igen!", "Det gick så fort!"].randomElement()!)
        cheerUntil = Self.clock() + 0.8
    }

    private func buildCastle() {
        guard var activities = play else { return }
        let result = activities.dig()
        play = activities
        let top = CGPoint(x: lastGeometry.sandbox.midX, y: lastGeometry.sandbox.minY - 60)
        switch result {
        case .built(let stage):
            SoundFX.play(.chomp)
            say(["Ett torn!", "Lite till…", "Snart klart!"][min(stage - 1, 2)])
        case .finished:
            Haptics.success()
            SoundFX.play(.coin)
            reward(2, at: Point2(top.x, top.y))
            store.perform { state, now in _ = state.pet?.play(at: now, fun: 8, energy: 2) }
            say("Ett riktigt sandslott!")
            cheerUntil = Self.clock() + 1
        case .knockedDown:
            SoundFX.play(.bounce)
            Haptics.thump()
            say("BOM! Hihi, vi bygger ett nytt!")
        }
    }

    // MARK: Pond

    private func duckAte(total: Int) {
        SoundFX.play(.squeak)
        addFloat("Kvack!", at: CGPoint(x: lastGeometry.pondCenter.x, y: lastGeometry.pondCenter.y - 70))
        if total.isMultiple(of: 3) {
            reward(1, at: Point2(Double(lastGeometry.pondCenter.x), Double(lastGeometry.pondCenter.y - 110)))
            store.perform { state, now in _ = state.pet?.play(at: now, fun: 4, energy: 0) }
            say("Ankorna är mätta och glada!")
            cheerUntil = Self.clock() + 0.8
        }
    }

    private func caughtButterfly(at point: Point2) {
        Haptics.success()
        SoundFX.play(.pop)
        cheerUntil = Self.clock() + 0.9
        reward(1, at: point)
        store.perform { state, now in _ = state.pet?.play(at: now, fun: 5, energy: 1) }
        say(["Tog dig! Hej då, fjärilen!", "Fångad! Flyg nu!"].randomElement()!)
    }

    private func buyIceCream() {
        let price = Catalog.item("icecream")?.price ?? 0
        let result = store.perform { state, now in state.buyAndEat("icecream", now: now) }
        guard result != nil else {
            say("En glass kostar \(price) mynt. Vi sparar till nästa gång!")
            return
        }
        SoundFX.play(.chomp)
        Haptics.success()
        iceCreamUntil = Self.clock() + 3
        cheerUntil = Self.clock() + 1
        addFloat("−\(price)", at: CGPoint(x: lastGeometry.kiosk.midX, y: lastGeometry.kiosk.minY + 40))
        addFloat("♥", at: CGPoint(x: fetch.map { CGFloat($0.petX) } ?? 0, y: lastGeometry.ground - 260))
        say(["Mmm, glass!", "Jordgubbsglass! Bästa!"].randomElement()!)
    }

    // MARK: Fetch

    private func throwBall(towardX x: CGFloat) {
        guard var game = fetch, game.throwBall(towardX: x, at: Self.clock()) else { return }
        fetch = game
        SoundFX.play(.boop)
        Haptics.tap()
        say("Jag tar den!")
    }

    private func playWithFriend() {
        guard var game = fetch else { return }
        leaveWhatItsDoing()
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

    /// Mounds all over the park, so exploring pays off: x in park points, y as a fraction of the height.
    /// They sit on the grass behind the path your sötis walks, and high enough that the dock never hides them.
    static let moundSpots: [CGPoint] = [
        CGPoint(x: 300, y: 0.70), CGPoint(x: 640, y: 0.73), CGPoint(x: 1290, y: 0.70),
        CGPoint(x: 2470, y: 0.72), CGPoint(x: 3180, y: 0.68), CGPoint(x: 1000, y: 0.67),
    ]
    static let moundSize = CGSize(width: 120, height: 60)

    private static func makeMounds() -> [Mound] {
        moundSpots.enumerated().map { Mound(id: $0.offset, point: $0.element) }
    }

    private func dig(_ mound: Mound) {
        guard digsLeft > 0, let index = mounds.firstIndex(where: { $0.id == mound.id }) else { return }
        digsLeft -= 1
        let reward = [0, 2, 3, 4, 5, 8].randomElement()!
        mounds[index].reward = reward
        coinsFound += reward
        Haptics.tap()
        SoundFX.play(reward > 0 ? .coin : .boop)
        leaveWhatItsDoing()
        fetch?.walkPet(to: mound.point.x)
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


/// The parts of the park that move: swings, the sandcastle, ducks and crumbs, butterflies.
private struct ParkLiving: View {
    let g: ParkGeometry
    let play: ParkPlay
    let t: Double

    var body: some View {
        Canvas { c, _ in
            drawSwings(c)
            drawCastle(c)
            drawPond(c)
            drawButterflies(c)
        }
        .frame(width: g.size.width, height: g.size.height)
        .allowsHitTesting(false)
    }

    private func drawSwings(_ c: GraphicsContext) {
        for (index, pivot) in g.swingPivots.enumerated() {
            // The empty swing sways a little in the breeze.
            let degrees = index == 0 ? play.swingAngle(at: t) : sin(t * 1.3) * 4
            let angle = degrees * .pi / 180
            let seat = CGPoint(x: pivot.x + sin(angle) * g.ropeLength, y: pivot.y + cos(angle) * g.ropeLength)
            let across = CGPoint(x: cos(angle) * 34, y: -sin(angle) * 34)
            c.line(Color(hex: 0x8B6B5A), width: 4) { p in
                p.move(to: CGPoint(x: pivot.x - 30, y: pivot.y)); p.addLine(to: CGPoint(x: seat.x - across.x, y: seat.y - across.y))
                p.move(to: CGPoint(x: pivot.x + 30, y: pivot.y)); p.addLine(to: CGPoint(x: seat.x + across.x, y: seat.y + across.y))
            }
            c.line(index == 0 ? .coral : .sky, width: 14) { p in
                p.move(to: CGPoint(x: seat.x - across.x * 1.2, y: seat.y - across.y * 1.2))
                p.addLine(to: CGPoint(x: seat.x + across.x * 1.2, y: seat.y + across.y * 1.2))
            }
        }
    }

    private func drawCastle(_ c: GraphicsContext) {
        let box = g.sandbox
        let sand = Color(hex: 0xE8C57E)
        let base = CGPoint(x: box.midX, y: box.midY + 6)
        if play.castle >= 1 { c.box(base.x - 50, base.y - 34, 100, 34, radius: 6, sand) }
        if play.castle >= 2 { c.box(base.x - 54, base.y - 70, 30, 40, radius: 5, sand); c.box(base.x + 24, base.y - 70, 30, 40, radius: 5, sand) }
        if play.castle >= 3 { c.box(base.x - 20, base.y - 92, 40, 62, radius: 6, sand) }
        if play.castle >= 1 {
            c.box(base.x - 10, base.y - 20, 20, 20, radius: 10, Color(hex: 0xB88A4A))
        }
        if play.castle >= ParkPlay.castleStages {
            c.line(.ink, width: 3) { p in p.move(to: CGPoint(x: base.x, y: base.y - 92)); p.addLine(to: CGPoint(x: base.x, y: base.y - 130)) }
            let wave = sin(t * 5) * 4
            c.shape(.coral) { $0.addLines([CGPoint(x: base.x, y: base.y - 130), CGPoint(x: base.x + 30, y: base.y - 120 + wave), CGPoint(x: base.x, y: base.y - 110)]) }
        }
    }

    private func drawPond(_ c: GraphicsContext) {
        for crumb in play.crumbs {
            c.dot(crumb.position.x, crumb.position.y, 5, Color(hex: 0xE0B070))
        }
        for duck in play.ducks {
            let p = duck.position
            let side: CGFloat = duck.facingRight ? 1 : -1
            let bob = sin(t * 3 + Double(duck.id)) * 2
            c.oval(p.x, p.y + 6, 30, 6, Color.skyDeep.opacity(0.35))
            c.oval(p.x, p.y - 4 + bob, 26, 15, .white)
            c.dot(p.x + side * 18, p.y - 20 + bob, 11, .white)
            c.dot(p.x + side * 21, p.y - 23 + bob, 2.5, .ink)
            c.shape(Color(hex: 0xFF9F68)) { $0.addLines([
                CGPoint(x: p.x + side * 27, y: p.y - 21 + bob), CGPoint(x: p.x + side * 38, y: p.y - 17 + bob), CGPoint(x: p.x + side * 27, y: p.y - 14 + bob),
            ]) }
            c.oval(p.x - side * 6, p.y - 6 + bob, 12, 7, Color(hex: 0xEDE6DA))
        }
    }

    private func drawButterflies(_ c: GraphicsContext) {
        let colors: [(Color, Color)] = [(.pink, .lavender), (.butter, .coral), (.sky, .mint)]
        for index in 0..<ParkPlay.butterflyCount where play.isHere(index, at: t) {
            let p = play.butterfly(index, at: t)
            let flap = 0.35 + abs(sin(t * 14 + Double(index))) * 0.65
            let (a, b) = colors[index % colors.count]
            c.oval(p.x - 11 * flap, p.y - 6, 12 * flap, 10, a)
            c.oval(p.x + 11 * flap, p.y - 6, 12 * flap, 10, b)
            c.oval(p.x - 8 * flap, p.y + 6, 8 * flap, 7, b)
            c.oval(p.x + 8 * flap, p.y + 6, 8 * flap, 7, a)
            c.box(p.x - 2, p.y - 12, 4, 22, radius: 2, .ink)
        }
    }
}

/// The still parts of the wide park: sky, hills and trees all the way along, the meadow,
/// the playground's frames and the pond with its flowers and kiosk.
struct ParkBackdrop: View {
    let size: CGSize

    var body: some View {
        Canvas { c, _ in
            let h = size.height
            let w = size.width
            let g = ParkGeometry(size: size)

            c.dot(1040, 150, 64, Color(hex: 0xFFE59A))
            c.dot(1040, 150, 46, .butter)
            for (x, y, s) in [(220.0, 150.0, 1.0), (700, 110, 0.8), (1500, 130, 1.1), (2150, 96, 0.8), (2700, 140, 1.2), (3300, 110, 0.9)] {
                c.oval(x, y, 70 * s, 26 * s, .white); c.oval(x + 40 * s, y - 20 * s, 46 * s, 30 * s, .white); c.oval(x - 40 * s, y - 14 * s, 34 * s, 22 * s, .white)
            }

            // Rolling hills the whole way along.
            c.shape(Color(hex: 0xA8E3B8)) { p in
                p.move(to: CGPoint(x: 0, y: h * 0.5))
                var x: CGFloat = 0
                var up = true
                while x < w {
                    let next = min(w, x + 440)
                    p.addQuadCurve(to: CGPoint(x: next, y: h * (up ? 0.48 : 0.49)), control: CGPoint(x: (x + next) / 2, y: h * (up ? 0.36 : 0.4)))
                    x = next
                    up.toggle()
                }
                p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
            }
            c.shape(Color(hex: 0x8ED6A2)) { p in
                p.move(to: CGPoint(x: 0, y: h * 0.6))
                var x: CGFloat = 0
                while x < w {
                    let next = min(w, x + 600)
                    p.addQuadCurve(to: CGPoint(x: next, y: h * 0.6), control: CGPoint(x: (x + next) / 2, y: h * 0.5))
                    x = next
                }
                p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
            }

            for (x, y, r) in [(140.0, 0.42, 56.0), (1080, 0.47, 62), (870, 0.41, 36), (1270, 0.43, 44), (2280, 0.44, 52), (3040, 0.42, 58), (3560, 0.45, 40)] {
                let base = h * y
                c.box(x - 8, base + 30, 16, r * 1.4, radius: 8, .poopLight)
                c.dot(x, base, r, .leafDeep)
                c.dot(x - r * 0.4, base - r * 0.25, r * 0.28, .leaf)
            }

            // The meadow's little pond and bench.
            c.oval(160, h * 0.86, 150, 36, .sky)
            c.oval(140, h * 0.855, 90, 16, Color(hex: 0xBFE6FF))
            c.box(780, h * 0.64, 160, 16, radius: 8, .wood)
            c.box(780, h * 0.64 + 24, 160, 16, radius: 8, .wood)
            c.box(792, h * 0.64 + 40, 12, 40, radius: 6, .woodDeep)
            c.box(916, h * 0.64 + 40, 12, 40, radius: 6, .woodDeep)

            for (x, y, color) in [(80.0, 0.7, Color.pink), (420, 0.73, .lavender), (1120, 0.74, .pink), (760, 0.95, .white), (120, 0.97, .lavender),
                                  (1350, 0.92, .butter), (1760, 0.95, .pink), (2050, 0.9, .white), (2600, 0.93, .lavender), (3000, 0.96, .pink), (3480, 0.92, .butter)] {
                c.dot(x, h * y, 8, color)
                c.dot(x, h * y, 3, .butter)
            }

            drawPlayground(c, g: g)
            drawPondSide(c, g: g)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func drawPlayground(_ c: GraphicsContext, g: ParkGeometry) {
        let ground = g.ground
        // Swing frame: two A-frames and a bar.
        let barY = g.swingPivots[0].y
        let left = g.swingPivots[0].x - 100
        let right = g.swingPivots[1].x + 100
        c.line(.coralDeep, width: 12) { p in
            for x in [left, right] {
                p.move(to: CGPoint(x: x - 40, y: ground)); p.addLine(to: CGPoint(x: x, y: barY))
                p.move(to: CGPoint(x: x + 40, y: ground)); p.addLine(to: CGPoint(x: x, y: barY))
            }
        }
        c.box(left - 14, barY - 10, right - left + 28, 20, radius: 10, .butter)

        // Slide: ladder, platform and a long coral ramp.
        let ladder = g.slideLadderX
        let top = g.slideTopY
        c.line(.skyDeep, width: 9) { p in
            p.move(to: CGPoint(x: ladder - 24, y: ground)); p.addLine(to: CGPoint(x: ladder - 24, y: top - 50))
            p.move(to: CGPoint(x: ladder + 24, y: ground)); p.addLine(to: CGPoint(x: ladder + 24, y: top - 50))
        }
        c.line(.sky, width: 7) { p in
            var y = ground - 30
            while y > top {
                p.move(to: CGPoint(x: ladder - 24, y: y)); p.addLine(to: CGPoint(x: ladder + 24, y: y))
                y -= 36
            }
        }
        c.box(ladder - 34, top, 140, 18, radius: 8, .butter)
        c.box(ladder + 92, top + 16, 12, ground - top - 16, radius: 6, .butterDeep)
        let ramp = Path { p in
            p.move(to: g.rampStart)
            p.addLine(to: CGPoint(x: g.rampEnd.x - 60, y: g.rampEnd.y - 26))
            p.addQuadCurve(to: CGPoint(x: g.rampEnd.x + 50, y: g.rampEnd.y), control: CGPoint(x: g.rampEnd.x - 10, y: g.rampEnd.y))
        }
        c.outline(ramp, .coralDeep, width: 40)
        c.outline(ramp, .coral, width: 28)
        c.outline(ramp.offsetBy(dx: 0, dy: -4), .white.opacity(0.5), width: 4)

        // Sandbox with a bucket and spade.
        let box = g.sandbox
        c.box(box.minX - 8, box.minY - 8, box.width + 16, box.height + 16, radius: 16, .wood)
        c.box(box.minX, box.minY, box.width, box.height, radius: 12, Color(hex: 0xF5DFA8))
        c.box(box.maxX - 40, box.minY + 10, 26, 28, radius: 6, .sky)
        c.line(.coral, width: 5) { p in p.move(to: CGPoint(x: box.minX + 20, y: box.maxY - 10)); p.addLine(to: CGPoint(x: box.minX + 44, y: box.minY + 14)) }
    }

    private func drawPondSide(_ c: GraphicsContext, g: ParkGeometry) {
        let pond = g.pondCenter
        let r = g.pondRadii
        c.oval(pond.x, pond.y, r.width + 14, r.height + 10, Color(hex: 0x7BC98A))
        c.oval(pond.x, pond.y, r.width, r.height, .sky)
        c.oval(pond.x - 60, pond.y - 8, r.width * 0.6, r.height * 0.4, Color(hex: 0xBFE6FF))
        for (dx, dy) in [(-210.0, 10.0), (190, -6), (90, 18)] {
            c.oval(pond.x + dx, pond.y + dy, 22, 8, .leaf)
        }
        for x in [pond.x - r.width - 6, pond.x + r.width + 2] {
            c.line(.leafDeep, width: 4) { p in
                for k in 0..<3 {
                    let rx = x + CGFloat(k) * 8
                    p.move(to: CGPoint(x: rx, y: pond.y + 10)); p.addLine(to: CGPoint(x: rx + 4, y: pond.y - 50 - CGFloat(k) * 8))
                }
            }
            c.oval(x + 12, pond.y - 52, 4, 12, Color(hex: 0x8B6B5A))
        }

        // Flowerbed the butterflies like.
        let bed = g.flowers
        c.oval(bed.x, bed.y, 190, 26, Color(hex: 0x7BC98A))
        for (index, dx) in stride(from: -160.0, through: 160, by: 40).enumerated() {
            let color = [Color.pink, .butter, .lavender, .coral, .sky][index % 5]
            let height = 26 + Double(index % 3) * 10
            c.line(.leafDeep, width: 3) { p in p.move(to: CGPoint(x: bed.x + dx, y: bed.y)); p.addLine(to: CGPoint(x: bed.x + dx, y: bed.y - height)) }
            for angle in stride(from: 0.0, to: 360, by: 72) {
                let a = angle * .pi / 180
                c.dot(bed.x + dx + cos(a) * 7, bed.y - height + sin(a) * 7, 6, color)
            }
            c.dot(bed.x + dx, bed.y - height, 4, .white)
        }

        // Ice-cream kiosk: a striped cart under a parasol.
        let k = g.kiosk
        c.box(k.minX + k.width / 2 - 4, k.minY + 40, 8, 120, radius: 4, .inkSoft)
        c.shape(.coral) { p in
            p.move(to: CGPoint(x: k.minX - 20, y: k.minY + 60))
            p.addQuadCurve(to: CGPoint(x: k.maxX + 20, y: k.minY + 60), control: CGPoint(x: k.midX, y: k.minY - 30))
            p.closeSubpath()
        }
        for index in 0..<3 {
            let x = k.minX + CGFloat(index) * 70 + 10
            c.shape(.white) { $0.addLines([CGPoint(x: k.midX, y: k.minY + 10), CGPoint(x: x, y: k.minY + 60), CGPoint(x: x + 24, y: k.minY + 60)]) }
        }
        c.box(k.minX, k.minY + 150, k.width, 90, radius: 14, .white)
        for index in 0..<4 {
            c.box(k.minX + 8 + CGFloat(index) * 38, k.minY + 158, 18, 74, radius: 6, .pinkLight)
        }
        c.box(k.minX - 6, k.minY + 140, k.width + 12, 16, radius: 8, .mint)
        c.dot(k.minX + 30, k.maxY - 4, 14, .inkSoft)
        c.dot(k.maxX - 30, k.maxY - 4, 14, .inkSoft)
        // A big cone on top as a sign.
        let cone = CGPoint(x: k.midX, y: k.minY + 106)
        c.shape(Color(hex: 0xE5B585)) { $0.addLines([CGPoint(x: cone.x - 18, y: cone.y), CGPoint(x: cone.x + 18, y: cone.y), CGPoint(x: cone.x, y: cone.y + 34)]) }
        c.dot(cone.x, cone.y - 6, 20, .pink)
        c.dot(cone.x - 4, cone.y - 22, 14, Color(hex: 0xFFF3E3))
    }
}
