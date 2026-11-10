import CritterKit
import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    @State private var bubble: String?
    @State private var bubbleToken = UUID()
    @State private var hearts: [HeartBurst] = []
    @State private var floating: [FloatingText] = []
    @State private var strokeDistance: CGFloat = 0
    @State private var lastDragPoint: CGPoint?
    @State private var showFridge = false
    @State private var showAbout = false
    @State private var ballBounce = false
    @State private var petHop = false
    @State private var chomping: String?

    var body: some View {
        DesignCanvas(background: .pinkLight) { size in
            if let pet = store.pet {
                room(pet: pet, layout: RoomLayout(size: size))
            }
        }
        .sheet(isPresented: $showAbout) {
            if let pet = store.pet { AboutPetView(pet: pet, now: store.now) }
        }
    }

    // MARK: Layout

    private func room(pet: Pet, layout: RoomLayout) -> some View {
        let size = layout.size
        let expression = pet.expression(at: store.now)
        return ZStack(alignment: .topLeading) {
            RoomBackdrop(size: size, waterLevel: pet.needs.thirst / 100, foodInBowl: pet.needs.hunger > 50)

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

            if ballBounce {
                SketchView(width: 60, height: 60) { c in
                    c.dot(30, 30, 26, .butter)
                    c.line(.butterDeep, width: 4) { p in
                        p.move(to: CGPoint(x: 4, y: 30)); p.addLine(to: CGPoint(x: 56, y: 30))
                        p.move(to: CGPoint(x: 30, y: 4)); p.addQuadCurve(to: CGPoint(x: 30, y: 56), control: CGPoint(x: 44, y: 30))
                    }
                }
                .frame(width: 60, height: 60)
                .position(x: layout.petCenter.x + 190, y: layout.petCenter.y + 60)
                .transition(.asymmetric(insertion: .offset(x: 200, y: -300), removal: .opacity))
            }

            petView(pet: pet, expression: expression, layout: layout)

            if let chomping {
                ItemArt(id: chomping)
                    .frame(width: 80, height: 80)
                    .position(x: layout.petCenter.x, y: layout.petCenter.y + 30)
                    .transition(.asymmetric(insertion: .offset(y: 200).combined(with: .opacity), removal: .scale(scale: 0.1).combined(with: .opacity)))
            }

            if pet.isAsleep {
                Color.ink.opacity(0.42)
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                ZzzView()
                    .position(x: layout.petCenter.x + 140, y: layout.petCenter.y - 120)
            }

            HeartLayer(hearts: hearts)
            FloatingTextLayer(items: floating)

            if let bubble {
                SpeechBubble(text: bubble)
                    .position(x: layout.petCenter.x + 230, y: layout.petCenter.y - 150)
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
            }

            hud(pet: pet, size: size)
        }
        .frame(width: size.width, height: size.height)
    }

    private func petView(pet: Pet, expression: Mood, layout: RoomLayout) -> some View {
        LiveCritterView(genome: pet.genome, expression: expression, weight: pet.weight)
            .frame(width: 300, height: 300)
            .offset(y: petHop ? -40 : 0)
            .contentShape(Circle())
            .gesture(petting(at: layout))
            .position(layout.petCenter)
            .accessibilityElement()
            .accessibilityLabel("\(pet.name). Stroke to pet.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { stroke(at: layout.petCenter) }
    }

    private func hud(pet: Pet, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
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

            if showFridge {
                FridgeTray(onFeed: feed, onShop: { navigate(.market) })
                    .position(x: size.width / 2, y: size.height - 230)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            dock(pet: pet)
                .position(x: size.width / 2, y: size.height - 72)
        }
    }

    private func dock(pet: Pet) -> some View {
        Dock {
            DockButton(title: "Feed", systemName: "fork.knife", fill: .peachLight, highlighted: showFridge || pet.needs.hunger < 25) {
                withAnimation(.spring) { showFridge.toggle() }
            }
            DockButton(title: "Water", systemName: "drop.fill", fill: .skyLight, highlighted: pet.needs.thirst < 25) { refillWater() }
            DockButton(title: "Play", systemName: "tennisball.fill", fill: .butterLight) { play() }
            DockButton(title: pet.isAsleep ? "Wake" : "Sleep", systemName: pet.isAsleep ? "sun.max.fill" : "moon.zzz.fill", fill: Color(hex: 0xECE4FF), highlighted: pet.needs.energy < 20 && !pet.isAsleep) { toggleSleep() }
            DockButton(title: "Bath", systemName: "bathtub.fill", fill: .mintLight, highlighted: pet.needs.hygiene < 25) { navigate(.bath) }
            DockButton(title: "Park", systemName: "tree.fill", fill: Color(hex: 0xE3F7DC), highlighted: pet.needs.fun < 25) { goOut(.park) }
            DockButton(title: "Shop", systemName: "basket.fill", fill: .pinkLight) { navigate(.market) }
            DockButton(title: "Decor", systemName: "sofa.fill", fill: .lavenderLight) { navigate(.decor) }
            DockButton(title: "Memories", systemName: "heart.text.square.fill", fill: Color(hex: 0xF7F2FF)) { navigate(.memoriam) }
        }
    }

    // MARK: Interactions

    private func petting(at layout: RoomLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = CGPoint(x: layout.petCenter.x - 150 + value.location.x, y: layout.petCenter.y - 150 + value.location.y)
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
                lastDragPoint = nil
                strokeDistance = 0
            }
    }

    private func stroke(at point: CGPoint) {
        guard let pet = store.pet else { return }
        let result = store.perform { state, now in state.pet?.stroke(at: now) } ?? .dead
        switch result {
        case .loved(let gain):
            addHearts(at: point, count: gain > Rules.strokeLove ? 3 : 1)
            say(gain > Rules.strokeLove ? "I missed you!! +\(Int(gain)) love" : "Purrrr… +\(Int(gain)) love")
        case .nowFull:
            addHearts(at: point, count: 4)
            say("Okay, that's enough cuddles!")
        case .ignored:
            say("Hmph. Later.")
        case .asleep:
            say("Zzz… (\(pet.pronounName) is sleeping)")
        case .dead:
            break
        }
    }

    private func poke() {
        guard let pet = store.pet, !pet.isAsleep else { return }
        withAnimation(.spring(duration: 0.25)) { petHop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.3)) { petHop = false }
        }
        let lines = ["Hi!", "Hee hee!", "Boop!", "Pet me!", "What's up?"]
        say(lines.randomElement()!)
    }

    private func feed(_ itemID: String) {
        guard let pet = store.pet else { return }
        guard !pet.isAsleep else { return say("Zzz… (too sleepy to eat)") }
        let result = store.perform { state, now in state.feed(itemID, now: now) }
        withAnimation(.spring) { chomping = itemID }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeIn(duration: 0.3)) { chomping = nil }
        }
        switch result {
        case .yummy: say("Yum yum yum!")
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
        if store.perform({ state, now in state.refillWater(now: now) }) {
            say("Slurp slurp! Ahh.")
        }
    }

    private func play() {
        guard let pet = store.pet else { return }
        if pet.isAsleep { return say("Zzz…") }
        if store.perform({ state, now in state.pet?.play(at: now) ?? false }) {
            withAnimation(.spring(duration: 0.6, bounce: 0.6)) { ballBounce = true }
            withAnimation(.spring(duration: 0.3).delay(0.2)) { petHop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.spring(duration: 0.3)) { petHop = false }
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation { ballBounce = false }
            }
            say("Wheee! Again!")
        } else {
            say("Too tired to play…")
        }
    }

    private func toggleSleep() {
        guard let pet = store.pet else { return }
        if pet.isAsleep {
            store.perform { state, now in state.pet?.wakeUp(at: now) }
            say(pet.needs.energy < 60 ? "Yawn… grumpy…" : "Good morning!")
        } else if store.perform({ state, now in state.pet?.goToSleep(at: now) ?? false }) {
            withAnimation { bubble = nil }
        } else {
            say("I'm not sleepy!")
        }
    }

    private func goOut(_ screen: Screen) {
        guard let pet = store.pet else { return }
        if pet.isAsleep { return toaster.show("Shh, \(pet.pronounName) is sleeping.") }
        if pet.needs.energy < 15 { return toaster.show("\(pet.pronounName) is too tired for the park.") }
        navigate(screen)
    }

    private func giveMedicine() {
        if store.state.count(of: "medicine") == 0 {
            toaster.show("No medicine. Get a feel-good pill at the market!")
        } else if store.perform({ state, now in state.giveMedicine(now: now) }) {
            say("I feel better already!")
        }
    }

    private func scoop(_ poop: Poop, at point: CGPoint) {
        if let coins = store.perform({ state, _ in state.scoop(poop.id) }) {
            floating.append(FloatingText(text: "+\(coins)", point: point))
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
            hearts.removeAll { _ in true }
            floating.removeAll { _ in true }
        }
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

    var body: some View {
        let foods = Catalog.items.filter { $0.foodEffect != nil && store.state.count(of: $0.id) > 0 }
        HStack(spacing: 12) {
            if foods.isEmpty {
                Text("The fridge is empty!").font(.cute(20))
                Button("Go shopping", action: onShop)
                    .buttonStyle(ChunkyButtonStyle())
            } else {
                ForEach(foods) { item in
                    Button { onFeed(item.id) } label: {
                        VStack(spacing: 2) {
                            ItemArt(id: item.id).frame(width: 64, height: 64)
                            Text("\(item.name) ×\(store.state.count(of: item.id))")
                                .font(.cute(14))
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)
                        }
                        .frame(width: 112, height: 100)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0xFFF7EE)))
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel("Feed \(item.name)")
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
