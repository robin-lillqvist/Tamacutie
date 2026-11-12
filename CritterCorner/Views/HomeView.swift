import CritterKit
import SwiftUI

private enum Toy: String {
    case ball, bubbles
}

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    // The critter's body in the room.
    @State private var critterX: CGFloat = 640
    @State private var facingRight = true
    @State private var walking = false
    @State private var hop = false
    @State private var lean: Double = 0
    @State private var wiggle = false
    @State private var moodOverride: (mood: Mood, until: Date)?
    @State private var lookPoint: CGPoint?
    @State private var lastLayout = RoomLayout(size: CGSize(width: 1194, height: 834))

    // Interaction state.
    @State private var bubble: String?
    @State private var bubbleToken = UUID()
    @State private var bubbleShownAt = Date.distantPast
    @State private var scribbleTurns: [Date] = []
    @State private var scribbleDirection: CGFloat = 0
    @State private var hearts: [HeartBurst] = []
    @State private var floating: [FloatingText] = []
    @State private var sparkles: [FloatingText] = []
    @State private var strokeDistance: CGFloat = 0
    @State private var lastDragPoint: CGPoint?
    @State private var petting = false
    @State private var tickleTaps: [Date] = []
    @State private var showFridge = false
    @State private var showAbout = false
    @State private var draggedFood: String?
    @State private var foodPoint: CGPoint = .zero
    @State private var chomping = false
    @State private var busyUntil = Date.distantPast

    // Its own life, when left alone.
    @State private var lastTouch = Date()
    @State private var solo: SoloActivity?
    /// 0 on the floor, 1 up on the window sill.
    @State private var perch: CGFloat = 0

    // Playtime.
    @State private var toy: Toy?
    @State private var playground: Playground?
    @State private var grabbingBall = false

    // The room is wider than the screen; this is the part you see.
    @State private var camera = WorldCamera(worldWidth: DesignCanvas<EmptyView>.designWidth * Rules.roomScreens, viewportWidth: DesignCanvas<EmptyView>.designWidth)
    @State private var cameraX: CGFloat = 0

    // The play corner.
    /// While set, the critter stands here (feet at y + 150): on the ladder, the slide or the cushion.
    @State private var stagePoint: CGPoint?
    @State private var stageBusy = false
    @State private var cushionSquash = false
    @State private var struckBar: Int?
    @State private var notesPlayed = 0
    /// The walk in progress, so the camera can follow where the critter is, not where it's headed.
    @State private var stroll: (from: CGFloat, to: CGFloat, start: Date, duration: Double)?

    var body: some View {
        DesignCanvas(background: .pinkLight) { size in
            if let pet = store.pet {
                let world = RoomLayout(size: CGSize(width: size.width * Rules.roomScreens, height: size.height))
                ZStack(alignment: .topLeading) {
                    room(pet: pet, layout: world)
                        .offset(x: -cameraX)
                    hud(pet: pet, layout: world, screen: size)
                    EdgeArrows(cameraX: cameraX, worldWidth: world.size.width, size: size, y: world.floorTop + 80) { right in
                        camera.camera.page(right: right)
                        lastTouch = Date()
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .clipped()
                .coordinateSpace(.named("screen"))
                .onAppear { camera.resize(worldWidth: world.size.width, viewportWidth: size.width) }
                .onChange(of: size) { _, _ in camera.resize(worldWidth: world.size.width, viewportWidth: size.width) }
            }
        }
        .task {
            await camera.run(follow: { followTarget() }, publish: { cameraX = $0 })
        }
        .sheet(isPresented: $showAbout) {
            if let pet = store.pet { AboutPetView(pet: pet, now: store.now) }
        }
        .task(id: toy == nil) {
            if toy == nil { await wanderLoop() } else { await playLoop() }
        }
    }

    // MARK: Layout

    private func room(pet: Pet, layout: RoomLayout) -> some View {
        let size = layout.size
        return ZStack(alignment: .topLeading) {
            RoomBackdrop(size: size, waterLevel: pet.needs.thirst / 100, foodInBowl: pet.needs.hunger > 50, time: store.now)

            // Touching the empty room makes the critter look at your finger, and blows bubbles in bubble mode.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: size.width, height: size.height)
                .gesture(roomTouch(layout: layout))

            ForEach(store.state.room) { decor in
                PlacedDecorView(decor: decor, layout: layout)
            }
            .allowsHitTesting(false)

            ForEach(pet.poops) { poop in
                let point = layout.point(for: poop)
                Button {
                    scoop(poop, at: point)
                } label: {
                    VStack(spacing: -6) {
                        StinkLines()
                        PoopView()
                    }
                    .frame(width: 90, height: 100)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SquishyButtonStyle())
                .position(point)
                .accessibilityLabel("Bajs. Tryck för att plocka upp det.")
            }

            if layout.hasPlayCorner {
                playCorner(layout: layout)
            }

            if let playground {
                ForEach(playground.bubbles) { item in
                    SoapBubble(phase: item.phase)
                        .frame(width: 70, height: 70)
                        .position(x: item.position.x, y: item.position.y)
                        .allowsHitTesting(false)
                }
            }


            critter(pet: pet, layout: layout)

            if solo == .reading, perch > 0.9, !pet.isAsleep {
                ReadingBook()
                    .frame(width: 80, height: 52)
                    .position(bookPoint(layout: layout))
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }

            if let playground, toy == .ball || solo == .playingBall || playground.ballState != .resting {
                BallView()
                    .frame(width: 60, height: 60)
                    .scaleEffect(grabbingBall ? 1.2 : 1)
                    .contentShape(Circle().inset(by: -30))
                    .position(x: playground.ball.x, y: playground.ball.y)
                    .gesture(ballGesture)
                    .accessibilityIdentifier("ball")
                    .accessibilityLabel("Boll. Svep för att kasta den.")
            }

            if pet.isAsleep {
                Color.ink.opacity(0.42)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            }
            if pet.isAsleep {
                ZzzView()
                    .position(x: RoomLayout.bedX + 120, y: layout.floorTop - 170)
            }

            if let draggedFood {
                ItemArt(id: draggedFood)
                    .frame(width: 90, height: 90)
                    .scaleEffect(1.15)
                    .position(foodPoint)
                    .allowsHitTesting(false)
            }

            HeartLayer(hearts: hearts)
            FloatingTextLayer(items: floating)
            SparkleLayer(items: sparkles)

            if let bubble {
                let center = critterCenter(pet: pet, layout: layout)
                let scale = critterScale(pet)
                let onLeft = center.x - cameraX < 820
                SpeechBubble(text: bubble, tailOnLeft: onLeft)
                    .position(x: onLeft ? center.x + 210 : center.x - 210, y: center.y + 150 - 320 * scale)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(.named("room"))
        .onAppear { lastLayout = layout }
        .onChange(of: layout.size) { _, _ in lastLayout = layout }
    }

    private func critterCenter(pet: Pet, layout: RoomLayout) -> CGPoint {
        if pet.isAsleep { return CGPoint(x: RoomLayout.bedX, y: layout.floorTop - 40) }
        if let stagePoint { return stagePoint }
        if let playground {
            return CGPoint(x: playground.critterX, y: layout.petCenter.y - playground.hop)
        }
        // The frame's bottom edge is its feet: up on the sill, the feet rest on the sill.
        let seatY = layout.critterCenter(feetAt: CGPoint(x: critterX, y: layout.windowSillY), scale: 0.55).y
        return CGPoint(x: critterX, y: layout.petCenter.y + (seatY - layout.petCenter.y) * perch)
    }

    /// Smaller up in the window, since it sits further back in the room.
    private func critterScale(_ pet: Pet) -> CGFloat {
        pet.isAsleep ? 0.75 : 1 - 0.45 * perch
    }

    private func bookPoint(layout: RoomLayout) -> CGPoint {
        CGPoint(x: critterX, y: layout.windowSillY - 38)
    }

    private func displayMood(_ pet: Pet, center: CGPoint) -> Mood {
        let base = pet.expression(at: store.now)
        if [.asleep, .dead, .sick, .furious].contains(base) { return base }
        if let moodOverride, moodOverride.until > Date() { return moodOverride.mood }
        if draggedFood != nil, hypot(foodPoint.x - center.x, foodPoint.y - center.y) < 320 { return .hungry }
        if (chomping || (petting && !pet.isIgnoring(at: store.now))) && base != .ignoring { return .happy }
        if let playground, playground.task == .carryingBall || playground.isWalking { return .excited }
        return base
    }

    private func critter(pet: Pet, layout: RoomLayout) -> some View {
        let center = critterCenter(pet: pet, layout: layout)
        return LiveCritterView(
            genome: pet.genome,
            expression: displayMood(pet, center: center),
            weight: pet.weight,
            walking: playground?.isWalking ?? walking,
            facingRight: playground?.facingRight ?? facingRight,
            look: lookVector(from: center),
            lean: lean,
            wiggle: wiggle,
            blissful: (petting && !pet.isIgnoring(at: store.now)) || chomping || wiggle,
            shine: pet.shine(at: store.now),
            condition: pet.condition(at: store.now),
            coat: .everyday(for: pet),
            style: pet.appearance
        )
        .frame(width: 300, height: 300)
        .scaleEffect(critterScale(pet), anchor: .bottom)
        .offset(y: hop ? -46 : 0)
        .contentShape(Circle().inset(by: 30))
        .gesture(petting(center: center))
        .simultaneousGesture(TapGesture(count: 2).onEnded { tickle() })
        .position(center)
        .accessibilityElement()
        .accessibilityIdentifier("critter")
        .accessibilityValue([displayMood(pet, center: center).rawValue, solo.map { "solo-\($0.rawValue)" }].compactMap { $0 }.joined(separator: " "))
        .accessibilityLabel("\(pet.name). Stryk för att klappa. Dubbeltryck eller gnid snabbt fram och tillbaka för att kittla.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { stroke(at: center) }
        .accessibilityAction(named: "Kittla") { tickle() }
    }

    private func lookVector(from center: CGPoint) -> CGVector {
        var target: CGPoint?
        if draggedFood != nil {
            target = foodPoint
        } else if solo == .reading, perch > 0.9 {
            target = bookPoint(layout: lastLayout)
        } else if solo == .stargazing, perch > 0.9 {
            target = CGPoint(x: center.x + 60, y: lastLayout.windowSillY - 260)
        } else if let lookPoint {
            target = lookPoint
        } else if let playground {
            if toy == .ball || playground.ballState != .resting {
                target = CGPoint(x: playground.ball.x, y: playground.ball.y)
            } else if let first = playground.bubbles.first {
                target = CGPoint(x: first.position.x, y: first.position.y)
            }
        }
        guard let target else { return .zero }
        let eye = CGPoint(x: center.x, y: center.y - 30)
        return CGVector(dx: max(-1, min(1, (target.x - eye.x) / 260)), dy: max(-1, min(1, (target.y - eye.y) / 260)))
    }

    private func hud(pet: Pet, layout: RoomLayout, screen size: CGSize) -> some View {
        return ZStack(alignment: .topLeading) {
            Button { showAbout = true } label: {
                HStack(spacing: 14) {
                    CritterView(genome: pet.genome, expression: .happy, weight: pet.weight, style: pet.appearance)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color(hex: pet.genome.palette.stage)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pet.name).font(.cute(22, .bold))
                        Text("Dag \(pet.ageInDays(at: store.now) + 1) · \(pet.weightStage.title)")
                            .font(.cute(15, .medium))
                            .foregroundStyle(pet.weightStage.isDangerous ? Color.coralDeep : Color.inkSoft)
                    }
                }
                .foregroundStyle(Color.ink)
                .padding(12)
                .padding(.trailing, 10)
                .card()
            }
            .buttonStyle(SquishyButtonStyle())
            .position(x: 24 + 160, y: 24 + 38)

            // Menus stay out of the sötis's way: a slim strip on the left, pills along the top,
            // the fridge under the top bar and the dock at the bottom.
            NeedsStrip(pet: pet)
                .fixedSize()
                .position(x: 24 + 38, y: 116 + NeedsStrip.height / 2)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("needs")

            HStack(spacing: 12) {
                if pet.isSick {
                    Button { giveMedicine() } label: {
                        Label("Ge medicin", systemImage: "cross.case.fill")
                            .font(.cute(20, .bold))
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 18)
                            .frame(height: 58)
                            .card(fill: .mintLight, radius: 29)
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
                if store.state.piggyBank >= 1 {
                    Button {
                        let amount = store.perform { state, _ in state.collectPiggyBank() }
                        Haptics.success()
                        toaster.show("\(pet.pronounName)s spargris: +\(amount) mynt!")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.bank.building.fill")
                            Text("+\(Int(store.state.piggyBank))")
                        }
                        .font(.cute(20, .bold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 58)
                        .card(fill: .butterLight, radius: 29)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel("Ta mynten från spargrisen")
                }
                ClockPill(now: store.now)
                CoinPill(coins: store.state.coins)
            }
            .frame(width: size.width - 48, alignment: .trailing)
            .position(x: size.width / 2, y: 24 + 32)

            if showFridge, toy == nil {
                FridgeTray(onFeed: { feed($0) }, onShop: { navigate(.market) }, onDrag: { id, point, ended in
                    dragFood(id, to: point, ended: ended, layout: layout)
                })
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fridge-tray")
                .position(x: size.width / 2, y: 104 + 84)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let toy, let playground {
                PlayScore(toy: toy, fetches: playground.fetches, pops: playground.pops)
                    .position(x: size.width / 2 - 40, y: 24 + 32)
            }

            Group {
                if toy != nil {
                    playDock
                } else {
                    dock(pet: pet, layout: layout)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dock")
            .position(x: size.width / 2, y: size.height - 72)
        }
    }

    private func dock(pet: Pet, layout: RoomLayout) -> some View {
        Dock {
            DockButton(title: "Mata", systemName: "fork.knife", fill: .peachLight, highlighted: showFridge, nudge: pet.needs.hunger < 25) {
                noteTouch()
                withAnimation(.spring) { showFridge.toggle() }
            }
            DockButton(title: "Vatten", systemName: "drop.fill", fill: .skyLight, nudge: pet.needs.thirst < 25) { refillWater() }
            DockButton(title: "Leka", systemName: "tennisball.fill", fill: .butterLight, nudge: pet.needs.fun < 25) { startPlay(.ball, layout: layout) }
            DockButton(title: pet.isAsleep ? "Väck" : "Sova", systemName: pet.isAsleep ? "sun.max.fill" : "moon.zzz.fill", fill: Color(hex: 0xECE4FF), nudge: pet.isAsleep || pet.needs.energy < 20, bouncy: pet.isAsleep) { toggleSleep() }
            DockButton(title: "Bada", systemName: "bathtub.fill", fill: .mintLight, nudge: pet.needs.hygiene < 25) { goOut(.bath) }
            DockButton(title: "Parken", systemName: "tree.fill", fill: Color(hex: 0xE3F7DC)) { goOut(.park) }
            DockButton(title: "Handla", systemName: "basket.fill", fill: .pinkLight) { navigate(.market) }
            DockButton(title: "Inred", systemName: "sofa.fill", fill: .lavenderLight) { navigate(.decor) }
            DockButton(title: "Minnen", systemName: "heart.text.square.fill", fill: Color(hex: 0xF7F2FF)) { navigate(.memoriam) }
        }
    }

    private var playDock: some View {
        Dock {
            DockButton(title: "Boll", systemName: "tennisball.fill", fill: .butterLight, highlighted: toy == .ball, width: 110) {
                switchToy(.ball)
            }
            DockButton(title: "Bubblor", systemName: "bubbles.and.sparkles.fill", fill: .skyLight, highlighted: toy == .bubbles, width: 110) {
                switchToy(.bubbles)
            }
            DockButton(title: "Klar", systemName: "checkmark.circle.fill", fill: .mintLight, width: 110) { stopPlay() }
        }
    }

    // MARK: Wandering

    private var leftAlone: Bool {
        toy == nil && Date() > busyUntil && !petting && draggedFood == nil && !showFridge
    }

    private func wanderLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 4...8)))
            guard !Task.isCancelled, toy == nil, let pet = store.pet, pet.isAlive, !pet.isAsleep else { continue }
            guard leftAlone else { continue }
            switch pet.temper(at: store.now) {
            case .furious:
                await rage()
                continue
            case .upset:
                await sulk()
                continue
            case .grumpy, .calm:
                break
            }
            let idle = Date().timeIntervalSince(lastTouch)
            if Int.random(in: 0..<5) < 3,
               let activity = SoloLife.pick(for: pet, at: store.now, idle: idle, phase: DayPhase(date: store.now), roll: Double.random(in: 0..<1)) {
                await live(activity)
                continue
            }
            if pet.isIgnoring(at: store.now) {
                await walk(to: critterX < 640 ? 980 : 420)
                continue
            }
            if pet.needs.hunger < 35 {
                await walk(to: 860)
                say("Finns det nån mat?")
            } else if pet.needs.thirst < 35 {
                await walk(to: 980)
                say("Så törstig…")
            } else if pet.needs.energy < 25 {
                await walk(to: RoomLayout.bedX + 60)
                say("Gäääsp…")
            } else if pet.needs.fun < 30, Bool.random() {
                say(["Lek med mig!", "Jag har så tråkigt…", "Boll? Boll!"].randomElement()!)
            } else if Int.random(in: 0..<3) == 0 {
                await lookAround()
            } else {
                await walk(to: CGFloat.random(in: 420...(lastLayout.size.width - 300)))
                if Int.random(in: 0..<4) == 0 {
                    say(["La la la~", "Hmm hmm~", "*sniff sniff*", "Vilken fin dag!", "♪ ♫"].randomElement()!)
                }
            }
        }
    }

    // MARK: Temper

    /// Furious: stomps around the room, steaming.
    private func rage() async {
        say(["GRRRR!", "ARGH!!", "Jag är SÅ arg!", "Lämna mig ifred!!"].randomElement()!)
        Haptics.thump()
        for _ in 0..<2 {
            await walk(to: min(max(critterX + CGFloat.random(in: -420...420), 380), lastLayout.size.width - 300), speed: 330)
            guard leftAlone else { return }
            await stompHop()
        }
    }

    /// Upset: shuffles off to a corner and sniffles.
    private func sulk() async {
        await walk(to: critterX < 640 ? 400 : 900, speed: 80)
        if Bool.random() {
            say(["Snyft…", "Ingen lyssnar på mig…", "Jag vill bara vara ifred…"].randomElement()!, chatty: true)
        }
    }

    private func stompHop() async {
        withAnimation(.spring(duration: 0.15)) { hop = true }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(duration: 0.2, bounce: 0.2)) { hop = false }
        Haptics.thump()
        SoundFX.play(.bounce)
        try? await Task.sleep(for: .milliseconds(200))
    }

    /// Reacts to being bothered while it wants to be left alone. `before` is how it felt before the touch.
    private func grumble(before: Temper) {
        guard let pet = store.pet else { return }
        let temper = pet.temper(at: store.now)
        if temper > before {
            switch temper {
            case .furious:
                say("GRRRAAAH!! NU BLIR JAG ARG PÅ RIKTIGT!!")
                Task {
                    await stompHop()
                    await stompHop()
                }
            case .upset:
                Haptics.soft()
                say("Snyft… du lyssnar ju inte på mig…")
            case .grumpy, .calm:
                break
            }
            return
        }
        switch temper {
        case .furious:
            say(["GRRRR!", "SLUTA!!", "ARGH!", "Grrr… LÅT MIG VARA!"].randomElement()!, chatty: true)
            Haptics.thump()
        case .upset where pet.annoyanceLevel >= Rules.furyWarningAt:
            say("Sluta… snart blir jag riktigt arg!", chatty: true)
        case .upset:
            say(["Snyft… sluta…", "Varför lyssnar du inte?", "Snälla, låt mig vara…"].randomElement()!, chatty: true)
        case .grumpy:
            say(["Hmpf. Sen.", "Inte nu…", "Jag vill vara ifred!"].randomElement()!, chatty: true)
            facingRight.toggle()
        case .calm:
            say("Tack, men jag vill vara ifred en liten stund.", chatty: true)
        }
    }

    // MARK: A life of its own

    /// Any touch from the player: it notices you and stops what it was doing on its own.
    private func noteTouch() {
        lastTouch = Date()
        if solo != nil { endSolo() }
    }

    private func endSolo() {
        if solo == .playingBall, toy == nil, let playground {
            critterX = playground.critterX
            facingRight = playground.facingRight
            withAnimation(.spring) { self.playground = nil }
        }
        if solo == .dancing {
            moodOverride = nil
            withAnimation(.spring) { lean = 0 }
        }
        solo = nil
        lookPoint = nil
        if stageBusy, stagePoint != nil { endStage() }
        if perch > 0 { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { perch = 0 } }
    }

    private func stillDoing(_ activity: SoloActivity) -> Bool {
        solo == activity && !Task.isCancelled && store.pet?.isAsleep == false && store.pet?.isAlive == true
    }

    /// Waits, checking that nobody interrupted. False if it was interrupted.
    private func linger(_ seconds: Double, _ activity: SoloActivity) async -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            guard stillDoing(activity) else { return false }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return stillDoing(activity)
    }

    private func live(_ activity: SoloActivity) async {
        solo = activity
        switch activity {
        case .reading, .stargazing: await sitInWindow(activity)
        case .dancing: await dance()
        case .playingBall: await playBallAlone()
        case .watchingFish: await watchFish()
        case .sliding: await slide(alone: true)
        case .bouncing: await bounce(alone: true)
        case .makingMusic: await playXylophoneAlone()
        }
        if solo == activity { endSolo() }
    }

    private func sitInWindow(_ activity: SoloActivity) async {
        let reading = activity == .reading
        await walk(to: RoomLayout.windowSeatX)
        guard stillDoing(activity) else { return }
        facingRight = true
        SoundFX.play(.boop)
        withAnimation(.spring(duration: 0.55, bounce: 0.35)) { perch = 1 }
        guard await linger(1.2, activity) else { return }
        say(reading ? ["Dags för en bok!", "Var var jag nu…", "Läsdags!"].randomElement()! : ["Vad många stjärnor!", "Hej, månen!"].randomElement()!)
        let lines = reading
            ? ["Hmm, spännande…", "Oj! En drake!", "*bläddrar*", "Bara ett kapitel till…", "Hihi, vad roligt!"]
            : ["Ett stjärnfall!", "Så mysigt…", "Gäsp… vad fint det är."]
        for _ in 0..<Int.random(in: 3...5) {
            guard await linger(Double.random(in: 5...8), activity) else { return }
            if Bool.random() { say(lines.randomElement()!, chatty: true) }
            store.perform { state, _ in state.pet?.amuseItself(fun: 2) }
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { perch = 0 }
        _ = await linger(0.5, activity)
    }

    private func dance() async {
        say(["♪ Dansdags! ♫", "♫ La la laa ♪", "Titta, jag dansar!"].randomElement()!)
        moodOverride = (.excited, Date().addingTimeInterval(9))
        for beat in 0..<10 {
            guard stillDoing(.dancing) else { return }
            withAnimation(.spring(duration: 0.2)) {
                hop = true
                lean = beat.isMultiple(of: 2) ? 10 : -10
            }
            if beat.isMultiple(of: 2) { facingRight.toggle() }
            if beat.isMultiple(of: 3) {
                floating.append(FloatingText(text: beat.isMultiple(of: 2) ? "♪" : "♫", point: CGPoint(x: critterX + CGFloat.random(in: -110...110), y: lastLayout.petCenter.y - 150)))
                cleanUpLater()
            }
            try? await Task.sleep(for: .milliseconds(240))
            withAnimation(.spring(duration: 0.3, bounce: 0.5)) { hop = false }
            try? await Task.sleep(for: .milliseconds(380))
        }
        withAnimation(.spring) { lean = 0 }
        moodOverride = nil
        store.perform { state, _ in state.pet?.amuseItself(fun: 4, energy: 1) }
    }

    /// Throws the ball for itself and fetches it, a few times.
    private func playBallAlone() async {
        guard let pet = store.pet else { return }
        var config = Playground.Config(floorY: lastLayout.petCenter.y + 118, leftX: 60, rightX: lastLayout.size.width - 60, homeX: min(max(critterX, 420), lastLayout.size.width - 400), ceilingY: 150)
        config.critterSpeed = 300 + pet.needs.energy * 2
        withAnimation(.spring) { playground = Playground(config: config, critterX: critterX) }
        say(["Jag leker själv lite!", "Boll! Boll!", "Hämta, hämta!"].randomElement()!)
        var tosses = 0
        var nextToss = Date().addingTimeInterval(1)
        var last = Date()
        while stillDoing(.playingBall), toy == nil, var ground = playground {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date()
            let dt = min(0.05, now.timeIntervalSince(last))
            last = now
            if ground.ballState == .resting, ground.task == .idle {
                if tosses >= 3 { return }
                if now >= nextToss {
                    let towardRight = ground.critterX < lastLayout.size.width / 2
                    if ground.tossBallItself(towardRight: towardRight, strength: Double.random(in: 450...800)) { tosses += 1 }
                }
            }
            let events = ground.step(dt)
            guard stillDoing(.playingBall), toy == nil else { return }
            playground = ground
            for event in events {
                switch event {
                case .bounced:
                    SoundFX.play(.bounce)
                case .caughtBall:
                    if Bool.random() { say(["Tog den!", "Hihi!"].randomElement()!, chatty: true) }
                case .deliveredBall:
                    nextToss = now.addingTimeInterval(Double.random(in: 1.2...2.5))
                    store.perform { state, _ in state.pet?.amuseItself(fun: 3, energy: 1) }
                case .poppedBubble:
                    break
                }
            }
        }
    }

    // MARK: Play corner

    private static let barColors: [Color] = [.coral, Color(hex: 0xFF9F68), .butter, .mint, .sky, .lavender]

    private func barRect(_ index: Int, layout: RoomLayout) -> CGRect {
        let xylo = layout.xylophone
        let width: CGFloat = 34
        let gap = (xylo.width - 30 - width * 6) / 5
        let height = xylo.height - CGFloat(index) * 9
        let x = xylo.minX + 15 + CGFloat(index) * (width + gap)
        return CGRect(x: x, y: xylo.midY - height / 2 + CGFloat(index) * 2, width: width, height: height)
    }

    /// The slide, the xylophone bars and the bouncy cushion: things you can tap.
    private func playCorner(layout: RoomLayout) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .frame(width: layout.slideArea.width, height: layout.slideArea.height)
                .position(x: layout.slideArea.midX, y: layout.slideArea.midY)
                .onTapGesture { Task { await slide(alone: false) } }
                .accessibilityElement()
                .accessibilityIdentifier("slide")
                .accessibilityLabel("Rutschkana. Tryck så åker sötisen.")
                .accessibilityAddTraits(.isButton)

            ForEach(0..<6, id: \.self) { index in
                let rect = barRect(index, layout: layout)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Self.barColors[index])
                    .overlay(alignment: .top) { Circle().fill(.white.opacity(0.8)).frame(width: 9, height: 9).padding(.top, 8) }
                    .overlay(alignment: .bottom) { Circle().fill(.white.opacity(0.8)).frame(width: 9, height: 9).padding(.bottom, 8) }
                    .frame(width: rect.width, height: rect.height)
                    .offset(y: struckBar == index ? 5 : 0)
                    .contentShape(Rectangle().inset(by: -6))
                    .position(x: rect.midX, y: rect.midY)
                    .onTapGesture { strike(index, byPlayer: true) }
                    .accessibilityElement()
                    .accessibilityIdentifier("xylophone-\(index)")
                    .accessibilityLabel("Xylofon, ton \(index + 1)")
                    .accessibilityAddTraits(.isButton)
            }

            BouncyCushion(squashed: cushionSquash)
                .frame(width: 260, height: 110)
                .contentShape(Ellipse())
                .position(x: layout.cushion.x, y: layout.cushion.y - BouncyCushion.top + 55)
                .onTapGesture { Task { await bounce(alone: false) } }
                .accessibilityElement()
                .accessibilityIdentifier("cushion")
                .accessibilityLabel("Studsdyna. Tryck så studsar sötisen.")
                .accessibilityAddTraits(.isButton)
        }
    }

    /// Can it go and play in the play corner right now? Says why not, if it can't.
    private func readyToPlay(alone: Bool) -> Bool {
        guard !stageBusy, toy == nil, let pet = store.pet, pet.isAlive else { return false }
        if alone { return true }
        noteTouch()
        if pet.isAsleep { say("Zzz…"); return false }
        if pet.temper(at: store.now) >= .grumpy { say("Inte nu…", chatty: true); return false }
        if pet.needs.energy < 10 { say("För trött…"); return false }
        return true
    }

    private func stillPlaying(alone: Bool, _ activity: SoloActivity) -> Bool {
        alone ? stillDoing(activity) : !Task.isCancelled && store.pet?.isAsleep == false
    }

    private func slide(alone: Bool) async {
        guard readyToPlay(alone: alone) else { return }
        stageBusy = true
        let l = lastLayout
        if !alone { busyUntil = Date().addingTimeInterval(9) }
        await walk(to: l.slideLadderX, speed: alone ? 170 : 260)
        guard stillPlaying(alone: alone, .sliding) else { return endStage() }
        facingRight = true
        // Feet on the ladder, the platform, then along the top of the ramp (it is 40 thick, drawn on its centre line).
        let rampTop: CGFloat = 18
        func at(_ x: CGFloat, _ feetY: CGFloat) -> CGPoint { l.critterCenter(feetAt: CGPoint(x: x, y: feetY)) }
        stagePoint = l.petCenter
        stagePoint = at(l.slideLadderX, l.feetY)
        withAnimation(.easeInOut(duration: 1.1)) { stagePoint = at(l.slideLadderX + 10, l.slideTop.y) }
        try? await Task.sleep(for: .seconds(1.15))
        withAnimation(.easeInOut(duration: 0.35)) { stagePoint = at(l.slideLadderX + 90, l.slideTop.y) }
        try? await Task.sleep(for: .seconds(0.5))
        guard stillPlaying(alone: alone, .sliding) else { return endStage() }
        say(["Wiiiii!", "Huiii!", "Här kommer jag!"].randomElement()!)
        SoundFX.play(.whoosh)
        moodOverride = (.excited, Date().addingTimeInterval(2))
        withAnimation(.easeIn(duration: 0.7)) { stagePoint = at(l.slideBottom.x - 70, l.slideBottom.y - 30 - rampTop) }
        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.easeOut(duration: 0.3)) { stagePoint = at(l.slideBottom.x + 50, l.slideBottom.y - rampTop) }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeOut(duration: 0.2)) { stagePoint = at(l.slideBottom.x + 110, l.feetY) }
        try? await Task.sleep(for: .seconds(0.25))
        critterX = l.slideBottom.x + 110
        Haptics.thump()
        SoundFX.play(.bounce)
        addHearts(at: CGPoint(x: critterX, y: l.petCenter.y - 80), count: 2)
        reward(alone: alone, fun: 8)
        say(alone ? "Igen, igen!" : ["Igen! Igen!", "Det var så kul!"].randomElement()!, chatty: alone)
        endStage()
    }

    private func bounce(alone: Bool) async {
        guard readyToPlay(alone: alone) else { return }
        stageBusy = true
        let l = lastLayout
        if !alone { busyUntil = Date().addingTimeInterval(8) }
        await walk(to: l.cushion.x, speed: alone ? 170 : 260)
        guard stillPlaying(alone: alone, .bouncing) else { return endStage() }
        // Feet on the cushion's top; when it squashes, the top sinks and the feet go with it.
        let rest = l.critterCenter(feetAt: l.cushion)
        let sunk = CGPoint(x: rest.x, y: rest.y + BouncyCushion.sink)
        stagePoint = l.petCenter
        withAnimation(.spring(duration: 0.35)) { stagePoint = rest }
        try? await Task.sleep(for: .seconds(0.4))
        for (index, height) in [90.0, 150, 220, 260].enumerated() {
            guard stillPlaying(alone: alone, .bouncing) else { return endStage() }
            withAnimation(.easeOut(duration: 0.1)) {
                cushionSquash = true
                stagePoint = sunk
            }
            SoundFX.play(.boing)
            try? await Task.sleep(for: .milliseconds(110))
            let up = 0.18 + height / 900
            withAnimation(.spring(duration: 0.15)) { cushionSquash = false }
            withAnimation(.easeOut(duration: up)) { stagePoint = CGPoint(x: rest.x, y: rest.y - height) }
            if index == 3 { say(["Boing boing!", "Jag flyger!", "Högre!"].randomElement()!) }
            moodOverride = (.excited, Date().addingTimeInterval(1))
            try? await Task.sleep(for: .seconds(up))
            withAnimation(.easeIn(duration: up)) { stagePoint = rest }
            try? await Task.sleep(for: .seconds(up))
        }
        withAnimation(.easeOut(duration: 0.1)) { cushionSquash = true; stagePoint = sunk }
        try? await Task.sleep(for: .milliseconds(110))
        withAnimation(.spring(duration: 0.2)) { cushionSquash = false; stagePoint = rest }
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(duration: 0.4)) { stagePoint = l.critterCenter(feetAt: CGPoint(x: l.cushion.x - 180, y: l.feetY)) }
        try? await Task.sleep(for: .seconds(0.4))
        critterX = l.cushion.x - 180
        reward(alone: alone, fun: 6)
        endStage()
    }

    /// A xylophone note. When you play, the sötis dances along; every few notes is a bit of fun.
    private func strike(_ index: Int, byPlayer: Bool) {
        SoundFX.play(SoundFX.Effect.notes[index])
        let rect = barRect(index, layout: lastLayout)
        withAnimation(.spring(duration: 0.15)) { struckBar = index }
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            if struckBar == index { withAnimation(.spring(duration: 0.25)) { struckBar = nil } }
        }
        floating.append(FloatingText(text: index.isMultiple(of: 2) ? "♪" : "♫", point: CGPoint(x: rect.midX, y: rect.minY - 30)))
        cleanUpLater()
        guard byPlayer, let pet = store.pet, !pet.isAsleep else { return }
        lastTouch = Date()
        if solo != nil { endSolo() }
        notesPlayed += 1
        let calm = pet.temper(at: store.now) < .grumpy && stagePoint == nil && toy == nil
        let near = abs(critterX - lastLayout.xylophone.midX) < 650
        if calm, !near, Date() > busyUntil {
            // It hears the music and comes over to dance.
            busyUntil = Date().addingTimeInterval(6)
            say("Musik! Jag kommer!", chatty: true)
            Task { await walk(to: lastLayout.xylophone.minX - 150, speed: 300) }
        } else if calm, near {
            busyUntil = Date().addingTimeInterval(4)
            facingRight = lastLayout.xylophone.midX > critterX
            withAnimation(.spring(duration: 0.2)) {
                hop = true
                lean = notesPlayed.isMultiple(of: 2) ? 8 : -8
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { hop = false; lean = 0 }
            }
            moodOverride = (.excited, Date().addingTimeInterval(1.2))
        }
        if notesPlayed.isMultiple(of: 4) {
            store.perform { state, now in _ = state.pet?.play(at: now, fun: 3, energy: 0.5) }
        }
        if notesPlayed.isMultiple(of: 10) {
            say(["Vilken fin låt!", "Mer musik!", "Jag dansar!"].randomElement()!)
        }
    }

    private func playXylophoneAlone() async {
        let l = lastLayout
        await walk(to: l.xylophone.minX - 150)
        guard stillDoing(.makingMusic) else { return }
        facingRight = true
        say(["Lyssna på min låt!", "Pling plong!"].randomElement()!)
        let tune = [0, 2, 4, 2, 0, 2, 4, 5, 4, 2, 1, 0]
        for note in tune {
            guard stillDoing(.makingMusic) else { return }
            strike(note, byPlayer: false)
            withAnimation(.spring(duration: 0.18)) { hop = true }
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(duration: 0.25)) { hop = false }
            try? await Task.sleep(for: .milliseconds(240))
        }
        store.perform { state, _ in state.pet?.amuseItself(fun: 4) }
    }

    private func reward(alone: Bool, fun: Double) {
        if alone {
            store.perform { state, _ in state.pet?.amuseItself(fun: fun / 2, energy: 1) }
        } else {
            store.perform { state, now in _ = state.pet?.play(at: now, fun: fun, energy: 2) }
            floating.append(FloatingText(text: "+\(Int(fun)) kul", point: CGPoint(x: critterX, y: lastLayout.petCenter.y - 160)))
            cleanUpLater()
        }
    }

    private func endStage() {
        if let stagePoint, abs(stagePoint.y - lastLayout.critterCenter(feetAt: CGPoint(x: 0, y: lastLayout.feetY)).y) > 2 {
            critterX = stagePoint.x
            withAnimation(.spring(duration: 0.4)) { self.stagePoint = nil }
        } else {
            stagePoint = nil
        }
        stageBusy = false
    }

    private func watchFish() async {
        await walk(to: lastLayout.fishBowl.x + 10)
        guard stillDoing(.watchingFish) else { return }
        lookPoint = lastLayout.fishBowl
        say(["Hej, fisken!", "Blubb blubb!", "Vad simmar du på?"].randomElement()!)
        guard await linger(3, .watchingFish) else { return }
        withAnimation(.spring(duration: 0.22)) { hop = true }
        try? await Task.sleep(for: .milliseconds(220))
        withAnimation(.spring(duration: 0.3, bounce: 0.5)) { hop = false }
        guard await linger(3, .watchingFish) else { return }
        store.perform { state, _ in state.pet?.amuseItself(fun: 1) }
    }

    private func lookAround() async {
        for _ in 0..<2 {
            lookPoint = CGPoint(x: critterX + CGFloat.random(in: -400...400), y: CGFloat.random(in: 150...600))
            try? await Task.sleep(for: .seconds(1.1))
        }
        lookPoint = nil
        if Bool.random() {
            withAnimation(.spring(duration: 0.22)) { hop = true }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(duration: 0.3, bounce: 0.5)) { hop = false }
        }
    }

    private func walk(to target: CGFloat, speed: Double = 170) async {
        let distance = abs(target - critterX)
        guard distance > 20 else { return }
        let duration = Double(distance) / speed
        facingRight = target > critterX
        walking = true
        stroll = (critterX, target, Date(), duration)
        withAnimation(.linear(duration: duration)) { critterX = target }
        try? await Task.sleep(for: .seconds(duration))
        walking = false
    }

    // MARK: Playtime

    private func startPlay(_ chosen: Toy, layout: RoomLayout) {
        guard let pet = store.pet else { return }
        noteTouch()
        if pet.isAsleep { return say("Zzz…") }
        if pet.needs.energy < 10 { return say("För trött för att leka…") }
        var config = Playground.Config(floorY: layout.petCenter.y + 118, leftX: 60, rightX: layout.size.width - 60, homeX: Double(camera.x) + 600, ceilingY: 150)
        config.critterSpeed = 380 + pet.needs.energy * 2
        withAnimation(.spring) {
            showFridge = false
            playground = Playground(config: config, critterX: critterX)
            toy = chosen
        }
        say(chosen == .ball ? "Åh, bollen! Kasta den!" : "Bubblor! Tryck så blåser vi!")
        Haptics.tap()
    }

    private func switchToy(_ chosen: Toy) {
        toy = chosen
        say(chosen == .ball ? "Svep iväg bollen!" : "Tryck var som helst för bubblor!")
    }

    private func stopPlay() {
        if let playground {
            critterX = playground.critterX
            facingRight = playground.facingRight
            if playground.fetches + playground.pops > 0 { say("Det var jättekul!") }
        }
        withAnimation(.spring) {
            playground = nil
            toy = nil
        }
    }

    private func playLoop() async {
        var last = Date()
        while !Task.isCancelled, playground != nil {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date()
            let dt = min(0.05, now.timeIntervalSince(last))
            last = now
            guard var playground else { return }
            let events = playground.step(dt)
            self.playground = playground
            for event in events { handle(event) }
        }
    }

    private func handle(_ event: Playground.Event) {
        guard let playground else { return }
        let critterPoint = CGPoint(x: playground.critterX, y: lastLayout.petCenter.y - 100)
        switch event {
        case .bounced:
            Haptics.soft()
            SoundFX.play(.bounce)
        case .caughtBall(let inAir):
            Haptics.thump()
            SoundFX.play(.squeak)
            say(inAir ? "Fångad i luften!!" : "Tog den!")
            if inAir { addHearts(at: critterPoint, count: 2) }
        case .deliveredBall:
            Haptics.success()
            SoundFX.play(.giggle)
            let played = store.perform { state, now in state.pet?.play(at: now, fun: 10, energy: 3) ?? false }
            addHearts(at: critterPoint, count: 2)
            floating.append(FloatingText(text: "+10 kul", point: CGPoint(x: critterPoint.x, y: critterPoint.y - 60)))
            if playground.fetches.isMultiple(of: 3) {
                store.perform { state, _ in state.earn(1) }
                floating.append(FloatingText(text: "+1 mynt", point: CGPoint(x: critterPoint.x + 90, y: critterPoint.y - 20)))
            }
            say(["Igen! Igen!", "Kasta igen!", "Jag är supersnabb!", "Varsågod!"].randomElement()!)
            cleanUpLater()
            checkTired(played: played)
        case .poppedBubble(let point):
            Haptics.tap()
            SoundFX.play(.pop)
            sparkles.append(FloatingText(text: "", point: CGPoint(x: point.x, y: point.y)))
            let played = store.perform { state, now in state.pet?.play(at: now, fun: 4, energy: 1) ?? false }
            if playground.pops.isMultiple(of: 4) {
                store.perform { state, _ in state.earn(1) }
                floating.append(FloatingText(text: "+1 mynt", point: CGPoint(x: point.x, y: point.y - 30)))
            }
            if Int.random(in: 0..<3) == 0 { say(["Poff!", "Tog dig!", "Hihi!", "Mer bubblor!"].randomElement()!) }
            cleanUpLater()
            checkTired(played: played)
        }
    }

    private func checkTired(played: Bool) {
        guard let pet = store.pet else { return }
        if !played || pet.needs.energy < 10 {
            playground?.isTired = true
            say("Jag är helt slut…")
        }
    }

    private var ballGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("room"))
            .onChanged { value in
                lastTouch = Date()
                if solo == .playingBall {
                    solo = nil
                    toy = .ball
                }
                guard var playground else { return }
                let point = Point2(value.location.x, value.location.y)
                if !grabbingBall {
                    grabbingBall = playground.grabBall(at: point)
                    if grabbingBall { Haptics.tap() }
                } else {
                    playground.dragBall(to: point)
                }
                self.playground = playground
            }
            .onEnded { value in
                guard grabbingBall, var playground else { return }
                grabbingBall = false
                playground.throwBall(velocity: Point2(value.velocity.width, value.velocity.height))
                self.playground = playground
            }
    }

    /// The empty room: swipe to look around; a touch makes the sötis look at your finger or blows a bubble.
    private func roomTouch(layout: RoomLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("screen"))
            .onChanged { value in
                if camera.drag(translation: value.translation.width) {
                    lastTouch = Date()
                    lookPoint = nil
                    return
                }
                lookPoint = worldPoint(value.location)
            }
            .onEnded { value in
                if camera.endDrag(velocity: value.velocity.width) { return }
                if solo != nil || Date().timeIntervalSince(lastTouch) > 1 { noteTouch() }
                lastTouch = Date()
                let point = worldPoint(value.location)
                if toy == .bubbles {
                    playground?.blowBubble(at: Point2(point.x, min(point.y, layout.petCenter.y)))
                    Haptics.soft()
                    SoundFX.play(.boop)
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    lookPoint = nil
                }
            }
    }

    private func worldPoint(_ screen: CGPoint) -> CGPoint {
        CGPoint(x: screen.x + camera.x, y: screen.y)
    }

    /// What the camera keeps on screen when you aren't swiping: the ball in play, otherwise the sötis.
    private func followTarget() -> CGFloat? {
        guard !petting, draggedFood == nil, let pet = store.pet else { return nil }
        if pet.isAsleep { return RoomLayout.bedX }
        if let playground {
            return playground.ballState == .flying ? playground.ball.x : playground.critterX
        }
        if let stagePoint { return stagePoint.x }
        if let stroll {
            let progress = min(1, Date().timeIntervalSince(stroll.start) / max(0.01, stroll.duration))
            return stroll.from + (stroll.to - stroll.from) * progress
        }
        return critterX
    }

    // MARK: Petting and tickling

    private func petting(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("room"))
            .onChanged { value in
                let point = value.location
                if !petting { noteTouch() }
                petting = true
                busyUntil = Date().addingTimeInterval(4)
                lookPoint = point
                withAnimation(.easeOut(duration: 0.2)) { lean = Double(max(-1, min(1, (point.x - center.x) / 150))) * 6 }
                if let last = lastDragPoint {
                    strokeDistance += hypot(point.x - last.x, point.y - last.y)
                    noteScribble(dx: point.x - last.x)
                }
                lastDragPoint = point
                if strokeDistance > 160 {
                    strokeDistance = 0
                    stroke(at: point)
                }
            }
            .onEnded { value in
                if hypot(value.translation.width, value.translation.height) < 8 {
                    poke()
                }
                petting = false
                withAnimation(.spring) { lean = 0 }
                lastDragPoint = nil
                lookPoint = nil
                strokeDistance = 0
            }
    }

    private func stroke(at point: CGPoint) {
        guard let pet = store.pet else { return }
        let before = pet.temper(at: store.now)
        let result = store.perform { state, now in state.pet?.stroke(at: now) } ?? .dead
        switch result {
        case .loved(let gain) where gain > 0:
            Haptics.soft()
            SoundFX.play(.purr)
            addHearts(at: point, count: gain > Rules.strokeLove ? 3 : 1)
            say(gain > Rules.strokeLove ? "Jag har saknat dig!! +\(Int(gain)) kärlek" : ["Purrrr…", "Mmm, skönt…", "Mer, tack!", "Så mysigt…"].randomElement()! + " +\(Int(gain)) kärlek", chatty: true)
        case .loved:
            Haptics.soft()
            addHearts(at: point, count: 1)
            say(["Mmm…", "Purr…"].randomElement()!, chatty: true)
        case .tooSoon:
            break
        case .nowFull:
            Haptics.success()
            SoundFX.play(.purr)
            addHearts(at: point, count: 4)
            say("Mmm, nu är jag full av kärlek!")
        case .enough:
            Haptics.soft()
            say("Nu räcker det snart med gos…")
        case .grumpy:
            Haptics.thump()
            say("Hmpf! Nu vill jag vara ifred!")
            petting = false
            Task {
                try? await Task.sleep(for: .seconds(1))
                await walk(to: critterX < 640 ? 980 : 420)
            }
        case .ignored:
            grumble(before: before)
        case .asleep:
            say("Zzz… (\(pet.pronounName) sover)", chatty: true)
        case .dead:
            break
        }
    }

    /// A quick back-and-forth scribble on the sötis is tickling.
    private func noteScribble(dx: CGFloat) {
        guard abs(dx) > 2 else { return }
        let direction: CGFloat = dx > 0 ? 1 : -1
        if direction != scribbleDirection {
            scribbleDirection = direction
            let now = Date()
            scribbleTurns = scribbleTurns.filter { now.timeIntervalSince($0) < 0.8 } + [now]
            if scribbleTurns.count >= 4 {
                scribbleTurns = []
                tickle()
            }
        }
    }

    private func poke() {
        guard let pet = store.pet, !pet.isAsleep else { return }
        let now = Date()
        tickleTaps = tickleTaps.filter { now.timeIntervalSince($0) < 0.6 } + [now]
        Haptics.tap()
        if tickleTaps.count >= 2 {
            tickleTaps = []
            tickle()
            return
        }
        SoundFX.play(.boop)
        withAnimation(.spring(duration: 0.22)) { hop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(duration: 0.3, bounce: 0.5)) { hop = false }
        }
        if pet.isIgnoring(at: store.now) {
            let before = pet.temper(at: store.now)
            store.perform { state, now in state.pet?.poke(at: now) }
            return grumble(before: before)
        }
        say(["Hej!", "Bopp!", "Hihi!", "Läget?", "Hej kompis!"].randomElement()!, chatty: true)
    }

    private func tickle() {
        guard let pet = store.pet else { return }
        let before = pet.temper(at: store.now)
        let result = store.perform { state, now in state.pet?.tickle(at: now) } ?? .dead
        switch result {
        case .giggled:
            wiggle = true
            SoundFX.play(.giggle)
            Haptics.soft()
            moodOverride = (.excited, Date().addingTimeInterval(1.4))
            say(["Hihihi! Sluta!", "Kittlas inte!!", "Ha ha ha!", "Hihi, det kittlas!"].randomElement()!)
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                wiggle = false
            }
        case .tooSoon:
            break
        case .ignored:
            grumble(before: before)
        case .asleep, .dead:
            break
        }
    }

    // MARK: Care actions

    private func dragFood(_ id: String, to screenPoint: CGPoint, ended: Bool, layout: RoomLayout) {
        let point = worldPoint(screenPoint)
        if !ended {
            if draggedFood == nil { Haptics.tap() }
            draggedFood = id
            foodPoint = point
            busyUntil = Date().addingTimeInterval(4)
            return
        }
        let mouth = CGPoint(x: critterX, y: layout.petCenter.y + 10)
        let close = hypot(point.x - mouth.x, point.y - mouth.y) < 150
        withAnimation(.spring) { draggedFood = nil }
        if close {
            feed(id)
        } else {
            say("Kom hit med den!")
        }
    }

    private func feed(_ itemID: String) {
        guard let pet = store.pet else { return }
        guard !pet.isAsleep else { return say("Zzz… (för sömnig för att äta)") }
        let wasGrumpy = pet.isGrumpy(at: store.now)
        let sweet = Catalog.item(itemID)?.foodEffect?.isSweet == true
        let result = store.perform { state, now in state.feed(itemID, now: now) }
        Haptics.thump()
        SoundFX.play(.chomp)
        chomping = true
        withAnimation(.spring(duration: 0.15)) { hop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.2)) { hop = false }
            try? await Task.sleep(for: .milliseconds(800))
            chomping = false
        }
        sparkles.append(FloatingText(text: "crumbs", point: CGPoint(x: critterX, y: lastLayout.petCenter.y + 20)))
        cleanUpLater()
        if sweet, result != nil {
            addHearts(at: CGPoint(x: critterX, y: lastLayout.petCenter.y - 60), count: 3)
            moodOverride = (.excited, Date().addingTimeInterval(2))
        }
        if wasGrumpy, result != nil {
            return say("Tack… Jag är inte sur längre. Men jag vill vara ifred en stund.")
        }
        switch result {
        case .yummy where sweet: say(["Godis! Jag är så glad!", "Mmm, så sött! Tack!"].randomElement()!)
        case .yummy: say(["Mums mums!", "Smaskens!", "Jättegott!"].randomElement()!)
        case .tooFull: say("Uff… jag är så mätt!")
        case .dead: break
        case .asleep, nil: say("Hmm?")
        }
    }

    private func refillWater() {
        guard let pet = store.pet else { return }
        if pet.isAsleep { return say("Zzz…") }
        if store.state.count(of: "water") == 0 {
            toaster.show("Vattnet är slut. Köp mer i affären!")
            return
        }
        Task {
            busyUntil = Date().addingTimeInterval(6)
            await walk(to: 980)
            let wasGrumpy = store.pet?.isGrumpy(at: store.now) == true
            if store.perform({ state, now in state.refillWater(now: now) }) {
                Haptics.success()
                SoundFX.play(.splash)
                say(wasGrumpy ? "Tack… Jag är inte sur längre. Men jag vill vara ifred en stund." : "Slurp slurp! Ahh.")
            }
        }
    }

    private func toggleSleep() {
        guard let pet = store.pet else { return }
        if pet.isAsleep {
            store.perform { state, now in state.pet?.wakeUp(at: now) }
            critterX = RoomLayout.bedX + 120
            say(pet.needs.energy < 60 ? "Gäsp… grinig…" : "God morgon!")
        } else if pet.needs.energy >= 95 {
            say("Jag är inte trött!")
        } else {
            Task {
                busyUntil = Date().addingTimeInterval(8)
                await walk(to: RoomLayout.bedX)
                if store.perform({ state, now in state.pet?.goToSleep(at: now) ?? false }) {
                    withAnimation { bubble = nil }
                }
            }
        }
    }

    private func goOut(_ screen: Screen) {
        guard let pet = store.pet else { return }
        if pet.isAsleep { return toaster.show("Sch, \(pet.pronounName) sover.") }
        if screen == .park, pet.needs.energy < 15 { return toaster.show("\(pet.pronounName) är för trött för parken.") }
        navigate(screen)
    }

    private func giveMedicine() {
        if store.state.count(of: "medicine") == 0 {
            toaster.show("Ingen medicin. Köp ett må-bra-piller i affären!")
        } else if store.perform({ state, now in state.giveMedicine(now: now) }) {
            Haptics.success()
            say("Jag mår redan bättre!")
        }
    }

    private func scoop(_ poop: Poop, at point: CGPoint) {
        if let coins = store.perform({ state, _ in state.scoop(poop.id) }) {
            Haptics.tap()
            SoundFX.play(.coin)
            floating.append(FloatingText(text: "+\(coins)", point: point))
            sparkles.append(FloatingText(text: "", point: point))
            if Bool.random() { say(["Tack!", "Mycket bättre!", "Hoppsan, förlåt!"].randomElement()!) }
            cleanUpLater()
        }
    }

    // MARK: Effects

    /// Chatty lines (hellos, purrs) never cut off a bubble that only just appeared,
    /// so tapping fast can't flood the screen. Everything else replaces the bubble.
    private func say(_ text: String, chatty: Bool = false) {
        let now = Date()
        if chatty, bubble != nil, now.timeIntervalSince(bubbleShownAt) < 1.6 { return }
        guard text != bubble else { return }
        bubbleShownAt = now
        let token = UUID()
        bubbleToken = token
        withAnimation(.spring) { bubble = text }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if bubbleToken == token { withAnimation { bubble = nil } }
        }
    }

    private func addHearts(at point: CGPoint, count: Int) {
        let room = max(0, 8 - hearts.count)
        for index in 0..<min(count, room) {
            hearts.append(HeartBurst(point: CGPoint(x: point.x + CGFloat(index * 24 - 24), y: point.y), drift: CGFloat.random(in: -60...60)))
        }
        cleanUpLater()
    }

    private func cleanUpLater() {
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            hearts.removeAll()
            floating.removeAll()
            sparkles.removeAll()
        }
    }
}

