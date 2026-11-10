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

    // Playtime.
    @State private var toy: Toy?
    @State private var playground: Playground?
    @State private var grabbingBall = false

    var body: some View {
        DesignCanvas(background: .pinkLight) { size in
            if let pet = store.pet {
                room(pet: pet, layout: RoomLayout(size: size))
            }
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
            RoomBackdrop(size: size, waterLevel: pet.needs.thirst / 100, foodInBowl: pet.needs.hunger > 50, isNight: store.now.isNight)

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
                .accessibilityLabel("Poop. Tap to scoop it up.")
            }

            if let playground {
                ForEach(playground.bubbles) { item in
                    SoapBubble(phase: item.phase)
                        .frame(width: 70, height: 70)
                        .position(x: item.position.x, y: item.position.y)
                        .allowsHitTesting(false)
                }
            }

            if store.now.isNight && !pet.isAsleep {
                Color.ink.opacity(0.12)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
            }

            critter(pet: pet, layout: layout)

            if let playground, toy == .ball || playground.ballState != .resting {
                BallView()
                    .frame(width: 60, height: 60)
                    .scaleEffect(grabbingBall ? 1.2 : 1)
                    .contentShape(Circle().inset(by: -30))
                    .position(x: playground.ball.x, y: playground.ball.y)
                    .gesture(ballGesture)
                    .accessibilityIdentifier("ball")
                    .accessibilityLabel("Ball. Flick it to throw.")
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
                SpeechBubble(text: bubble, tailOnLeft: center.x < 820)
                    .position(x: center.x < 820 ? center.x + 210 : center.x - 210, y: center.y - 170)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            hud(pet: pet, layout: layout)
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(.named("room"))
        .onAppear { lastLayout = layout }
        .onChange(of: layout.size) { _, _ in lastLayout = layout }
    }

    private func critterCenter(pet: Pet, layout: RoomLayout) -> CGPoint {
        if pet.isAsleep { return CGPoint(x: RoomLayout.bedX, y: layout.floorTop - 40) }
        if let playground {
            return CGPoint(x: playground.critterX, y: layout.petCenter.y - playground.hop)
        }
        return CGPoint(x: critterX, y: layout.petCenter.y)
    }

    private func displayMood(_ pet: Pet, center: CGPoint) -> Mood {
        let base = pet.expression(at: store.now)
        if [.asleep, .dead, .sick].contains(base) { return base }
        if let moodOverride, moodOverride.until > Date() { return moodOverride.mood }
        if draggedFood != nil, hypot(foodPoint.x - center.x, foodPoint.y - center.y) < 320 { return .hungry }
        if (petting || chomping) && base != .ignoring { return .happy }
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
            blissful: (petting && pet.expression(at: store.now) != .ignoring) || chomping || wiggle
        )
        .frame(width: 300, height: 300)
        .scaleEffect(pet.isAsleep ? 0.75 : 1, anchor: .bottom)
        .offset(y: hop ? -46 : 0)
        .contentShape(Circle().inset(by: 30))
        .gesture(petting(center: center))
        .position(center)
        .accessibilityElement()
        .accessibilityIdentifier("critter")
        .accessibilityLabel("\(pet.name). Stroke to pet, tap quickly to tickle.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { stroke(at: center) }
    }

    private func lookVector(from center: CGPoint) -> CGVector {
        var target: CGPoint?
        if draggedFood != nil {
            target = foodPoint
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

    private func hud(pet: Pet, layout: RoomLayout) -> some View {
        let size = layout.size
        return ZStack(alignment: .topLeading) {
            Button { showAbout = true } label: {
                HStack(spacing: 14) {
                    CritterView(genome: pet.genome, expression: .happy, weight: pet.weight)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color(hex: pet.genome.palette.stage)))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pet.name).font(.cute(22, .bold))
                        Text("Day \(pet.ageInDays(at: store.now) + 1) · \(pet.weightStage.title)")
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

            NeedsPanel(pet: pet)
                .frame(width: 236)
                .position(x: 24 + 118, y: 116 + 200)

            if pet.isSick {
                Button("Give medicine") { giveMedicine() }
                    .buttonStyle(ChunkyButtonStyle(fill: .mint, shadow: .mintDeep))
                    .position(x: 24 + 118, y: 116 + 440)
            }

            HStack(spacing: 12) {
                if store.state.piggyBank >= 1 {
                    Button {
                        let amount = store.perform { state, _ in state.collectPiggyBank() }
                        Haptics.success()
                        toaster.show("\(pet.pronounName)'s piggy bank: +\(amount) coins!")
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
                    .accessibilityLabel("Collect piggy bank coins")
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
                .position(x: size.width / 2, y: size.height - 240)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toy, let playground {
                PlayScore(toy: toy, fetches: playground.fetches, pops: playground.pops)
                    .position(x: size.width - 24 - 120, y: 24 + 150)
            }

            Group {
                if toy != nil {
                    playDock
                } else {
                    dock(pet: pet, layout: layout)
                }
            }
            .position(x: size.width / 2, y: size.height - 72)
        }
    }

    private func dock(pet: Pet, layout: RoomLayout) -> some View {
        Dock {
            DockButton(title: "Feed", systemName: "fork.knife", fill: .peachLight, highlighted: showFridge || pet.needs.hunger < 25) {
                withAnimation(.spring) { showFridge.toggle() }
            }
            DockButton(title: "Water", systemName: "drop.fill", fill: .skyLight, highlighted: pet.needs.thirst < 25) { refillWater() }
            DockButton(title: "Play", systemName: "tennisball.fill", fill: .butterLight, highlighted: pet.needs.fun < 25) { startPlay(.ball, layout: layout) }
            DockButton(title: pet.isAsleep ? "Wake" : "Sleep", systemName: pet.isAsleep ? "sun.max.fill" : "moon.zzz.fill", fill: Color(hex: 0xECE4FF), highlighted: pet.needs.energy < 20 && !pet.isAsleep) { toggleSleep() }
            DockButton(title: "Bath", systemName: "bathtub.fill", fill: .mintLight, highlighted: pet.needs.hygiene < 25) { goOut(.bath) }
            DockButton(title: "Park", systemName: "tree.fill", fill: Color(hex: 0xE3F7DC)) { goOut(.park) }
            DockButton(title: "Shop", systemName: "basket.fill", fill: .pinkLight) { navigate(.market) }
            DockButton(title: "Decor", systemName: "sofa.fill", fill: .lavenderLight) { navigate(.decor) }
            DockButton(title: "Memories", systemName: "heart.text.square.fill", fill: Color(hex: 0xF7F2FF)) { navigate(.memoriam) }
        }
    }

    private var playDock: some View {
        Dock {
            DockButton(title: "Ball", systemName: "tennisball.fill", fill: .butterLight, highlighted: toy == .ball, width: 110) {
                switchToy(.ball)
            }
            DockButton(title: "Bubbles", systemName: "bubbles.and.sparkles.fill", fill: .skyLight, highlighted: toy == .bubbles, width: 110) {
                switchToy(.bubbles)
            }
            DockButton(title: "Done", systemName: "checkmark.circle.fill", fill: .mintLight, width: 110) { stopPlay() }
        }
    }

    // MARK: Wandering

    private func wanderLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 4...8)))
            guard !Task.isCancelled, toy == nil, let pet = store.pet, pet.isAlive, !pet.isAsleep else { continue }
            guard Date() > busyUntil, !petting, draggedFood == nil, !showFridge else { continue }
            if pet.isIgnoring(at: store.now) {
                await walk(to: critterX < 640 ? 980 : 420)
                continue
            }
            if pet.needs.hunger < 35 {
                await walk(to: 860)
                say("Is there any food?")
            } else if pet.needs.thirst < 35 {
                await walk(to: 980)
                say("So thirsty…")
            } else if pet.needs.energy < 25 {
                await walk(to: RoomLayout.bedX + 60)
                say("Yaaawn…")
            } else if pet.needs.fun < 30, Bool.random() {
                say(["Play with me!", "I'm bored…", "Ball? Ball!"].randomElement()!)
            } else if Int.random(in: 0..<3) == 0 {
                await lookAround()
            } else {
                await walk(to: CGFloat.random(in: 420...860))
                if Int.random(in: 0..<4) == 0 {
                    say(["La la la~", "Hmm hmm~", "*sniff sniff*", "What a nice day!", "♪ ♫"].randomElement()!)
                }
            }
        }
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

    private func walk(to target: CGFloat) async {
        let distance = abs(target - critterX)
        guard distance > 20 else { return }
        let duration = Double(distance) / 170
        facingRight = target > critterX
        walking = true
        withAnimation(.linear(duration: duration)) { critterX = target }
        try? await Task.sleep(for: .seconds(duration))
        walking = false
    }

    // MARK: Playtime

    private func startPlay(_ chosen: Toy, layout: RoomLayout) {
        guard let pet = store.pet else { return }
        if pet.isAsleep { return say("Zzz…") }
        if pet.needs.energy < 10 { return say("Too tired to play…") }
        var config = Playground.Config(floorY: layout.petCenter.y + 118, leftX: 60, rightX: layout.size.width - 60, homeX: 600, ceilingY: 150)
        config.critterSpeed = 380 + pet.needs.energy * 2
        withAnimation(.spring) {
            showFridge = false
            playground = Playground(config: config, critterX: critterX)
            toy = chosen
        }
        say(chosen == .ball ? "Ooh, the ball! Throw it!" : "Bubbles! Tap to blow some!")
        Haptics.tap()
    }

    private func switchToy(_ chosen: Toy) {
        toy = chosen
        say(chosen == .ball ? "Flick the ball!" : "Tap anywhere to blow bubbles!")
    }

    private func stopPlay() {
        if let playground {
            critterX = playground.critterX
            facingRight = playground.facingRight
            if playground.fetches + playground.pops > 0 { say("That was so fun!") }
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
            say(inAir ? "Mid-air catch!!" : "Got it!")
            if inAir { addHearts(at: critterPoint, count: 2) }
        case .deliveredBall:
            Haptics.success()
            SoundFX.play(.giggle)
            let played = store.perform { state, now in state.pet?.play(at: now, fun: 10, energy: 3) ?? false }
            addHearts(at: critterPoint, count: 2)
            floating.append(FloatingText(text: "+10 fun", point: CGPoint(x: critterPoint.x, y: critterPoint.y - 60)))
            if playground.fetches.isMultiple(of: 3) {
                store.perform { state, _ in state.earn(1) }
                floating.append(FloatingText(text: "+1 coin", point: CGPoint(x: critterPoint.x + 90, y: critterPoint.y - 20)))
            }
            say(["Again! Again!", "Throw it again!", "I'm so fast!", "Here you go!"].randomElement()!)
            cleanUpLater()
            checkTired(played: played)
        case .poppedBubble(let point):
            Haptics.tap()
            SoundFX.play(.pop)
            sparkles.append(FloatingText(text: "", point: CGPoint(x: point.x, y: point.y)))
            let played = store.perform { state, now in state.pet?.play(at: now, fun: 4, energy: 1) ?? false }
            if playground.pops.isMultiple(of: 4) {
                store.perform { state, _ in state.earn(1) }
                floating.append(FloatingText(text: "+1 coin", point: CGPoint(x: point.x, y: point.y - 30)))
            }
            if Int.random(in: 0..<3) == 0 { say(["Pop!", "Gotcha!", "Hee hee!", "More bubbles!"].randomElement()!) }
            cleanUpLater()
            checkTired(played: played)
        }
    }

    private func checkTired(played: Bool) {
        guard let pet = store.pet else { return }
        if !played || pet.needs.energy < 10 {
            playground?.isTired = true
            say("I'm all pooped out…")
        }
    }

    private var ballGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("room"))
            .onChanged { value in
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

    private func roomTouch(layout: RoomLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("room"))
            .onChanged { value in
                lookPoint = value.location
            }
            .onEnded { value in
                if toy == .bubbles, hypot(value.translation.width, value.translation.height) < 12 {
                    playground?.blowBubble(at: Point2(value.location.x, min(value.location.y, layout.petCenter.y)))
                    Haptics.soft()
                    SoundFX.play(.boop)
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    lookPoint = nil
                }
            }
    }

    // MARK: Petting and tickling

    private func petting(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("room"))
            .onChanged { value in
                let point = value.location
                petting = true
                busyUntil = Date().addingTimeInterval(4)
                lookPoint = point
                withAnimation(.easeOut(duration: 0.2)) { lean = Double(max(-1, min(1, (point.x - center.x) / 150))) * 6 }
                if let last = lastDragPoint {
                    strokeDistance += hypot(point.x - last.x, point.y - last.y)
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
        let result = store.perform { state, now in state.pet?.stroke(at: now) } ?? .dead
        switch result {
        case .loved(let gain):
            Haptics.soft()
            SoundFX.play(.purr)
            addHearts(at: point, count: gain > Rules.strokeLove ? 3 : 1)
            say(gain > Rules.strokeLove ? "I missed you!! +\(Int(gain)) love" : ["Purrrr…", "Mmm, nice…", "More please!", "So cozy…"].randomElement()! + " +\(Int(gain)) love")
        case .nowFull:
            Haptics.success()
            addHearts(at: point, count: 4)
            say("Okay, that's enough cuddles!")
            petting = false
            Task {
                try? await Task.sleep(for: .seconds(1))
                await walk(to: critterX < 640 ? 980 : 420)
            }
        case .ignored:
            say(["Hmph. Later.", "Not now…", "I need some space!"].randomElement()!)
            facingRight.toggle()
        case .asleep:
            say("Zzz… (\(pet.pronounName) is sleeping)")
        case .dead:
            break
        }
    }

    private func poke() {
        guard let pet = store.pet, !pet.isAsleep else { return }
        let now = Date()
        tickleTaps = tickleTaps.filter { now.timeIntervalSince($0) < 1.2 } + [now]
        Haptics.tap()
        if tickleTaps.count >= 3 {
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
            say("Hmph.")
        } else {
            say(["Hi!", "Boop!", "Hee!", "What's up?", "Hello friend!"].randomElement()!)
        }
    }

    private func tickle() {
        guard store.pet?.isIgnoring(at: store.now) == false else { return say("Not now!") }
        wiggle = true
        SoundFX.play(.giggle)
        moodOverride = (.excited, Date().addingTimeInterval(1.4))
        store.perform { state, now in _ = state.pet?.play(at: now, fun: 3, energy: 0) }
        say(["Hee hee hee! Stop it!", "That tickles!!", "Ha ha ha!"].randomElement()!)
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            wiggle = false
        }
    }

    // MARK: Care actions

    private func dragFood(_ id: String, to point: CGPoint, ended: Bool, layout: RoomLayout) {
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
            say("Bring it here!")
        }
    }

    private func feed(_ itemID: String) {
        guard let pet = store.pet else { return }
        guard !pet.isAsleep else { return say("Zzz… (too sleepy to eat)") }
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
        switch result {
        case .yummy: say(["Nom nom nom!", "Yummy!", "Delicious!"].randomElement()!)
        case .tooFull: say("Oof… I'm so full!")
        case .dead: break
        case .asleep, nil: say("Hmm?")
        }
    }

    private func refillWater() {
        guard let pet = store.pet else { return }
        if pet.isAsleep { return say("Zzz…") }
        if store.state.count(of: "water") == 0 {
            toaster.show("No water left. Buy some at the market!")
            return
        }
        Task {
            busyUntil = Date().addingTimeInterval(6)
            await walk(to: 980)
            if store.perform({ state, now in state.refillWater(now: now) }) {
                Haptics.success()
                SoundFX.play(.splash)
                say("Slurp slurp! Ahh.")
            }
        }
    }

    private func toggleSleep() {
        guard let pet = store.pet else { return }
        if pet.isAsleep {
            store.perform { state, now in state.pet?.wakeUp(at: now) }
            critterX = RoomLayout.bedX + 120
            say(pet.needs.energy < 60 ? "Yawn… grumpy…" : "Good morning!")
        } else if pet.needs.energy >= 95 {
            say("I'm not sleepy!")
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
        if pet.isAsleep { return toaster.show("Shh, \(pet.pronounName) is sleeping.") }
        if screen == .park, pet.needs.energy < 15 { return toaster.show("\(pet.pronounName) is too tired for the park.") }
        navigate(screen)
    }

    private func giveMedicine() {
        if store.state.count(of: "medicine") == 0 {
            toaster.show("No medicine. Get a feel-good pill at the market!")
        } else if store.perform({ state, now in state.giveMedicine(now: now) }) {
            Haptics.success()
            say("I feel better already!")
        }
    }

    private func scoop(_ poop: Poop, at point: CGPoint) {
        if let coins = store.perform({ state, _ in state.scoop(poop.id) }) {
            Haptics.tap()
            SoundFX.play(.coin)
            floating.append(FloatingText(text: "+\(coins)", point: point))
            sparkles.append(FloatingText(text: "", point: point))
            if Bool.random() { say(["Thank you!", "Much better!", "Oops, sorry!"].randomElement()!) }
            cleanUpLater()
        }
    }

    // MARK: Effects

    private func say(_ text: String) {
        let token = UUID()
        bubbleToken = token
        withAnimation(.spring) { bubble = text }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if bubbleToken == token { withAnimation { bubble = nil } }
        }
    }

    private func addHearts(at point: CGPoint, count: Int) {
        for index in 0..<count {
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
}

private struct PlayScore: View {
    let toy: Toy
    let fetches: Int
    let pops: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(toy == .ball ? "Fetch!" : "Bubble pop!").font(.cute(20, .bold))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(toy == .ball ? fetches : pops)").font(.cute(40, .bold)).contentTransition(.numericText())
                Text(toy == .ball ? "fetches" : "pops").font(.cute(16, .medium)).foregroundStyle(Color.inkSoft)
            }
            Text(toy == .ball ? "Drag the ball and let go to throw it!" : "Tap the room to blow bubbles!")
                .font(.cute(15, .medium))
                .foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.ink)
        .padding(18)
        .frame(width: 240, alignment: .leading)
        .card()
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

