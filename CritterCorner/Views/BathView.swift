import CritterKit
import SwiftUI

private typealias BathStep = BathSession.Step

private extension BathSession.Step {
    var title: String {
        switch self {
        case .fill: "Fyll"
        case .scrub: "Skrubba"
        case .rinse: "Skölj"
        case .dry: "Torka"
        case .done: "Klar"
        }
    }

    var hint: String {
        switch self {
        case .fill: "Vrid på den röda kranen så fylls badkaret."
        case .scrub: "Ta svampen och skrubba bort leran tills det skummar."
        case .rinse: "Vrid på den blå duschkranen och dra duschen fram och tillbaka så sköljs skummet bort."
        case .dry: "Ta handduken och gnugga bort vattendropparna."
        case .done: "Skinande ren och glittrig!"
        }
    }
}

private enum HeldTool {
    case sponge, towel, showerHead
}

/// The bath: fill the tub, scrub the mud off, rinse under the shower, towel dry, then a happy shake.
struct BathView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    @State private var session: BathSession?
    @State private var lastLayout = BathLayout(size: CGSize(width: 1194, height: 834))
    @State private var held: HeldTool?
    @State private var spongePosition: CGPoint?
    @State private var towelPosition: CGPoint?
    @State private var headX: CGFloat = 780
    @State private var tapOpen = false
    @State private var showerOn = false
    @State private var useShampoo = false
    @State private var bubble: String?
    @State private var drain: Double = 1
    @State private var draining = false
    @State private var shaking = false
    @State private var flyingDrops: [FlyingDrop] = []
    @State private var rewarded = false
    @State private var duckHop = false
    @State private var lastSoundAt = Date.distantPast

    private let shadow = Color(hex: 0xA3DCCB)

    var body: some View {
        DesignCanvas(background: .mintLight) { size in
            if let pet = store.pet, let session {
                scene(pet: pet, session: session, layout: BathLayout(size: size))
            }
        }
        .onAppear {
            guard session == nil, let pet = store.pet else { return }
            // Same seed as the everyday look, so the mud in the tub is the mud you saw at home.
            session = BathSession(seed: pet.genome.seed, dirtiness: 1 - pet.needs.hygiene / 100)
        }
        .task { await runLoop() }
    }

    // MARK: Scene

    private func scene(pet: Pet, session: BathSession, layout: BathLayout) -> some View {
        let water = session.water * drain
        let center = layout.petCenter
        let underShower = showerOn && abs(headX - center.x) < 160
        return ZStack(alignment: .topLeading) {
            BathBackdrop(size: layout.size, towelOnRack: session.step != .dry)

            ShowerPipes(layout: layout, headX: headX)
                .allowsHitTesting(false)

            if water > 0.05 {
                Steam(amount: water)
                    .frame(width: 560, height: 200)
                    .position(x: 600, y: layout.tubTop - 140)
            }

            LiveCritterView(
                genome: pet.genome,
                expression: session.step == .done ? .excited : .happy,
                weight: pet.weight,
                look: lookVector(from: center, layout: layout),
                wiggle: shaking || held == .towel,
                blissful: held == .sponge || underShower,
                shine: session.step == .done ? pet.shine(at: store.now) : 0,
                condition: session.step == .done ? .sparkly : (pet.isSick ? .sick : .normal),
                coat: CritterCoat(mud: session.dirt, foam: session.foam, drops: session.drops, shampoo: useShampoo, sickly: pet.isSick),
                style: pet.appearance
            )
            .frame(width: 300, height: 300)
            .position(center)
            .allowsHitTesting(false)

            if water > 0.02 {
                WaterSurface(level: water, foamy: session.step == .scrub || session.step == .rinse, shampoo: useShampoo)
                    .frame(width: 680, height: 60)
                    .position(x: 600, y: layout.tubTop + 6)
                    .allowsHitTesting(false)
            }

            Tub(width: 720)
                .frame(width: 720, height: 170)
                .position(x: 600, y: layout.tubTop + 85)
                .allowsHitTesting(false)

            if draining {
                DrainSwirl()
                    .frame(width: 90, height: 40)
                    .position(x: 760, y: layout.tubTop + 8)
                    .allowsHitTesting(false)
            }

            // Everything you rub or slide goes through this layer; buttons sit above it.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: layout.size.width, height: layout.size.height - 140)
                .position(x: layout.size.width / 2, y: (layout.size.height - 140) / 2 + 100)
                .gesture(toolGesture(layout: layout))

            if water > 0.3 {
                Button { squeakDuck() } label: {
                    RubberDuck().frame(width: 90, height: 70)
                }
                .buttonStyle(.plain)
                .bobbing(amount: 4)
                .offset(y: duckHop ? -40 : 0)
                .position(x: 880, y: layout.tubTop - 16)
                .accessibilityLabel("Badanka")
            }

            FaucetView(open: tapOpen, waterTop: layout.tubTop + 6 - CGFloat(water) * 12, layout: layout, hint: session.step == .fill && !tapOpen) {
                turnTap()
            }

            ShowerWater(on: showerOn, headX: headX, top: layout.showerHeadY + 34, bottom: layout.tubTop + 10)
                .allowsHitTesting(false)

            ShowerHeadView(showerOn: showerOn, grabbed: held == .showerHead, hint: session.step == .rinse && showerOn && held == nil)
                .frame(width: 110, height: 90)
                .position(x: headX, y: layout.showerHeadY)
                .allowsHitTesting(false)

            ValveButton(on: showerOn, color: .skyDeep, identifier: "shower", label: "Duschkran", hint: session.step == .rinse && !showerOn) {
                toggleShower()
            }
            .position(layout.showerValve)

            tools(session: session, layout: layout)

            ForEach(flyingDrops) { drop in
                FlyingDropView(drop: drop)
            }

            if let bubble {
                SpeechBubble(text: bubble, tailOnLeft: true)
                    .position(x: center.x + 250, y: center.y - 170)
                    .allowsHitTesting(false)
            }

            hud(session: session, layout: layout)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .coordinateSpace(.named("bath"))
        .onAppear { lastLayout = layout }
        .onChange(of: layout.size) { _, _ in lastLayout = layout }
    }

    @ViewBuilder
    private func tools(session: BathSession, layout: BathLayout) -> some View {
        if session.step == .scrub {
            let position = spongePosition ?? layout.spongeRest
            Sponge(shampoo: useShampoo, scrubbing: held == .sponge)
                .frame(width: 110, height: 76)
                .overlay { if held == nil { HintRing() } }
                .position(position)
                .allowsHitTesting(false)
        }
        if session.step == .dry || towelPosition != nil {
            let position = towelPosition ?? layout.towelRest
            if session.step == .dry {
                RubbingTowel(rubbing: held == .towel)
                    .frame(width: 150, height: 110)
                    .overlay { if held == nil { HintRing() } }
                    .position(position)
                    .allowsHitTesting(false)
            }
        }
    }

    private func hud(session: BathSession, layout: BathLayout) -> some View {
        let size = layout.size
        return ZStack(alignment: .topLeading) {
            HStack {
                RoundIconButton(systemName: "chevron.left", label: "Tillbaka hem", shadow: shadow) { navigate(.home) }
                Spacer()
                HStack(spacing: 8) {
                    ForEach(BathStep.allCases.dropLast(), id: \.self) { candidate in
                        Text("\(candidate.rawValue + 1) \(candidate.title)")
                            .font(.cute(17))
                            .foregroundStyle(candidate == session.step ? .white : (candidate.rawValue < session.step.rawValue ? Color.ink : Color.inkSoft))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(candidate == session.step ? Color.ink : (candidate.rawValue < session.step.rawValue ? Color.mintLight : .clear)))
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
                Text("Glittermätare").font(.cute(18, .bold))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: 0xEAF3F0))
                        Capsule().fill(Color.mint).frame(width: max(16, geo.size.width * session.overallProgress))
                            .animation(.spring, value: session.overallProgress)
                    }
                }
                .frame(height: 16)
                Text(session.step.hint).font(.cute(15, .medium)).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                if session.step == .scrub {
                    Toggle(isOn: Binding(get: { useShampoo }, set: { toggleShampoo($0) })) {
                        Text("Schampo ×\(store.state.count(of: "shampoo"))").font(.cute(15))
                    }
                    .tint(.lavenderDeep)
                }
                Text("+\(Rules.bathReward) mynt när sötisen glittrar").font(.cute(15)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Color.butterLight))
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .frame(width: 210)
            .card(shadow: shadow)
            .position(x: 24 + 105, y: size.height * 0.36)

            if session.step == .done {
                Button("Skinande ren! Gå hem") { navigate(.home) }
                    .buttonStyle(ChunkyButtonStyle())
                    .position(x: size.width / 2, y: size.height - 64)
            }
        }
    }

    private func lookVector(from center: CGPoint, layout: BathLayout) -> CGVector {
        let target: CGPoint? = switch held {
        case .sponge: spongePosition
        case .towel: towelPosition
        case .showerHead: CGPoint(x: headX, y: layout.showerHeadY)
        case nil: showerOn ? CGPoint(x: headX, y: layout.showerHeadY) : (tapOpen ? layout.faucetSpout : nil)
        }
        guard let target else { return .zero }
        return CGVector(dx: max(-1, min(1, (target.x - center.x) / 220)), dy: max(-1, min(1, (target.y - center.y + 30) / 220)))
    }

    // MARK: Interaction

    private func toolGesture(layout: BathLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("bath"))
            .onChanged { value in
                guard var session else { return }
                if held == nil {
                    held = pickUp(at: value.startLocation, step: session.step, layout: layout)
                    if held != nil { Haptics.tap() }
                }
                let point = value.location
                switch held {
                case .sponge:
                    spongePosition = point
                    let local = layout.petPoint(point)
                    if session.scrub(at: local.x, local.y) {
                        playThrottled(.pop, every: 0.18)
                        Haptics.soft()
                    }
                case .towel:
                    towelPosition = point
                    let local = layout.petPoint(point)
                    session.dry(at: local.x, local.y)
                    playThrottled(.boop, every: 0.5)
                case .showerHead:
                    headX = min(layout.railRange.upperBound, max(layout.railRange.lowerBound, point.x))
                case nil:
                    break
                }
                self.session = session
            }
            .onEnded { _ in held = nil }
    }

    private func pickUp(at point: CGPoint, step: BathStep, layout: BathLayout) -> HeldTool? {
        func near(_ target: CGPoint, _ reach: CGFloat) -> Bool { hypot(point.x - target.x, point.y - target.y) < reach }
        switch step {
        case .scrub where near(spongePosition ?? layout.spongeRest, 110):
            return .sponge
        case .dry where near(towelPosition ?? layout.towelRest, 120):
            return .towel
        case .rinse where near(CGPoint(x: headX, y: layout.showerHeadY), 110):
            return .showerHead
        default:
            if step == .scrub || step == .dry { say(step == .scrub ? "Ta svampen!" : "Ta handduken!") }
            return nil
        }
    }

    private func turnTap() {
        guard let session else { return }
        guard session.step == .fill else { return say(session.water >= 1 ? "Badkaret är fullt!" : "Hmm?") }
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { tapOpen = true }
        self.session?.turnOnTap()
        SoundFX.play(.splash)
        Haptics.thump()
        say("Åh, varmt vatten!")
    }

    private func toggleShower() {
        guard let session else { return }
        guard session.step == .rinse || showerOn else {
            return say(session.step.rawValue < BathStep.rinse.rawValue ? "Inte än, jag är ju lerig!" : "Jag är redan sköljd!")
        }
        Haptics.thump()
        SoundFX.play(.splash)
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showerOn.toggle() }
        if showerOn { say(store.pet?.genome.has(.lovesBaths) == true ? "Wiii, regn!" : "Iiih! Vatten!") }
    }

    private func squeakDuck() {
        SoundFX.play(.squeak)
        Haptics.tap()
        withAnimation(.spring(duration: 0.2)) { duckHop = true }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(duration: 0.4, bounce: 0.6)) { duckHop = false }
        }
    }

    private func toggleShampoo(_ on: Bool) {
        if !on { useShampoo = false; return }
        if store.state.count(of: "shampoo") > 0 {
            useShampoo = true
            say("Bubbelschampo!")
        } else {
            toaster.show("Inget schampo. Det finns bland badsakerna i affären.")
        }
    }

    private func runLoop() async {
        var last = Date()
        var previousStep = session?.step
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(33))
            let now = Date()
            let dt = min(0.1, now.timeIntervalSince(last))
            last = now
            guard var session else { continue }
            if session.isFilling {
                if session.update(dt) {
                    withAnimation(.spring(duration: 0.5, bounce: 0.3)) { tapOpen = false }
                }
                playThrottled(.splash, every: 0.6)
            }
            if showerOn {
                playThrottled(.splash, every: 0.4)
                if session.step == .rinse {
                    session.rinse(atX: lastLayout.petPoint(CGPoint(x: headX, y: 0)).x, dt: dt)
                }
            }
            self.session = session
            if session.step != previousStep {
                previousStep = session.step
                stepChanged(to: session.step)
            }
        }
    }

    private func stepChanged(to step: BathStep) {
        Haptics.success()
        held = nil
        switch step {
        case .scrub:
            say("Skrubbe-dubbe-dubb!")
        case .rinse:
            SoundFX.play(.giggle)
            say("Så skummigt! Nu duschen!")
        case .dry:
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showerOn = false }
            say(store.pet?.genome.has(.lovesBaths) == true ? "Vad kul! Handduk, tack!" : "Brrr! Handduk, tack!")
        case .done:
            finish()
        case .fill:
            break
        }
    }

    private func finish() {
        guard !rewarded else { return }
        rewarded = true
        let coins = store.perform { state, now in state.finishBath(useShampoo: useShampoo, now: now) }
        SoundFX.play(.coin)
        shaking = true
        flyingDrops = (0..<18).map { _ in FlyingDrop(start: lastLayout.petCenter) }
        say("*skak skak skak*")
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            shaking = false
            towelPosition = nil
            say(useShampoo ? "Extraglittrig!! Kolla hur jag glänser!" : "Kolla så blank jag är!")
            SoundFX.play(.bounce)
            draining = true
            withAnimation(.easeIn(duration: 2.2)) { drain = 0 }
            try? await Task.sleep(for: .seconds(1))
            flyingDrops = []
            try? await Task.sleep(for: .seconds(1.3))
            draining = false
        }
        toaster.show("Badet är klart: +\(coins) mynt!")
    }

    private func playThrottled(_ effect: SoundFX.Effect, every seconds: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastSoundAt) > seconds else { return }
        lastSoundAt = now
        SoundFX.play(effect)
    }

    private func say(_ text: String) {
        withAnimation(.spring) { bubble = text }
    }
}