extension RoomLayout {
    static let bedX: CGFloat = 300
    /// Where it sits in the window, clear of the cactus.
    static let windowSeatX: CGFloat = 820
}

/// An open picture book, held up while it reads in the window. A page turns now and then.
private struct ReadingBook: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5)
            let turn = t < 0.6 ? t / 0.6 : 1
            SketchView(width: 80, height: 52) { c in
                c.box(2, 6, 76, 44, radius: 6, .coralDeep)
                c.box(6, 4, 33, 42, radius: 4, .cream)
                c.box(41, 4, 33, 42, radius: 4, .cream)
                c.line(.inkSoft.opacity(0.5), width: 2) { p in
                    for row in 0..<4 {
                        let y = 13 + CGFloat(row) * 8
                        p.move(to: CGPoint(x: 11, y: y)); p.addLine(to: CGPoint(x: 34, y: y))
                        p.move(to: CGPoint(x: 46, y: y)); p.addLine(to: CGPoint(x: row == 3 ? 58 : 69, y: y))
                    }
                }
                c.star(58, 40, 4, .butter)
                if turn < 1 {
                    let edge = 74 - CGFloat(turn) * 68
                    c.shape(.white) { $0.addLines([CGPoint(x: 40, y: 4), CGPoint(x: edge, y: 2), CGPoint(x: edge, y: 44), CGPoint(x: 40, y: 46)]) }
                }
                c.line(.coralDeep, width: 2) { p in p.move(to: CGPoint(x: 40, y: 4)); p.addLine(to: CGPoint(x: 40, y: 46)) }
            }
        }
    }
}

