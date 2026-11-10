import CritterKit
import SwiftUI

/// What's on the critter's coat: mud, bath foam, water drops, and a sickly tint.
/// Everything is painted onto the body itself, clipped to its outline, so it moves and squashes with it.
struct CritterCoat: Equatable {
    var mud: [BathSession.Mark] = []
    var foam: [BathSession.Mark] = []
    var drops: [BathSession.Mark] = []
    var shampoo = false
    var sickly = false

    /// The everyday look: mud builds up as hygiene drops, in the same spots the bath will find.
    static func everyday(for pet: Pet) -> CritterCoat {
        var coat = CritterCoat(sickly: pet.isSick)
        let grime = pet.grime
        if grime > 0 {
            coat.mud = BathSession(seed: pet.genome.seed, dirtiness: 1 - pet.needs.hygiene / 100).dirt.map { spot in
                var faded = spot
                faded.amount = spot.amount * min(1, 0.35 + grime)
                return faded
            }
        }
        return coat
    }
}

/// Draws a critter from its genome in a 200×200 design space, mirroring the mockup SVGs.
struct CritterView: View {
    let genome: Genome
    var expression: Mood = .content
    var weight: Double = Rules.healthyWeight
    var blinking = false
    var halo = false
    /// Where the eyes look, -1...1 on each axis.
    var look: CGVector = .zero
    /// Eyes squeezed shut with joy, e.g. while being petted.
    var blissful = false
    /// 0...1 glossy coat after a bath.
    var shine: Double = 0
    var coat = CritterCoat()

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 200, y: size.height / 200)
            CritterPainter(genome: genome, expression: expression, weight: weight, blinking: blinking || blissful, halo: halo, look: look, shine: shine, coat: coat, context: context).paint()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("A \(genome.palette.name.lowercased()) critter"))
    }
}

/// Breathing, blinking and bouncing on top of `CritterView`.
struct LiveCritterView: View {
    let genome: Genome
    var expression: Mood = .content
    var weight: Double = Rules.healthyWeight
    var halo = false
    var walking = false
    var facingRight = true
    var look: CGVector = .zero
    /// Extra tilt in degrees, e.g. leaning into a pat.
    var lean: Double = 0
    var wiggle = false
    var blissful = false
    /// 0...1 after a bath: a glossy coat and twinkling sparkles.
    var shine: Double = 0
    var condition: Condition = .normal
    var coat = CritterCoat()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = Double(genome.seed % 1000) / 160
            let dying = condition == .dying
            let breath = 1 + (dying ? 0.012 * sin(t * 1.1 + phase) : 0.025 * sin(t * 2.2 + phase))
            let shiver = condition == .sick ? sin(t * 31) * 1.2 : 0
            let blinkCycle = (t + phase).truncatingRemainder(dividingBy: 4.2)
            let bounce: Double = switch expression {
            case .excited: -abs(sin(t * 6)) * 18
            case .happy: -abs(sin(t * 2.5)) * 4
            default: 0
            }
            let step = walking ? -abs(sin(t * 11)) * 12 : 0
            let waddle = walking ? sin(t * 11) * 4 : 0
            let giggle = wiggle ? sin(t * 40) * 7 : 0
            let sway: Double = (expression == .ignoring ? -6 : sin(t * 1.3 + phase) * 1.5) + waddle + giggle + lean
            let eyes = CGVector(dx: facingRight ? look.dx : -look.dx, dy: look.dy)
            CritterView(genome: genome, expression: expression, weight: weight, blinking: blinkCycle < 0.14 || (dying && blinkCycle < 1.4), halo: halo, look: eyes, blissful: blissful, shine: shine, coat: coat)
                .saturation(dying ? 0.3 : (condition == .sick ? 0.75 : 1))
                .opacity(dying ? 0.9 : 1)
                .scaleEffect(x: (2 - breath) * (facingRight ? 1 : -1), y: breath * (dying ? 0.95 : 1), anchor: .bottom)
                .rotationEffect(.degrees(sway + (dying ? 4 : 0)), anchor: .bottom)
                .offset(x: shiver)
                .overlay {
                    if shine > 0.02 { Twinkles(time: t, amount: shine, girth: weight) }
                    if condition == .filthy { Flies(time: t) }
                    if condition == .filthy || condition == .dirty { Stink(time: t, strong: condition == .filthy) }
                }
                .offset(y: bounce + step)
        }
    }
}