// MARK: - Layout

private struct BathLayout {
    let size: CGSize
    var tubTop: CGFloat { size.height * 0.64 }
    var petCenter: CGPoint { CGPoint(x: 600, y: tubTop - 70) }
    var faucetPipeX: CGFloat { 268 }
    var faucetSpout: CGPoint { CGPoint(x: 352, y: tubTop - 92) }
    var faucetValve: CGPoint { CGPoint(x: 268, y: tubTop - 150) }
    var showerPipeX: CGFloat { 1000 }
    var showerArmY: CGFloat { 120 }
    var showerHeadY: CGFloat { 170 }
    var showerValve: CGPoint { CGPoint(x: 1000, y: tubTop - 170) }
    var railRange: ClosedRange<CGFloat> { 360...930 }
    var spongeRest: CGPoint { CGPoint(x: 460, y: tubTop - 14) }
    var towelRest: CGPoint { CGPoint(x: 1080, y: 300) }

    /// Converts a scene point into the critter's normalised 0...1 frame.
    func petPoint(_ point: CGPoint) -> (x: Double, y: Double) {
        (Double((point.x - (petCenter.x - 150)) / 300), Double((point.y - (petCenter.y - 150)) / 300))
    }
}

// MARK: - Plumbing

private let chrome = Color(hex: 0xC9D3DA)
private let chromeShade = Color(hex: 0x9FAEB8)

