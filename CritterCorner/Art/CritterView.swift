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
    var style: CritterStyle = .vinyl

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 200, y: size.height / 200)
            var painter = CritterPainter(genome: genome, expression: expression, weight: weight, blinking: blinking || blissful, halo: halo, look: look, shine: shine, coat: coat, style: style, context: context)
            painter.paint()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("Ett kryp i färgen \(genome.palette.name.lowercased())"))
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
    var style: CritterStyle = .vinyl

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
            CritterView(genome: genome, expression: expression, weight: weight, blinking: blinkCycle < 0.14 || (dying && blinkCycle < 1.4), halo: halo, look: eyes, blissful: blissful, shine: shine, coat: coat, style: style)
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


/// Mixes two hex colours; `t` = 0 gives `a`, 1 gives `b`.
private func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
    func channel(_ value: UInt32, _ shift: UInt32) -> Double { Double((value >> shift) & 0xFF) / 255 }
    func lerp(_ shift: UInt32) -> Double { channel(a, shift) + (channel(b, shift) - channel(a, shift)) * t }
    return Color(.sRGB, red: lerp(16), green: lerp(8), blue: lerp(0))
}

/// Draws one critter in one of four styles. Every style shares the genome's silhouette and features,
/// so a critter keeps its identity; only the way it is drawn changes.
private struct CritterPainter {
    let genome: Genome
    let expression: Mood
    let weight: Double
    let blinking: Bool
    let halo: Bool
    let look: CGVector
    let shine: Double
    let coat: CritterCoat
    let style: CritterStyle
    var context: GraphicsContext

    private var palette: Palette { genome.palette }
    private var bellyColor: Color { Color(hex: palette.belly) }
    private var ink: Color { Color(hex: 0x3A2E2A) }
    /// Body width factor: thin critters are narrow, chubby ones wide.
    private var girth: CGFloat { 0.62 + CGFloat(min(max(weight, 0), 100)) / 100 * 0.76 }
    private var spread: CGFloat { 0.8 + 0.2 * girth }
    private var googlyLeft: CGFloat { 12 + CGFloat(genome.seed % 5) }
    private var googlyRight: CGFloat { 15 + CGFloat((genome.seed / 7) % 5) }

    mutating func paint() {
        let base = context
        ellipse(100, style == .chibi ? 191 : 186, 56 * girth, 8, .ink, opacity: 0.1)
        if halo { wings() }
        tail()
        switch style {
        case .chibi:
            chibiBody()
            // The chibi head is the usual critter shape, shrunk and lifted onto a little body.
            context.translateBy(x: 100, y: 30)
            context.scaleBy(x: 0.84, y: 0.84)
            context.translateBy(x: -100, y: -30)
        case .doodle:
            doodleLimbs()
        default:
            break
        }
        if genome.head != .sprout && genome.head != .antennae { headFeature() }
        feet()
        torso()
        if style == .plush { plushArmsAndTag() }
        if genome.head == .sprout || genome.head == .antennae { headFeature() } else if style == .doodle { doodleHair() }
        eyes()
        cheeks()
        nose()
        mouth()
        if coat.sickly { sickExtras() }
        context = base
        if halo {
            var ring = Path(ellipseIn: CGRect(x: 66, y: 12, width: 68, height: 18))
            ring = ring.strokedPath(StrokeStyle(lineWidth: 6))
            context.fill(ring, with: .color(.butterDeep))
        }
    }

    // MARK: Style-aware fill