/// Little flies buzzing around a filthy critter.
private struct Flies: View {
    let time: TimeInterval

    var body: some View {
        Canvas { c, size in
            for i in 0..<3 {
                let speed = 2.4 + Double(i) * 0.7
                let angle = time * speed + Double(i) * 2.1
                let x = size.width * (0.5 + cos(angle) * (0.32 + 0.06 * Double(i)))
                let y = size.height * (0.32 + sin(angle * 1.7) * 0.12 + Double(i) * 0.05)
                let flap = abs(sin(time * 40 + Double(i)))
                c.oval(x - 4, y - 5, 5, 3 + 2 * flap, .white.opacity(0.8))
                c.oval(x + 4, y - 5, 5, 3 + 2 * flap, .white.opacity(0.8))
                c.dot(x, y, 4, .ink)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Wavy smell lines rising off a dirty critter.
private struct Stink: View {
    let time: TimeInterval
    let strong: Bool

    var body: some View {
        Canvas { c, size in
            for i in 0..<(strong ? 3 : 2) {
                let x = size.width * (0.3 + 0.2 * Double(i))
                let phase = (time * 0.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                let y = size.height * (0.3 - 0.18 * phase)
                c.line(Color(hex: 0x9AB87A).opacity((strong ? 0.8 : 0.5) * sin(phase * .pi)), width: 4) { p in
                    p.move(to: CGPoint(x: x, y: y + 30))
                    p.addCurve(to: CGPoint(x: x, y: y - 20), control1: CGPoint(x: x + 14, y: y + 14), control2: CGPoint(x: x - 14, y: y - 4))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Twinkling stars around a freshly bathed critter.
private struct Twinkles: View {
    let time: TimeInterval
    let amount: Double
    let girth: Double

    var body: some View {
        Canvas { c, size in
            let count = 3 + Int(amount * 7)
            let width = 0.34 + (girth / 100) * 0.16
            let colors: [Color] = [.white, .butter, .white, .sky, .pink]
            for i in 0..<count {
                let angle = Double(i) * 2.399 + 0.6
                let twinkle = max(0, sin(time * 2.6 + Double(i) * 1.9))
                guard twinkle > 0.05 else { continue }
                let x = size.width * (0.5 + cos(angle) * width)
                let y = size.height * (0.56 + sin(angle) * 0.34)
                let r = size.width * (0.025 + 0.035 * twinkle) * (0.6 + 0.4 * amount)
                c.sparkle(x, y, r, colors[i % colors.count].opacity(min(1, amount * 1.6) * twinkle))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Small seeded quirks that make each critter its own little character.
private struct Quirks {
    let eyeSpacing: CGFloat
    let eyeSize: CGFloat
    let nose: Int
    let pattern: Int
    let earJitter: Double
    let tuft: Bool
    let toothy: Bool

    init(seed: UInt64) {
        var rng = SeededRandom(seed: seed ^ 0x7E57_ABCD_0042_1337)
        eyeSpacing = .random(in: 24...32, using: &rng)
        eyeSize = .random(in: 5.5...7.5, using: &rng)
        nose = .random(in: 0...2, using: &rng)
        pattern = .random(in: 0...4, using: &rng)
        earJitter = .random(in: -14...14, using: &rng)
        tuft = Bool.random(using: &rng)
        toothy = Int.random(in: 0..<3, using: &rng) == 0
    }
}

private struct CritterPainter {
    let genome: Genome
    let expression: Mood
    let weight: Double
    let blinking: Bool
    let halo: Bool
    let look: CGVector
    let shine: Double
    let coat: CritterCoat
    var context: GraphicsContext

    private var body: Color { Color(hex: genome.palette.body) }
    private var belly: Color { Color(hex: genome.palette.belly) }
    private var shade: Color { Color(hex: genome.palette.shade) }
    /// Body width factor: thin critters are narrow, chubby ones wide.
    private var girth: CGFloat { 0.62 + CGFloat(min(max(weight, 0), 100)) / 100 * 0.76 }
    private var spread: CGFloat { 0.8 + 0.2 * girth }
    private var quirks: Quirks { Quirks(seed: genome.seed) }

    func paint() {
        ellipse(100, 186, 56 * girth, 8, .ink, opacity: 0.1)
        if halo { wings() }
        tail()
        if genome.head != .sprout && genome.head != .antennae { headFeature() }
        feet()
        torso()
        arms()
        if genome.head == .sprout || genome.head == .antennae { headFeature() } else if quirks.tuft { tuft() }
        eyes()
        cheeks()
        nose()
        mouth()
        if coat.sickly { sickExtras() }
        if halo {
            var ring = Path(ellipseIn: CGRect(x: 66, y: 12, width: 68, height: 18))
            ring = ring.strokedPath(StrokeStyle(lineWidth: 6))
            context.fill(ring, with: .color(.butterDeep))
        }
    }

    // MARK: Parts

    private func wings() {
        ellipse(100 - 66 * girth, 112, 30, 18, .white, rotation: -30)
        ellipse(100 + 66 * girth, 112, 30, 18, .white, rotation: 30)
    }

    private func tail() {
        let dx = 50 * (girth - 1)
        switch genome.tail {
        case .none:
            break
        case .lightning:
            var path = Path()
            path.move(to: CGPoint(x: 150 + dx, y: 150))
            path.addLine(to: CGPoint(x: 168 + dx, y: 136))
            path.addLine(to: CGPoint(x: 160 + dx, y: 130))
            path.addLine(to: CGPoint(x: 178 + dx, y: 114))
            stroke(path, shade, width: 10)
        case .fin:
            var path = Path()
            path.move(to: CGPoint(x: 156 + dx, y: 160))
            path.addQuadCurve(to: CGPoint(x: 188 + dx, y: 132), control: CGPoint(x: 182 + dx, y: 154))
            path.addQuadCurve(to: CGPoint(x: 168 + dx, y: 170), control: CGPoint(x: 184 + dx, y: 156))
            path.closeSubpath()
            fill(path, shade)
        }
    }

    private func headFeature() {
        switch genome.head {
        case .floppyEars:
            let tilt: Double = switch expression {
            case .excited: 50
            case .sad, .sick, .hungry: 62
            default: 28
            }
            for side in [-1.0, 1.0] {
                let x = 100 + side * 40 * spread
                let wonk = side > 0 ? quirks.earJitter : 0
                ellipse(x, 62, 16, 40, body, rotation: side * tilt + wonk)
                ellipse(x + side * -2, 66, 7, 27, belly, rotation: side * tilt + wonk)
            }
        case .pointyEars:
            for side in [-1.0, 1.0] {
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 100 + side * x * spread, y: y) }
                var outer = Path()
                outer.addLines([p(48, 92), p(44, 38), p(8, 66)])
                outer.closeSubpath()
                fill(outer, body)
                stroke(outer, body, width: 8)
                var inner = Path()
                inner.addLines([p(38, 80), p(36, 54), p(18, 67)])
                inner.closeSubpath()
                fill(inner, .pink)
            }
        case .antennae:
            let knob: Color = genome.palette.name == "Butter" ? .coral : .butter
            for side in [-1.0, 1.0] {
                var path = Path()
                path.move(to: CGPoint(x: 100 + side * 18, y: 62))
                path.addQuadCurve(to: CGPoint(x: 100 + side * 42, y: 26), control: CGPoint(x: 100 + side * 28, y: 30))
                stroke(path, .ink, width: 4)
                ellipse(100 + side * 44, 25, 10, 10, knob)
            }
        case .roundEars:
            for side in [-1.0, 1.0] {
                let x = 100 + side * 48 * spread
                ellipse(x, 80, 15, 15, body)
                ellipse(x, 80, 7, 7, belly)
            }
        case .finAndHorns:
            for side in [-1.0, 1.0] {
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 100 + side * x, y: y) }
                var horn = Path()
                horn.move(to: p(30, 72))
                horn.addQuadCurve(to: p(24, 44), control: p(34, 50))
                horn.addQuadCurve(to: p(16, 66), control: p(22, 58))
                horn.closeSubpath()
                fill(horn, .butterLight)
            }
            var fin = Path()
            fin.move(to: CGPoint(x: 84, y: 66))
            fin.addQuadCurve(to: CGPoint(x: 116, y: 66), control: CGPoint(x: 100, y: 30))
            fin.closeSubpath()
            fill(fin, shade)
        case .sprout:
            var stem = Path()
            stem.move(to: CGPoint(x: 100, y: 66))
            stem.addLine(to: CGPoint(x: 100, y: 44))
            stroke(stem, .leafDeep, width: 5)
            var left = Path()
            left.move(to: CGPoint(x: 100, y: 46))
            left.addQuadCurve(to: CGPoint(x: 68, y: 50), control: CGPoint(x: 78, y: 32))
            left.addQuadCurve(to: CGPoint(x: 100, y: 46), control: CGPoint(x: 86, y: 58))
            fill(left, .leaf)
            var right = Path()
            right.move(to: CGPoint(x: 100, y: 42))
            right.addQuadCurve(to: CGPoint(x: 134, y: 40), control: CGPoint(x: 122, y: 24))
            right.addQuadCurve(to: CGPoint(x: 100, y: 42), control: CGPoint(x: 118, y: 52))
            fill(right, .leaf)
        }
    }

    private func feet() {
        ellipse(100 - 28 * girth, 177, 15, 9, shade)
        ellipse(100 + 28 * girth, 177, 15, 9, shade)
    }

    private func torso() {
        var ctx = context
        ctx.translateBy(x: 100, y: 0)
        ctx.scaleBy(x: girth, y: 1)
        ctx.translateBy(x: -100, y: 0)
        let outline: Path
        switch genome.body {
        case .round:
            outline = Path(ellipseIn: CGRect(x: 34, y: 60, width: 132, height: 120))
            ctx.fill(outline, with: .color(body))
            ctx.fill(Path(ellipseIn: CGRect(x: 60, y: 112, width: 80, height: 60)), with: .color(belly))
        case .bean:
            outline = Path(roundedRect: CGRect(x: 42, y: 54, width: 116, height: 128), cornerRadius: 58)
            ctx.fill(outline, with: .color(body))
            ctx.fill(Path(ellipseIn: CGRect(x: 64, y: 122, width: 72, height: 52)), with: .color(belly))
        case .blob:
            var path = Path()
            path.move(to: CGPoint(x: 40, y: 150))
            path.addCurve(to: CGPoint(x: 100, y: 52), control1: CGPoint(x: 30, y: 92), control2: CGPoint(x: 60, y: 52))
            path.addCurve(to: CGPoint(x: 160, y: 150), control1: CGPoint(x: 140, y: 52), control2: CGPoint(x: 170, y: 92))
            path.addCurve(to: CGPoint(x: 100, y: 182), control1: CGPoint(x: 158, y: 172), control2: CGPoint(x: 140, y: 182))
            path.addCurve(to: CGPoint(x: 40, y: 150), control1: CGPoint(x: 60, y: 182), control2: CGPoint(x: 42, y: 172))
            outline = path
            ctx.fill(path, with: .color(body))
            ctx.fill(Path(ellipseIn: CGRect(x: 62, y: 128, width: 76, height: 44)), with: .color(belly))
        }
        paintPattern(in: ctx, clippedTo: outline)
        defer { paintCoat(in: ctx, clippedTo: outline) }
        if shine > 0 {
            let gloss = Color.white.opacity(0.65 * shine)
            let top: CGFloat = genome.body == .round ? 66 : 58
            let highlight = Path(ellipseIn: CGRect(x: -22, y: -8, width: 44, height: 16))
                .applying(CGAffineTransform(translationX: 70, y: top + 26).rotated(by: -0.6))
            ctx.fill(highlight, with: .color(gloss))
            ctx.fill(Path(ellipseIn: CGRect(x: 52, y: top + 44, width: 9, height: 9)), with: .color(gloss))
            let rim = Path(ellipseIn: CGRect(x: 120, y: top + 70, width: 28, height: 10))
                .applying(CGAffineTransform(translationX: 134, y: top + 75).rotated(by: 0.9).translatedBy(x: -134, y: -(top + 75)))
            ctx.fill(rim, with: .color(Color.white.opacity(0.35 * shine)))
        }
        switch genome.marking {
        case .none:
            break
        case .spots:
            for (x, y, r) in [(54.0, 112.0, 7.0), (148, 96, 5), (142, 140, 4)] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(shade))
            }
        case .sparkles:
            for (x, y, r) in [(62.0, 96.0, 4.0), (144, 128, 3), (132, 80, 2.5)] {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.75)))
            }
        case .forehead:
            var chevron = Path()
            chevron.addLines([CGPoint(x: 90, y: 72), CGPoint(x: 100, y: 82), CGPoint(x: 110, y: 72)])
            ctx.stroke(chevron, with: .color(shade), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
    }

    /// Bold flat graphic patterns: stripes, polka dots, colour-blocked bottoms or a little cap.
    private func paintPattern(in base: GraphicsContext, clippedTo outline: Path) {
        var c = base
        c.clip(to: outline)
        switch quirks.pattern {
        case 1:
            for y in [146.0, 162, 178] { c.box(0, y, 200, 7, shade.opacity(0.85)) }
        case 2:
            for (x, y) in [(56.0, 96.0), (146, 104), (52, 140), (150, 146), (124, 78), (78, 74)] { c.dot(x, y, 6, belly) }
        case 3:
            c.box(0, 156, 200, 50, shade)
        case 4:
            c.box(0, 0, 200, genome.body == .round ? 84 : 78, shade)
        default:
            break
        }
    }

    private func arms() {
        let pose: Double = switch expression {
        case .excited: 150
        case .happy: 38
        case .sad, .sick, .dead: 6
        case .asleep: 12
        default: 24
        }
        for side in [-1.0, 1.0] {
            let shoulder = CGPoint(x: 100 + side * 54 * girth, y: 124)
            let angle = side * pose * .pi / 180
            let center = CGPoint(x: shoulder.x + sin(angle) * 16, y: shoulder.y + cos(angle) * 16)
            ellipse(center.x, center.y, 9, 19, shade, rotation: -side * pose)
            let hand = CGPoint(x: shoulder.x + sin(angle) * 32, y: shoulder.y + cos(angle) * 32)
            ellipse(hand.x, hand.y, 8, 8, shade)
        }
    }

    private func tuft() {
        var hair = Path()
        let top: CGFloat = genome.body == .round ? 62 : 55
        hair.move(to: CGPoint(x: 94, y: top + 4)); hair.addQuadCurve(to: CGPoint(x: 90, y: top - 12), control: CGPoint(x: 86, y: top - 2))
        hair.move(to: CGPoint(x: 100, y: top + 2)); hair.addQuadCurve(to: CGPoint(x: 102, y: top - 16), control: CGPoint(x: 96, y: top - 8))
        hair.move(to: CGPoint(x: 106, y: top + 4)); hair.addQuadCurve(to: CGPoint(x: 114, y: top - 10), control: CGPoint(x: 112, y: top - 2))
        stroke(hair, shade, width: 5)
    }

    private func nose() {
        guard genome.eyes != .cyclops else { return }
        switch quirks.nose {
        case 1:
            ellipse(100, 118, 4.5, 3, .ink)
        case 2:
            ellipse(100, 118, 5.5, 4.2, .coralDeep)
            ellipse(98.5, 116.8, 1.6, 1.2, .white, opacity: 0.7)
        default:
            break
        }
    }

    /// Mud, foam and drops painted onto the fur, clipped to the body so they move with it.
    private func paintCoat(in base: GraphicsContext, clippedTo outline: Path) {
        var c = base
        c.clip(to: outline)
        if coat.sickly {
            c.fill(Path(CGRect(x: 0, y: 0, width: 200, height: 200)), with: .color(Color(hex: 0x9AD39A).opacity(0.3)))
        }
        for spot in coat.mud {
            let x = spot.x * 200, y = spot.y * 200, r = spot.size * 200
            let mud = Color(hex: 0x8A5A3C)
            c.oval(x, y, r, r * 0.8, mud.opacity(0.8 * spot.amount), rotation: Double(spot.id * 37 % 90))
            c.dot(x + r * 0.75, y - r * 0.45, r * 0.38, mud.opacity(0.7 * spot.amount))
            c.dot(x - r * 0.8, y + r * 0.35, r * 0.3, mud.opacity(0.6 * spot.amount))
            c.dot(x - r * 0.2, y + r * 0.95, r * 0.22, mud.opacity(0.55 * spot.amount))
            c.dot(x - r * 0.25, y - r * 0.25, r * 0.22, Color(hex: 0xA8754F).opacity(0.7 * spot.amount))
        }
        let foamTint: Color = coat.shampoo ? Color(hex: 0xF1E6FF) : .white
        for blob in coat.foam {
            let x = blob.x * 200, y = blob.y * 200, r = blob.size * 200
            let alpha = min(1, blob.amount)
            c.dot(x, y, r, foamTint.opacity(alpha))
            c.dot(x - r * 0.8, y + r * 0.3, r * 0.7, foamTint.opacity(alpha))
            c.dot(x + r * 0.8, y + r * 0.2, r * 0.75, foamTint.opacity(alpha))
            c.dot(x - r * 0.2, y - r * 0.4, r * 0.25, Color.sky.opacity(0.5 * alpha))
        }
        for drop in coat.drops {
            let x = drop.x * 200, y = drop.y * 200
            c.shape(Color.skyDeep.opacity(0.85 * drop.amount)) { p in
                p.move(to: CGPoint(x: x, y: y - 6))
                p.addCurve(to: CGPoint(x: x, y: y + 4), control1: CGPoint(x: x + 5, y: y - 1), control2: CGPoint(x: x + 4, y: y + 4))
                p.addCurve(to: CGPoint(x: x, y: y - 6), control1: CGPoint(x: x - 4, y: y + 4), control2: CGPoint(x: x - 5, y: y - 1))
            }
            c.dot(x - 1.5, y - 0.5, 1.1, .white.opacity(drop.amount))
        }
    }

    private func sickExtras() {
        // A thermometer poking out of the mouth and a cold sweat drop.
        let thermometer = Path(roundedRect: CGRect(x: -3, y: -2, width: 34, height: 6), cornerRadius: 3)
            .applying(CGAffineTransform(translationX: 104, y: 132).rotated(by: 0.45))
        context.fill(thermometer, with: .color(.white))
        context.stroke(thermometer, with: .color(.ink.opacity(0.4)), lineWidth: 1)
        let bulb = Path(ellipseIn: CGRect(x: 30, y: -2.5, width: 7, height: 7))
            .applying(CGAffineTransform(translationX: 104, y: 132).rotated(by: 0.45))
        context.fill(bulb, with: .color(.coralDeep))
        var sweat = Path()
        sweat.move(to: CGPoint(x: 146, y: 74))
        sweat.addCurve(to: CGPoint(x: 146, y: 92), control1: CGPoint(x: 156, y: 84), control2: CGPoint(x: 154, y: 92))
        sweat.addCurve(to: CGPoint(x: 146, y: 74), control1: CGPoint(x: 138, y: 92), control2: CGPoint(x: 136, y: 84))
        context.fill(sweat, with: .color(.sky))
    }

    private var eyesClosed: Bool {
        blinking || [.asleep, .dead, .ignoring].contains(expression)
    }

    private func eyes() {
        let q = quirks
        let centers: [CGFloat] = genome.eyes == .cyclops ? [100] : [100 - q.eyeSpacing * spread, 100 + q.eyeSpacing * spread]
        let lookShift: CGFloat = expression == .ignoring ? -12 : 0
        let lx = CGFloat(max(-1, min(1, look.dx))) * 4
        let ly = CGFloat(max(-1, min(1, look.dy))) * 3
        for cx in centers.map({ $0 + lookShift }) {
            let wide: CGFloat = genome.eyes == .cyclops ? 16 : q.eyeSize + 3
            if eyesClosed {
                var arc = Path()
                switch expression {
                case .asleep, .ignoring:
                    arc.move(to: CGPoint(x: cx - wide, y: 106))
                    arc.addQuadCurve(to: CGPoint(x: cx + wide, y: 106), control: CGPoint(x: cx, y: 115))
                default:
                    arc.move(to: CGPoint(x: cx - wide, y: 110))
                    arc.addQuadCurve(to: CGPoint(x: cx + wide, y: 110), control: CGPoint(x: cx, y: 99))
                }
                stroke(arc, .ink, width: 3.5)
                continue
            }
            if genome.eyes == .cyclops {
                ellipse(cx, 106, 19, 20, .white)
                ellipse(cx + lx * 1.4, 108 + ly, 10, 11, .ink)
                ellipse(cx + 4 + lx * 1.4, 103 + ly, 3.5, 3.5, .white)
            } else if expression == .sick {
                ellipse(cx, 110, q.eyeSize, q.eyeSize * 0.55, .ink)
                var lid = Path()
                lid.move(to: CGPoint(x: cx - q.eyeSize - 2, y: 106))
                lid.addLine(to: CGPoint(x: cx + q.eyeSize + 2, y: 106))
                stroke(lid, .ink, width: 2.5)
            } else {
                let big: CGFloat = expression == .excited ? 1.25 : (expression == .sad ? 0.9 : 1)
                let r = q.eyeSize * big
                ellipse(cx + lx, 108 + ly, r * 0.85, r, .ink)
                ellipse(cx + lx + r * 0.3, 108 + ly - r * 0.4, r * 0.3, r * 0.3, .white)
                if expression == .excited { ellipse(cx + lx - r * 0.3, 108 + ly + r * 0.35, r * 0.15, r * 0.15, .white) }
            }
        }
        if [.sad, .hungry, .sick].contains(expression), genome.eyes == .big {
            for (index, cx) in centers.enumerated() {
                let side: CGFloat = index == 0 ? 1 : -1
                var brow = Path()
                brow.move(to: CGPoint(x: cx - side * 9, y: 98))
                brow.addLine(to: CGPoint(x: cx + side * 4, y: 93))
                stroke(brow, .ink, width: 3)
            }
        }
        if expression == .sad, let first = centers.first {
            var tear = Path()
            tear.move(to: CGPoint(x: first - 4, y: 122))
            tear.addQuadCurve(to: CGPoint(x: first - 4, y: 136), control: CGPoint(x: first, y: 130))
            stroke(tear, .sky, width: 4)
        }
    }

    private func cheeks() {
        let color: Color = expression == .sick ? Color(hex: 0x9AD39A) : .blush
        let opacity = expression == .excited ? 0.8 : 0.6
        let shift: CGFloat = expression == .ignoring ? -12 : 0
        let x = (quirks.eyeSpacing + 13) * spread
        ellipse(100 - x + shift, 124, 7.5, 6, color, opacity: opacity)
        ellipse(100 + x + shift, 124, 7.5, 6, color, opacity: opacity)
    }

    private func mouth() {
        var path = Path()
        switch expression {
        case .happy, .dead:
            path.move(to: CGPoint(x: 92, y: 126))
            path.addQuadCurve(to: CGPoint(x: 100, y: 126), control: CGPoint(x: 96, y: 132))
            path.addQuadCurve(to: CGPoint(x: 108, y: 126), control: CGPoint(x: 104, y: 132))
            stroke(path, .ink, width: 3)
        case .content:
            path.move(to: CGPoint(x: 93, y: 128))
            path.addQuadCurve(to: CGPoint(x: 107, y: 128), control: CGPoint(x: 100, y: 136))
            if quirks.toothy {
                path.closeSubpath()
                fill(path, .ink)
                fill(Path(roundedRect: CGRect(x: 97, y: 128, width: 6, height: 5), cornerRadius: 1.5), .white)
            } else {
                stroke(path, .ink, width: 3)
            }
        case .excited:
            path.move(to: CGPoint(x: 88, y: 126))
            path.addQuadCurve(to: CGPoint(x: 112, y: 126), control: CGPoint(x: 100, y: 146))
            path.closeSubpath()
            fill(path, .ink)
            ellipse(100, 133, 6, 3, .coral)
        case .hungry:
            ellipse(100, 132, 7, 8, .ink)
        case .sad:
            path.move(to: CGPoint(x: 92, y: 134))
            path.addQuadCurve(to: CGPoint(x: 108, y: 134), control: CGPoint(x: 100, y: 126))
            stroke(path, .ink, width: 3)
        case .sick:
            path.move(to: CGPoint(x: 90, y: 132))
            path.addQuadCurve(to: CGPoint(x: 100, y: 132), control: CGPoint(x: 95, y: 127))
            path.addQuadCurve(to: CGPoint(x: 110, y: 132), control: CGPoint(x: 105, y: 137))
            stroke(path, .ink, width: 3)
        case .asleep, .sleepy:
            ellipse(100, 132, 4, 3, .ink)
        case .ignoring:
            path.move(to: CGPoint(x: 80, y: 130))
            path.addQuadCurve(to: CGPoint(x: 94, y: 130), control: CGPoint(x: 87, y: 126))
            stroke(path, .ink, width: 3)
        }
    }

    // MARK: Primitives

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: Color, rotation: Double = 0, opacity: Double = 1) {
        let path = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            .applying(CGAffineTransform(translationX: cx, y: cy).rotated(by: rotation * .pi / 180))
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    private func fill(_ path: Path, _ color: Color) {
        context.fill(path, with: .color(color))
    }

    private func stroke(_ path: Path, _ color: Color, width: CGFloat) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

#Preview {
    HStack {
        ForEach(0..<4) { index in
            LiveCritterView(genome: Genome(seed: UInt64(index * 31)), expression: [.happy, .excited, .sad, .ignoring][index])
                .frame(width: 200, height: 200)
        }
    }
    .padding()
    .background(Color.cream)
}