/// The wall pipes: a riser from the floor behind the tub up to a rail over the tub, which holds the shower head.
private struct ShowerPipes: View {
    let layout: BathLayout
    let headX: CGFloat

    var body: some View {
        Canvas { c, _ in
            let x = layout.showerPipeX
            let arm = layout.showerArmY
            c.box(x - 12, arm, 24, layout.tubTop + 60 - arm, radius: 12, chrome)
            c.box(x - 6, arm + 10, 6, layout.tubTop + 40 - arm, radius: 3, .white.opacity(0.45))
            c.box(layout.railRange.lowerBound - 30, arm - 10, x - layout.railRange.lowerBound + 42, 20, radius: 10, chrome)
            c.box(layout.railRange.lowerBound - 24, arm - 6, x - layout.railRange.lowerBound + 30, 5, radius: 2.5, .white.opacity(0.5))
            c.dot(x, arm, 18, chromeShade)
            c.dot(x, arm, 11, chrome)
            for bracket in [layout.railRange.lowerBound - 10, (layout.railRange.lowerBound + x) / 2] {
                c.box(bracket - 8, arm - 40, 16, 34, radius: 6, chromeShade)
            }
            // The head's slider on the rail.
            c.box(headX - 18, arm - 14, 36, 28, radius: 10, chromeShade)
            c.box(headX - 6, arm + 10, 12, layout.showerHeadY - arm - 20, radius: 6, chrome)
            // Faucet riser on the left of the tub.
            c.box(layout.faucetPipeX - 13, layout.faucetValve.y, 26, layout.tubTop + 50 - layout.faucetValve.y, radius: 13, chrome)
            c.box(layout.faucetPipeX - 13, layout.faucetSpout.y - 13, layout.faucetSpout.x - layout.faucetPipeX + 10, 26, radius: 13, chrome)
            c.box(layout.faucetSpout.x - 14, layout.faucetSpout.y - 6, 26, 26, radius: 9, chrome)
            c.box(layout.faucetSpout.x - 16, layout.faucetSpout.y + 14, 30, 10, radius: 5, chromeShade)
            c.box(layout.faucetPipeX - 7, layout.faucetSpout.y - 8, layout.faucetSpout.x - layout.faucetPipeX - 4, 5, radius: 2.5, .white.opacity(0.55))
        }
    }
}