/// A big squishy cushion to bounce on.
struct BouncyCushion: View {
    let squashed: Bool
    /// Where the middle of its top face is, in its 260 × 110 frame: feet land here.
    static let top: CGFloat = 50
    static let squash: CGFloat = 0.8
    /// How far the top face drops when it squashes (it squashes from the bottom).
    static var sink: CGFloat { (110 - top) * (1 - squash) }

    var body: some View {
        SketchView(width: 260, height: 110) { c in
            c.oval(130, 78, 124, 30, .lavenderDeep)
            c.oval(130, 62, 120, 40, .lavender)
            c.oval(130, 52, 96, 22, Color(hex: 0xD9CCFF))
            for (x, y) in [(70.0, 64.0), (120, 74), (176, 66), (100, 52), (154, 50)] {
                c.dot(x, y, 4, .white.opacity(0.8))
            }
        }
        .scaleEffect(x: squashed ? 1.08 : 1, y: squashed ? Self.squash : 1, anchor: .bottom)
        .animation(.spring(duration: 0.15), value: squashed)
    }
}

/// A pill along the top: the score and how to play. Never over the sötis.
private struct PlayScore: View {
    let toy: Toy
    let fetches: Int
    let pops: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(toy == .ball ? fetches : pops)")
                .font(.cute(30, .bold))
                .contentTransition(.numericText())
                .accessibilityIdentifier("play-count")
            VStack(alignment: .leading, spacing: 0) {
                Text(toy == .ball ? "Apport! · hämtningar" : "Bubbelpop! · bubblor").font(.cute(17, .bold))
                Text(toy == .ball ? "Dra i bollen och släpp för att kasta" : "Tryck i rummet för att blåsa bubblor")
                    .font(.cute(14, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20)
        .frame(height: 64)
        .card(radius: 32)
        .allowsHitTesting(false)
    }
}

struct BallView: View {
    var body: some View {
        SketchView(width: 60, height: 60) { c in
            c.dot(30, 30, 27, .coral)
            c.line(.white, width: 4) { p in
                p.move(to: CGPoint(x: 5, y: 26)); p.addQuadCurve(to: CGPoint(x: 55, y: 26), control: CGPoint(x: 30, y: 44))
            }
            c.dot(21, 19, 6, .white.opacity(0.6))
        }
    }
}

private struct SoapBubble: View {
    let phase: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let wobble = 1 + sin(timeline.date.timeIntervalSinceReferenceDate * 3 + phase) * 0.05
            ZStack {
                Circle().fill(Color.white.opacity(0.25))
                Circle().strokeBorder(
                    AngularGradient(colors: [.pink, .lavender, .sky, .mint, .butter, .pink], center: .center),
                    lineWidth: 4
                )
                Circle().fill(.white.opacity(0.85)).frame(width: 14, height: 14).offset(x: -14, y: -14)
            }
            .scaleEffect(x: wobble, y: 2 - wobble)
        }
    }
}