    /// Fills a body part the way the current style paints things.
    private func part(_ path: Path, _ hex: UInt32, outline: Bool = true) {
        let rect = path.boundingRect
        switch style {
        case .vinyl:
            context.fill(path, with: .radialGradient(
                Gradient(colors: [mix(hex, 0xFFFFFF, 0.45), Color(hex: hex), mix(hex, 0x000000, 0.12)]),
                center: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.3),
                startRadius: 0,
                endRadius: max(rect.width, rect.height) * 0.85
            ))
        case .chibi:
            context.fill(path, with: .color(Color(hex: hex)))
            var shaded = context
            shaded.clip(to: path)
            shaded.fill(Path(ellipseIn: CGRect(x: rect.midX - rect.width * 0.1, y: rect.midY, width: rect.width, height: rect.height * 0.8)), with: .color(mix(hex, 0x000000, 0.2).opacity(0.25)))
            if outline { context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)) }
        case .plush:
            context.fill(path, with: .color(mix(hex, 0x8A8A8A, 0.08)))
            var felt = context
            felt.clip(to: path)
            var y = rect.minY
            var row = 0
            while y < rect.maxY {
                var x = rect.minX + (row.isMultiple(of: 2) ? 0 : 3)
                while x < rect.maxX {
                    felt.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(row.isMultiple(of: 2) ? .black.opacity(0.07) : .white.opacity(0.18)))
                    x += 6
                }
                y += 3
                row += 1
            }
        case .doodle:
            context.fill(path, with: .color(mix(hex, 0xFFFFFF, 0.15)))
            var hatch = context
            hatch.clip(to: path)
            var lines = Path()
            var x = rect.minX - rect.height
            while x < rect.maxX {
                lines.move(to: CGPoint(x: x, y: rect.maxY))
                lines.addLine(to: CGPoint(x: x + rect.height * 0.7, y: rect.minY))
                x += 9
            }
            hatch.stroke(lines, with: .color(mix(hex, 0x000000, 0.25).opacity(0.35)), lineWidth: 3)
            if outline {
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                context.stroke(path.applying(CGAffineTransform(translationX: 1.4, y: -1.2)), with: .color(ink.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation: Double = 0) -> Path {
        Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            .applying(CGAffineTransform(translationX: cx, y: cy).rotated(by: rotation * .pi / 180))
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
            if style == .chibi || style == .doodle { stroke(path, ink, width: 14) }
            stroke(path, Color(hex: palette.shade), width: 10)
        case .fin:
            var path = Path()
            path.move(to: CGPoint(x: 156 + dx, y: 160))
            path.addQuadCurve(to: CGPoint(x: 188 + dx, y: 132), control: CGPoint(x: 182 + dx, y: 154))
            path.addQuadCurve(to: CGPoint(x: 168 + dx, y: 170), control: CGPoint(x: 184 + dx, y: 156))
            path.closeSubpath()
            part(path, palette.shade)
        }
    }

    private func chibiBody() {
        let w = 66 * girth
        for side in [-1.0, 1.0] {
            part(Path(roundedRect: CGRect(x: 100 + side * 15 * girth - 10, y: 166, width: 20, height: 26), cornerRadius: 9), palette.body)
        }
        part(Path(roundedRect: CGRect(x: 100 - w / 2, y: 136, width: w, height: 44), cornerRadius: 20), palette.body)
        context.fill(Path(ellipseIn: CGRect(x: 100 - w * 0.28, y: 150, width: w * 0.56, height: 24)), with: .color(bellyColor))
    }

    private func doodleLimbs() {
        var limbs = Path()
        for side in [-1.0, 1.0] {
            let hip = 100 + side * 18 * girth
            limbs.move(to: CGPoint(x: hip, y: 170)); limbs.addLine(to: CGPoint(x: hip + side * 4, y: 194))
            let shoulder = CGPoint(x: 100 + side * 56 * girth, y: 130)
            let hand = CGPoint(x: shoulder.x + side * 22, y: 116)
            limbs.move(to: shoulder); limbs.addLine(to: hand)
            limbs.move(to: hand); limbs.addLine(to: CGPoint(x: hand.x + side * 6, y: hand.y - 8))
            limbs.move(to: hand); limbs.addLine(to: CGPoint(x: hand.x + side * 9, y: hand.y + 2))
        }
        stroke(limbs, ink, width: 3.5)
        for side in [-1.0, 1.0] {
            let foot = oval(100 + side * 18 * girth + side * 8, 195, 9, 4.5)
            context.stroke(foot, with: .color(ink), lineWidth: 3)
        }
    }

    private func doodleHair() {
        var hair = Path()
        let top: CGFloat = genome.body == .round ? 62 : 55
        hair.move(to: CGPoint(x: 82, y: top + 4))
        for (index, x) in stride(from: 88.0, through: 118, by: 6).enumerated() {
            hair.addLine(to: CGPoint(x: x, y: index.isMultiple(of: 2) ? top - 14 : top + 2))
        }
        stroke(hair, ink, width: 3.5)
    }

    private func plushArmsAndTag() {
        for side in [-1.0, 1.0] {
            part(oval(100 + side * 60 * girth, 142, 12, 21, rotation: side * -25), palette.shade)
        }
        let tagCenter = CGPoint(x: 100 + 58 * girth, y: 160)
        let tag = Path(roundedRect: CGRect(x: -9, y: -6, width: 18, height: 13), cornerRadius: 2)
            .applying(CGAffineTransform(translationX: tagCenter.x, y: tagCenter.y).rotated(by: 0.2))
        context.fill(tag, with: .color(.white))
        context.fill(oval(tagCenter.x, tagCenter.y + 0.5, 3, 3), with: .color(Color(hex: palette.shade)))
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
                part(oval(x, 62, 16, 40, rotation: side * tilt), palette.body)
                ellipse(x + side * -2, 66, 7, 27, bellyColor, rotation: side * tilt)
            }
        case .pointyEars:
            for side in [-1.0, 1.0] {
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 100 + side * x * spread, y: y) }
                var outer = Path()
                outer.move(to: p(48, 92))
                outer.addQuadCurve(to: p(44, 38), control: p(50, 60))
                outer.addQuadCurve(to: p(8, 66), control: p(24, 46))
                outer.closeSubpath()
                part(outer, palette.body)
                var inner = Path()
                inner.addLines([p(38, 80), p(36, 54), p(18, 67)])
                inner.closeSubpath()
                fill(inner, .pink)
            }
        case .antennae:
            let knob: UInt32 = palette.belly == 0xFFF1C4 ? 0xFF7A8A : 0xFFD66B
            for side in [-1.0, 1.0] {
                var path = Path()
                path.move(to: CGPoint(x: 100 + side * 18, y: 62))
                path.addQuadCurve(to: CGPoint(x: 100 + side * 42, y: 26), control: CGPoint(x: 100 + side * 28, y: 30))
                stroke(path, .ink, width: 4)
                part(oval(100 + side * 44, 25, 10, 10), knob)
            }
        case .roundEars:
            for side in [-1.0, 1.0] {
                let x = 100 + side * 48 * spread
                part(oval(x, 80, 15, 15), palette.body)
                ellipse(x, 80, 7, 7, bellyColor)
            }
        case .finAndHorns:
            for side in [-1.0, 1.0] {
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 100 + side * x, y: y) }
                var horn = Path()
                horn.move(to: p(30, 72))
                horn.addQuadCurve(to: p(24, 44), control: p(34, 50))
                horn.addQuadCurve(to: p(16, 66), control: p(22, 58))
                horn.closeSubpath()
                part(horn, 0xFFF1C4)
            }
            var fin = Path()
            fin.move(to: CGPoint(x: 84, y: 66))
            fin.addQuadCurve(to: CGPoint(x: 116, y: 66), control: CGPoint(x: 100, y: 30))
            fin.closeSubpath()
            part(fin, palette.shade)
        case .sprout:
            var stem = Path()
            stem.move(to: CGPoint(x: 100, y: 66))
            stem.addLine(to: CGPoint(x: 100, y: 44))
            stroke(stem, .leafDeep, width: 5)
            var left = Path()
            left.move(to: CGPoint(x: 100, y: 46))
            left.addQuadCurve(to: CGPoint(x: 68, y: 50), control: CGPoint(x: 78, y: 32))
            left.addQuadCurve(to: CGPoint(x: 100, y: 46), control: CGPoint(x: 86, y: 58))
            part(left, 0x7BC96F)
            var right = Path()
            right.move(to: CGPoint(x: 100, y: 42))
            right.addQuadCurve(to: CGPoint(x: 134, y: 40), control: CGPoint(x: 122, y: 24))
            right.addQuadCurve(to: CGPoint(x: 100, y: 42), control: CGPoint(x: 118, y: 52))
            part(right, 0x7BC96F)
        }
    }

    private func feet() {
        switch style {
        case .vinyl:
            for side in [-1.0, 1.0] { part(oval(100 + side * 30 * girth, 179, 19, 10), palette.shade) }
        case .plush:
            for side in [-1.0, 1.0] { part(oval(100 + side * 28 * girth, 179, 18, 10), palette.shade) }
        case .chibi, .doodle:
            break
        }
    }

    private mutating func torso() {
        let base = context
        context.translateBy(x: 100, y: 0)
        context.scaleBy(x: girth, y: 1)
        context.translateBy(x: -100, y: 0)
        let outline: Path
        let bellyRect: CGRect
        switch genome.body {
        case .round:
            outline = Path(ellipseIn: CGRect(x: 32, y: 56, width: 136, height: 126))
            bellyRect = CGRect(x: 60, y: 112, width: 80, height: 60)
        case .bean:
            outline = Path(roundedRect: CGRect(x: 42, y: 52, width: 116, height: 130), cornerRadius: 58)
            bellyRect = CGRect(x: 64, y: 122, width: 72, height: 52)
        case .blob:
            var path = Path()
            path.move(to: CGPoint(x: 40, y: 150))
            path.addCurve(to: CGPoint(x: 100, y: 52), control1: CGPoint(x: 30, y: 92), control2: CGPoint(x: 60, y: 52))
            path.addCurve(to: CGPoint(x: 160, y: 150), control1: CGPoint(x: 140, y: 52), control2: CGPoint(x: 170, y: 92))
            path.addCurve(to: CGPoint(x: 100, y: 182), control1: CGPoint(x: 158, y: 172), control2: CGPoint(x: 140, y: 182))
            path.addCurve(to: CGPoint(x: 40, y: 150), control1: CGPoint(x: 60, y: 182), control2: CGPoint(x: 42, y: 172))
            outline = path
            bellyRect = CGRect(x: 62, y: 128, width: 76, height: 44)
        }
        part(outline, palette.body)
        let belly = Path(ellipseIn: bellyRect)
        context.fill(belly, with: .color(style == .doodle ? mix(palette.belly, 0xFFFFFF, 0.2) : bellyColor))
        if style == .plush {
            context.stroke(Path(ellipseIn: bellyRect.insetBy(dx: 5, dy: 5)), with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2.5, dash: [6, 5]))
            context.stroke(Path { p in p.move(to: CGPoint(x: 100, y: outline.boundingRect.minY + 4)); p.addLine(to: CGPoint(x: 100, y: outline.boundingRect.minY + 30)) }, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, dash: [6, 5]))
        }
        switch genome.marking {
        case .none:
            break
        case .spots:
            for (x, y, r) in [(54.0, 112.0, 7.0), (148, 96, 5), (142, 140, 4)] {
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: palette.shade)))
            }
        case .sparkles:
            for (x, y, r) in [(62.0, 96.0, 4.0), (144, 128, 3), (132, 80, 2.5)] {
                context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.75)))
            }
        case .forehead:
            var chevron = Path()
            chevron.addLines([CGPoint(x: 90, y: 72), CGPoint(x: 100, y: 82), CGPoint(x: 110, y: 72)])
            context.stroke(chevron, with: .color(Color(hex: palette.shade)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        // Vinyl always has a soft gloss; a fresh bath makes every style shine.
        let gloss = style == .vinyl ? 0.55 + 0.3 * shine : 0.65 * shine
        if gloss > 0 {
            let top = outline.boundingRect.minY
            context.fill(oval(72, top + 28, 22, 9, rotation: -32), with: .color(.white.opacity(gloss)))
            context.fill(oval(56, top + 48, 4.5, 4.5), with: .color(.white.opacity(gloss)))
        }
        if style == .chibi || style == .doodle {
            // Re-stroke so the belly and markings sit inside the outline.
            context.stroke(outline, with: .color(ink), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        }
        paintCoat(in: context, clippedTo: outline)
        context = base
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

    // MARK: Face

    private var eyesClosed: Bool {
        blinking || [.asleep, .dead, .ignoring].contains(expression)
    }

    private var eyeCenters: [CGFloat] {
        if genome.eyes == .cyclops { return [100] }
        let spacing: CGFloat = style == .chibi ? 26 : 23
        return [100 - spacing * spread, 100 + spacing * spread]
    }

    private func eyes() {
        let lookShift: CGFloat = expression == .ignoring ? -12 : 0
        let lx = CGFloat(max(-1, min(1, look.dx))) * 5
        let ly = CGFloat(max(-1, min(1, look.dy))) * 4
        for (index, cx) in eyeCenters.map({ $0 + lookShift }).enumerated() {
            let cyclops = genome.eyes == .cyclops
            if eyesClosed {
                closedEye(cx, wide: cyclops ? 18 : (style == .chibi ? 9 : 12))
                continue
            }
            switch style {
            case .vinyl:
                if cyclops {
                    ellipse(cx, 106, 22, 24, .white)
                    ellipse(cx + lx * 1.4, 110 + ly, 15, 17, .ink)
                    ellipse(cx + 7 + lx * 1.4, 102 + ly, 6, 6, .white)
                } else if expression == .sick {
                    ellipse(cx, 113, 12, 7, .ink)
                } else {
                    let big: CGFloat = expression == .excited ? 1.15 : (expression == .sad ? 0.88 : 1)
                    ellipse(cx + lx, 110 + ly, 12.5 * big, 14.5 * big, .ink)
                    ellipse(cx + lx + 4.5 * big, 104.5 + ly, 5 * big, 5 * big, .white)
                    ellipse(cx + lx - 3 * big, 116 + ly, 2.2 * big, 2.2 * big, .white)
                }
            case .chibi:
                let r: CGFloat = cyclops ? 11 : (expression == .excited ? 8 : 6.5)
                if expression == .sick {
                    ellipse(cx, 110, r, r * 0.55, ink)
                } else {
                    ellipse(cx + lx * 0.8, 108 + ly * 0.8, r * 0.9, r, ink)
                    ellipse(cx + lx * 0.8 + r * 0.32, 108 + ly * 0.8 - r * 0.35, r * 0.32, r * 0.32, .white)
                }
            case .plush:
                let r: CGFloat = cyclops ? 15 : 10
                ellipse(cx, 108, r, r, ink)
                context.stroke(oval(cx, 108, r * 0.65, r * 0.65), with: .color(Color(hex: 0x6B5A55)), lineWidth: 1.6)
                ellipse(cx - r * 0.22, 106, 1.6, 1.6, .white, opacity: 0.7)
                ellipse(cx + r * 0.22, 110, 1.6, 1.6, .white, opacity: 0.7)
            case .doodle:
                let r = cyclops ? CGFloat(22) : (index == 0 ? googlyLeft : googlyRight)
                let y: CGFloat = 104 - (index == 1 ? 3 : 0)
                ellipse(cx, y, r, r, .white)
                context.stroke(oval(cx, y, r, r), with: .color(ink), lineWidth: 2.6)
                let droop: CGFloat = expression == .sad || expression == .sick ? 4 : 0
                ellipse(cx + lx * 1.2 + (index == 0 ? 2 : -2), y + ly + droop + 2, r * 0.42, r * 0.42, ink)
            }
        }
        if [.sad, .hungry, .sick].contains(expression), genome.eyes == .big, style != .plush {
            for (index, cx) in eyeCenters.enumerated() {
                let side: CGFloat = index == 0 ? 1 : -1
                var brow = Path()
                brow.move(to: CGPoint(x: cx - side * 10, y: 95))
                brow.addLine(to: CGPoint(x: cx + side * 5, y: 89))
                stroke(brow, .ink, width: 3)
            }
        }
        if expression == .sad, let first = eyeCenters.first {
            var tear = Path()
            tear.move(to: CGPoint(x: first - 4, y: 122))
            tear.addQuadCurve(to: CGPoint(x: first - 4, y: 136), control: CGPoint(x: first, y: 130))
            stroke(tear, .sky, width: 4)
        }
    }

    private func closedEye(_ cx: CGFloat, wide: CGFloat) {
        if style == .plush {
            var cross = Path()
            cross.move(to: CGPoint(x: cx - 7, y: 102)); cross.addLine(to: CGPoint(x: cx + 7, y: 114))
            cross.move(to: CGPoint(x: cx + 7, y: 102)); cross.addLine(to: CGPoint(x: cx - 7, y: 114))
            stroke(cross, ink, width: 3.5)
            return
        }
        var arc = Path()
        switch expression {
        case .asleep, .ignoring:
            arc.move(to: CGPoint(x: cx - wide, y: 107))
            arc.addQuadCurve(to: CGPoint(x: cx + wide, y: 107), control: CGPoint(x: cx, y: 117))
        default:
            arc.move(to: CGPoint(x: cx - wide, y: 111))
            arc.addQuadCurve(to: CGPoint(x: cx + wide, y: 111), control: CGPoint(x: cx, y: 98))
        }
        stroke(arc, .ink, width: style == .chibi ? 3.5 : 4.5)
    }

    private func cheeks() {
        let shift: CGFloat = expression == .ignoring ? -12 : 0
        let sick = expression == .sick
        let color: Color = sick ? Color(hex: 0x9AD39A) : (style == .doodle ? .coral : .blush)
        let x = 38 * girth
        switch style {
        case .vinyl:
            for side in [-1.0, 1.0] { ellipse(100 + side * x + shift, 130, 11, 7, color, opacity: expression == .excited ? 0.6 : 0.5) }
        case .chibi:
            for side in [-1.0, 1.0] { ellipse(100 + side * x + shift, 126, 7.5, 7.5, color, opacity: 0.7) }
        case .plush:
            for side in [-1.0, 1.0] { ellipse(100 + side * x + shift, 128, 8, 8, color, opacity: 0.45) }
        case .doodle:
            for side in [-1.0, 1.0] { ellipse(100 + side * (x + 4) + shift, 132, 9, 7, color, opacity: 0.5) }
        }
    }

    private func nose() {
        guard genome.eyes != .cyclops else { return }
        switch style {
        case .chibi:
            ellipse(100, 120, 5, 3.5, ink)
        case .plush:
            var triangle = Path()
            triangle.addLines([CGPoint(x: 93, y: 118), CGPoint(x: 107, y: 118), CGPoint(x: 100, y: 126)])
            triangle.closeSubpath()
            fill(triangle, Color(hex: 0xC2566E))
        case .vinyl, .doodle:
            break
        }
    }

    private func mouth() {
        let stitched = style == .plush
        let dy: CGFloat = style == .chibi ? 2 : (style == .plush ? 4 : 0)
        func draw(_ path: Path) {
            let moved = path.applying(CGAffineTransform(translationX: 0, y: dy))
            if stitched {
                context.stroke(moved, with: .color(Color(hex: 0xC2566E)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [4, 3]))
            } else {
                stroke(moved, .ink, width: 3)
            }
        }
        var path = Path()
        switch expression {
        case .happy, .dead:
            path.move(to: CGPoint(x: 92, y: 128))
            path.addQuadCurve(to: CGPoint(x: 100, y: 128), control: CGPoint(x: 96, y: 134))
            path.addQuadCurve(to: CGPoint(x: 108, y: 128), control: CGPoint(x: 104, y: 134))
            draw(path)
        case .content:
            path.move(to: CGPoint(x: 93, y: 129))
            path.addQuadCurve(to: CGPoint(x: 107, y: 129), control: CGPoint(x: 100, y: 137))
            draw(path)
            if style == .doodle {
                fill(Path(CGRect(x: 97, y: 131, width: 6, height: 5)), .white)
                context.stroke(Path(CGRect(x: 97, y: 131, width: 6, height: 5)), with: .color(ink), lineWidth: 1.5)
            }
        case .excited:
            path.move(to: CGPoint(x: 88, y: 127 + dy))
            path.addQuadCurve(to: CGPoint(x: 112, y: 127 + dy), control: CGPoint(x: 100, y: 147 + dy))
            path.closeSubpath()
            fill(path, stitched ? Color(hex: 0xC2566E) : .ink)
            ellipse(100, 134 + dy, 6, 3, .coral)
        case .hungry:
            ellipse(100, 133 + dy, 7, 8, stitched ? Color(hex: 0xC2566E) : .ink)
        case .sad:
            path.move(to: CGPoint(x: 92, y: 135))
            path.addQuadCurve(to: CGPoint(x: 108, y: 135), control: CGPoint(x: 100, y: 127))
            draw(path)
        case .sick:
            path.move(to: CGPoint(x: 90, y: 133))
            path.addQuadCurve(to: CGPoint(x: 100, y: 133), control: CGPoint(x: 95, y: 128))
            path.addQuadCurve(to: CGPoint(x: 110, y: 133), control: CGPoint(x: 105, y: 138))
            draw(path)
        case .asleep, .sleepy:
            ellipse(100, 133 + dy, 4, 3, stitched ? Color(hex: 0xC2566E) : .ink)
        case .ignoring:
            path.move(to: CGPoint(x: 80, y: 131))
            path.addQuadCurve(to: CGPoint(x: 94, y: 131), control: CGPoint(x: 87, y: 127))
            draw(path)
        }
    }

    // MARK: Primitives

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: Color, rotation: Double = 0, opacity: Double = 1) {
        context.fill(oval(cx, cy, rx, ry, rotation: rotation), with: .color(color.opacity(opacity)))
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
        ForEach(CritterStyle.allCases, id: \.self) { style in
            LiveCritterView(genome: Genome(seed: 31), expression: .happy, style: style)
                .frame(width: 200, height: 200)
        }
    }
    .padding()
    .background(Color.cream)
}