/// A round tap handle that turns when you tap it.
private struct ValveButton: View {
    let on: Bool
    let color: Color
    let identifier: String
    let label: String
    let hint: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(chromeShade).frame(width: 30, height: 30)
                ZStack {
                    Capsule().fill(color).frame(width: 74, height: 20)
                    Capsule().fill(color).frame(width: 20, height: 74)
                    Circle().fill(color).frame(width: 34, height: 34)
                    Circle().fill(.white.opacity(0.7)).frame(width: 12, height: 12)
                }
                .rotationEffect(.degrees(on ? 90 : 0))
            }
            .frame(width: 90, height: 90)
            .overlay { if hint { HintRing() } }
            .contentShape(Circle())
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "På" : "Av")
    }
}

private struct FaucetView: View {
    let open: Bool
    let waterTop: CGFloat
    let layout: BathLayout
    let hint: Bool
    let action: () -> Void

    var body: some View {
        let spout = layout.faucetSpout
        let streamTop = spout.y + 24
        let length = max(10, waterTop - streamTop)
        ZStack(alignment: .topLeading) {
            FlowingStream(width: 16)
                .frame(width: 16, height: length)
                .mask(alignment: .top) {
                    Rectangle().frame(height: open ? length : 0)
                }
                .position(x: spout.x, y: streamTop + length / 2)
                .allowsHitTesting(false)

            if open {
                Splash()
                    .frame(width: 70, height: 30)
                    .position(x: spout.x, y: waterTop)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            ValveButton(on: open, color: .coral, identifier: "tap", label: "Badkran", hint: hint, action: action)
                .position(layout.faucetValve)
        }
        .animation(.easeOut(duration: 0.45), value: open)
    }
}

/// A column of falling water with drops sliding down it.
private struct FlowingStream: View {
    let width: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                c.box(0, 0, size.width, size.height, radius: size.width / 2, Color.sky.opacity(0.8))
                let phase = CGFloat((t * 2.2).truncatingRemainder(dividingBy: 1))
                for i in 0..<Int(size.height / 30) + 2 {
                    let y = (CGFloat(i) + phase) * 30 - 20
                    c.box(size.width * 0.3, y, size.width * 0.3, 14, radius: 3, .white.opacity(0.85))
                }
            }
        }
    }
}