struct SparkleLayer: View {
    let items: [FloatingText]

    var body: some View {
        ZStack {
            ForEach(items) { item in
                SparkleBurst(crumbs: item.text == "crumbs").position(item.point)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SparkleBurst: View {
    let crumbs: Bool
    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index) / 7 * 2 * .pi + (crumbs ? 0.3 : 0)
                Group {
                    if crumbs {
                        Circle().fill(index.isMultiple(of: 2) ? Color.poopLight : Color(hex: 0xE8B27A)).frame(width: 9, height: 9)
                    } else {
                        SketchView(width: 20, height: 20) { c in c.sparkle(10, 10, 9, [Color.butter, .pink, .sky, .lavender][index % 4]) }
                            .frame(width: 22, height: 22)
                    }
                }
                .offset(x: burst ? cos(angle) * 60 : 0, y: burst ? sin(angle) * (crumbs ? 30 : 60) + (crumbs ? 30 : 0) : 0)
                .opacity(burst ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { burst = true } }
    }
}

/// The needs as a slim column of rings, so the panel never covers the room.
struct NeedsStrip: View {
    let pet: Pet
    static let height: CGFloat = 7 * 58 + 6 * 8 + 24

    var body: some View {
        VStack(spacing: 8) {
            NeedRing(title: "Mat", systemName: "fork.knife", value: pet.needs.hunger, tint: Color(hex: 0xFF9F68), iconFill: .peachLight)
            NeedRing(title: "Vatten", systemName: "drop.fill", value: pet.needs.thirst, tint: .skyDeep, iconFill: .skyLight)
            NeedRing(title: "Energi", systemName: "moon.fill", value: pet.needs.energy, tint: .lavenderDeep, iconFill: Color(hex: 0xECE4FF))
            NeedRing(title: "Renhet", systemName: "bubbles.and.sparkles.fill", value: pet.needs.hygiene, tint: .mintDeep, iconFill: .mintLight)
            NeedRing(title: "Kul", systemName: "tennisball.fill", value: pet.needs.fun, tint: .butterDeep, iconFill: .butterLight)
            NeedRing(title: "Kärlek", systemName: "heart.fill", value: pet.needs.love, tint: .coral, iconFill: .pinkLight)
            NeedRing(title: pet.poops.isEmpty ? "Rummet" : "Rummet, \(pet.poops.count) bajskorv\(pet.poops.count == 1 ? "" : "ar")", systemName: "house.fill", value: pet.roomCleanliness, tint: .poopLight, iconFill: Color(hex: 0xEFE6DC), badge: pet.poops.count)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 9)
        .card(fill: .white.opacity(0.95), radius: 38)
    }
}

/// One need: its icon inside a ring that fills up. Low needs turn red and pulse.
private struct NeedRing: View {
    let title: String
    let systemName: String
    let value: Double
    let tint: Color
    let iconFill: Color
    var badge = 0

    var body: some View {
        let low = value < 25
        ZStack {
            Circle().fill(iconFill)
            Circle().stroke(Color(hex: 0xF3E8EE), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.03, value / 100))
                .stroke(low ? Color.coralDeep : tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring, value: value)
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
        }
        .frame(width: 52, height: 52)
        .padding(3)
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text("\(badge)")
                    .font(.cute(13, .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.coralDeep))
            }
        }
        .modifier(LowPulse(active: low))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(Int(value)) procent")
    }
}