struct NeedsPanel: View {
    let pet: Pet

    var body: some View {
        VStack(spacing: 12) {
            NeedBar(title: "Hunger", systemName: "fork.knife", value: pet.needs.hunger, tint: Color(hex: 0xFF9F68), iconFill: .peachLight)
            NeedBar(title: "Thirst", systemName: "drop.fill", value: pet.needs.thirst, tint: .skyDeep, iconFill: .skyLight)
            NeedBar(title: "Energy", systemName: "moon.fill", value: pet.needs.energy, tint: .lavenderDeep, iconFill: Color(hex: 0xECE4FF))
            NeedBar(title: "Clean", systemName: "bubbles.and.sparkles.fill", value: pet.needs.hygiene, tint: .mintDeep, iconFill: .mintLight)
            NeedBar(title: "Fun", systemName: "tennisball.fill", value: pet.needs.fun, tint: .butterDeep, iconFill: .butterLight)
            NeedBar(title: "Love", systemName: "heart.fill", value: pet.needs.love, tint: .coral, iconFill: .pinkLight)
            NeedBar(title: pet.poops.isEmpty ? "Room" : "Room · \(pet.poops.count) poop\(pet.poops.count == 1 ? "" : "s")", systemName: "house.fill", value: pet.roomCleanliness, tint: .poopLight, iconFill: Color(hex: 0xEFE6DC))
        }
        .padding(18)
        .card(fill: .white.opacity(0.95))
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
                Text("Drag food to your critter's mouth, or tap it")
                    .font(.cute(15, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            HStack(spacing: 12) {
                if foods.isEmpty {
                    Text("The fridge is empty!").font(.cute(20))
                    Button("Go shopping", action: onShop)
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
                            DragGesture(minimumDistance: 8, coordinateSpace: .named("room"))
                                .onChanged { onDrag(item.id, $0.location, false) }
                                .onEnded { onDrag(item.id, $0.location, true) }
                        )
                        .accessibilityElement()
                        .accessibilityIdentifier("food-\(item.id)")
                        .accessibilityLabel("Feed \(item.name)")
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