private struct Splash: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                for i in 0..<6 {
                    let phase = (t * 2.5 + Double(i) / 6).truncatingRemainder(dividingBy: 1)
                    let side: CGFloat = i.isMultiple(of: 2) ? 1 : -1
                    let x = size.width / 2 + side * CGFloat(phase) * size.width * 0.45
                    let y = size.height * 0.7 - CGFloat(sin(phase * .pi)) * size.height * 0.7
                    c.dot(x, y, 4 * CGFloat(1 - phase) + 1.5, .white.opacity(0.9))
                }
                c.oval(size.width / 2, size.height * 0.8, size.width * 0.35, 5, .white.opacity(0.6))
            }
        }
    }
}

private struct ShowerHeadView: View {
    let showerOn: Bool
    let grabbed: Bool
    let hint: Bool

    var body: some View {
        SketchView(width: 110, height: 90) { c in
            c.shape(chrome) { p in
                p.move(to: CGPoint(x: 40, y: 20))
                p.addLine(to: CGPoint(x: 70, y: 20))
                p.addLine(to: CGPoint(x: 96, y: 56))
                p.addLine(to: CGPoint(x: 14, y: 56))
                p.closeSubpath()
            }
            c.oval(55, 58, 44, 12, chromeShade)
            c.box(44, 0, 22, 24, radius: 8, chromeShade)
            for x in stride(from: 25.0, through: 85, by: 10) { c.dot(x, 60, 2.6, Color(hex: 0x6F7E88)) }
            c.box(30, 26, 40, 5, radius: 2.5, .white.opacity(0.55))
        }
        .scaleEffect(grabbed ? 1.08 : 1)
        .overlay { if hint { HintRing() } }
        .animation(.spring(duration: 0.25), value: grabbed)
    }
}