private struct LowPulse: ViewModifier {
    let active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && on ? 1.08 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { on = true } }
    }
}

struct ClockPill: View {
    @Environment(GameStore.self) private var store
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
            Text(now, format: .dateTime.weekday(.abbreviated).hour().minute())
        }
        .font(.cute(18))
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 18)
        .frame(height: 58)
        .card(radius: 29)
        #if DEBUG
        .onLongPressGesture { store.skipAhead(hours: 3) }
        #endif
    }
}

private struct FridgeTray: View {
    @Environment(GameStore.self) private var store
    let onFeed: (String) -> Void
    let onShop: () -> Void
    let onDrag: (String, CGPoint, Bool) -> Void

    var body: some View {
        let foods = Catalog.items.filter { $0.foodEffect != nil && store.state.count(of: $0.id) > 0 }
        VStack(spacing: 6) {
            if !foods.isEmpty {
                Text("Dra maten till sötisens mun, eller tryck på den")
                    .font(.cute(15, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            HStack(spacing: 12) {
                if foods.isEmpty {
                    Text("Kylskåpet är tomt!").font(.cute(20))
                    Button("Gå och handla", action: onShop)
                        .buttonStyle(ChunkyButtonStyle())
                } else {
                    ForEach(foods) { item in
                        VStack(spacing: 2) {
                            ItemArt(id: item.id).frame(width: 64, height: 64)
                            Text("\(item.name) ×\(store.state.count(of: item.id))")
                                .font(.cute(14))
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 112, height: 100)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0xFFF7EE)))
                        .contentShape(Rectangle())
                        .onTapGesture { onFeed(item.id) }
                        .gesture(
                            DragGesture(minimumDistance: 8, coordinateSpace: .named("screen"))
                                .onChanged { onDrag(item.id, $0.location, false) }
                                .onEnded { onDrag(item.id, $0.location, true) }
                        )
                        .accessibilityElement()
                        .accessibilityIdentifier("food-\(item.id)")
                        .accessibilityLabel("Mata med \(item.name.lowercased())")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onFeed(item.id) }
                    }
                }
            }
        }
        .padding(12)
        .card()
    }
}

private struct ZzzView: View {
    @State private var drift = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text("z").font(.cute(28, .bold))
            Text("z").font(.cute(38, .bold)).offset(y: -18)
            Text("Z").font(.cute(52, .bold)).offset(y: -40)
        }
        .foregroundStyle(.white)
        .offset(y: drift ? -12 : 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever()) { drift = true }
        }
        .allowsHitTesting(false)
    }
}