/// Rain from the shower head, growing down when turned on and draining away when turned off.
private struct ShowerWater: View {
    let on: Bool
    let headX: CGFloat
    let top: CGFloat
    let bottom: CGFloat

    var body: some View {
        let height = bottom - top
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                for i in 0..<9 {
                    let spread = CGFloat(i - 4)
                    let startX = size.width / 2 + spread * 8
                    let endX = size.width / 2 + spread * 17
                    c.outline(
                        Path { p in p.move(to: CGPoint(x: startX, y: 0)); p.addLine(to: CGPoint(x: endX, y: size.height)) },
                        Color.sky.opacity(0.55),
                        width: 3
                    )
                    for k in 0..<3 {
                        let fall = CGFloat((t * 1.8 + Double(i) * 0.11 + Double(k) / 3).truncatingRemainder(dividingBy: 1))
                        c.box(startX + (endX - startX) * fall - 2, size.height * fall, 4, 16, radius: 2, .white.opacity(0.9))
                    }
                }
            }
        }
        .frame(width: 200, height: height)
        .mask(alignment: .top) {
            Rectangle().frame(height: on ? height : 0)
        }
        .animation(.easeOut(duration: on ? 0.5 : 0.35), value: on)
        .position(x: headX, y: top + height / 2)
    }
}

private struct DrainSwirl: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                for ring in 0..<3 {
                    let r = CGFloat(ring + 1) * 12
                    let start = Angle.radians(t * 5 + Double(ring))
                    c.outline(
                        Path { p in p.addArc(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: r, startAngle: start, endAngle: start + .degrees(220), clockwise: false) }
                            .applying(CGAffineTransform(translationX: 0, y: size.height / 2).scaledBy(x: 1, y: 0.4).translatedBy(x: 0, y: -size.height / 2)),
                        Color.skyDeep.opacity(0.7),
                        width: 3
                    )
                }
            }
        }
    }
}

/// A gently pulsing ring that says "touch me".
private struct HintRing: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .strokeBorder(Color.butterDeep, lineWidth: 4)
            .frame(width: 110, height: 110)
            .scaleEffect(pulse ? 1.15 : 0.9)
            .opacity(pulse ? 0.2 : 0.9)
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
            .allowsHitTesting(false)
    }
}

private extension View {
    func bobbing(amount: CGFloat) -> some View {
        modifier(Bobbing(amount: amount))
    }
}

private struct Bobbing: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            content
                .offset(y: sin(t * 2.2) * amount)
                .rotationEffect(.degrees(sin(t * 1.7) * 5))
        }
    }
}

// MARK: - Pieces

private struct WaterSurface: View {
    let level: Double
    let foamy: Bool
    let shampoo: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                let top = size.height * (1 - CGFloat(level)) * 0.7
                c.shape(Color.sky.opacity(0.55)) { p in
                    p.move(to: CGPoint(x: 0, y: size.height))
                    p.addLine(to: CGPoint(x: 0, y: top))
                    for x in stride(from: 0.0, through: size.width, by: 20) {
                        p.addLine(to: CGPoint(x: x, y: top + sin(x / 40 + t * 3) * 3))
                    }
                    p.addLine(to: CGPoint(x: size.width, y: size.height))
                    p.closeSubpath()
                }
                c.line(.white.opacity(0.7), width: 3) { p in
                    for x in stride(from: 40.0, to: size.width - 40, by: 90) {
                        let y = top + 10 + sin(x + t * 2) * 2
                        p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 30, y: y))
                    }
                }
                if foamy {
                    for i in 0..<18 {
                        let x = 20 + Double(i) * (size.width - 40) / 17
                        let r = 10 + 6 * sin(Double(i) * 1.7 + t)
                        c.dot(x, top + 2, r, (shampoo ? Color(hex: 0xF1E6FF) : .white).opacity(0.9))
                    }
                }
            }
        }
    }
}

private struct Steam: View {
    let amount: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { c, size in
                for i in 0..<4 {
                    let phase = (t * 0.35 + Double(i) * 0.27).truncatingRemainder(dividingBy: 1)
                    let baseX = size.width * (0.15 + 0.23 * Double(i))
                    let y = size.height * (1 - phase)
                    c.line(.white.opacity(0.5 * amount * sin(phase * .pi)), width: 6) { p in
                        p.move(to: CGPoint(x: baseX, y: y + 50))
                        p.addCurve(to: CGPoint(x: baseX, y: y - 30), control1: CGPoint(x: baseX + 18, y: y + 25), control2: CGPoint(x: baseX - 18, y: y - 5))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Sponge: View {
    let shampoo: Bool
    let scrubbing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let squish = scrubbing ? sin(timeline.date.timeIntervalSinceReferenceDate * 14) * 0.08 : 0
            SketchView(width: 110, height: 76) { c in
                c.box(5, 18, 100, 54, radius: 18, .butter)
                c.box(5, 8, 100, 24, radius: 12, .leaf)
                for (x, y, r) in [(28.0, 48.0, 5.0), (54, 58, 4), (80, 46, 5), (92, 62, 3), (40, 62, 3)] {
                    c.dot(x, y, r, .butterDeep)
                }
                if shampoo || scrubbing {
                    c.dot(20, 10, 9, shampoo ? Color(hex: 0xF1E6FF) : .white)
                    c.dot(34, 4, 7, .white)
                    c.dot(92, 8, 6, .white)
                }
            }
            .scaleEffect(x: 1 + squish, y: 1 - squish)
            .rotationEffect(.degrees(scrubbing ? 12 : -8))
        }
    }
}

private struct RubbingTowel: View {
    let rubbing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let swing = rubbing ? sin(timeline.date.timeIntervalSinceReferenceDate * 12) * 9 : 0
            SketchView(width: 150, height: 110) { c in
                c.box(0, 0, 150, 110, radius: 22, .pink)
                c.line(.white, width: 6, dash: [12, 10]) { p in
                    p.move(to: CGPoint(x: 10, y: 84)); p.addLine(to: CGPoint(x: 140, y: 84))
                }
                c.box(0, 0, 150, 18, radius: 9, Color(hex: 0xF27D9B))
            }
            .rotationEffect(.degrees(swing - (rubbing ? 6 : 0)))
        }
    }
}

private struct RubberDuck: View {
    var body: some View {
        SketchView(width: 90, height: 70) { c in
            c.oval(40, 46, 34, 20, .butter)
            c.dot(60, 24, 18, .butter)
            c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: 74, y: 24), CGPoint(x: 90, y: 28), CGPoint(x: 74, y: 34)]) }
            c.dot(64, 20, 3, .ink)
            c.oval(30, 40, 14, 8, .butterDeep)
        }
    }
}

private struct FlyingDrop: Identifiable {
    let id = UUID()
    let start: CGPoint
    let angle = Double.random(in: -.pi ... 0)
    let distance = CGFloat.random(in: 160...320)
}

private struct FlyingDropView: View {
    let drop: FlyingDrop
    @State private var flown = false

    var body: some View {
        Circle()
            .fill(Color.sky)
            .overlay(Circle().fill(.white.opacity(0.7)).frame(width: 5, height: 5).offset(x: -3, y: -3))
            .frame(width: 16, height: 16)
            .position(drop.start)
            .offset(x: flown ? cos(drop.angle) * drop.distance : 0, y: flown ? sin(drop.angle) * drop.distance + 80 : 0)
            .opacity(flown ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { flown = true } }
            .allowsHitTesting(false)
    }
}

private struct Tub: View {
    let width: CGFloat

    var body: some View {
        Canvas { c, size in
            let w = size.width
            c.shape(.white) { p in
                p.move(to: CGPoint(x: 20, y: 20))
                p.addLine(to: CGPoint(x: w - 20, y: 20))
                p.addLine(to: CGPoint(x: w - 20, y: 70))
                p.addQuadCurve(to: CGPoint(x: w - 130, y: 160), control: CGPoint(x: w - 20, y: 160))
                p.addLine(to: CGPoint(x: 130, y: 160))
                p.addQuadCurve(to: CGPoint(x: 20, y: 70), control: CGPoint(x: 20, y: 160))
                p.closeSubpath()
            }
            c.box(60, 50, w - 120, 10, radius: 5, Color(hex: 0xEAF6FF))
            c.box(0, 0, w, 34, radius: 17, .white)
            c.outline(Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: 34), cornerRadius: 17), Color(hex: 0xD6ECFF), width: 4)
            c.box(60, 150, 40, 20, radius: 10, .butterDeep)
            c.box(w - 100, 150, 40, 20, radius: 10, .butterDeep)
        }
    }
}

private struct BathBackdrop: View {
    let size: CGSize
    let towelOnRack: Bool

    var body: some View {
        Canvas { c, _ in
            let floorTop = size.height * 0.74
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
            c.box(80, floorTop + 40, 220, 70, radius: 35, Color(hex: 0xFFD1DC))
            // Towel rack.
            c.box(1010, 240, 150, 10, radius: 5, .wood)
            if towelOnRack {
                c.shape(.pink) { p in
                    p.move(to: CGPoint(x: 1035, y: 250)); p.addLine(to: CGPoint(x: 1125, y: 250)); p.addLine(to: CGPoint(x: 1125, y: 390))
                    p.addQuadCurve(to: CGPoint(x: 1035, y: 390), control: CGPoint(x: 1080, y: 408)); p.closeSubpath()
                }
                c.line(.white, width: 6, dash: [10, 10]) { p in p.move(to: CGPoint(x: 1035, y: 360)); p.addLine(to: CGPoint(x: 1125, y: 360)) }
            }
            // Little shelf with bottles.
            c.box(60, 560, 140, 10, radius: 5, .wood)
            c.box(78, 520, 24, 40, radius: 8, .lavender)
            c.box(113, 530, 20, 30, radius: 7, .pink)
            c.box(145, 516, 22, 44, radius: 8, .mint)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
