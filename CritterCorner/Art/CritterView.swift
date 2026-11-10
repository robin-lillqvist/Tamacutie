import CritterKit
import SwiftUI

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

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 200, y: size.height / 200)
            CritterPainter(genome: genome, expression: expression, weight: weight, blinking: blinking || blissful, halo: halo, look: look, context: context).paint()
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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = Double(genome.seed % 1000) / 160
            let breath = 1 + 0.025 * sin(t * 2.2 + phase)
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
            CritterView(genome: genome, expression: expression, weight: weight, blinking: blinkCycle < 0.14, halo: halo, look: eyes, blissful: blissful)
                .scaleEffect(x: (2 - breath) * (facingRight ? 1 : -1), y: breath, anchor: .bottom)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .offset(y: bounce + step)
        }
    }
}

private struct CritterPainter {
    let genome: Genome
    let expression: Mood
    let weight: Double
    let blinking: Bool
    let halo: Bool
    let look: CGVector
    var context: GraphicsContext

    private var body: Color { Color(hex: genome.palette.body) }
    private var belly: Color { Color(hex: genome.palette.belly) }
    private var shade: Color { Color(hex: genome.palette.shade) }
    /// Body width factor: thin critters are narrow, chubby ones wide.
    private var girth: CGFloat { 0.62 + CGFloat(min(max(weight, 0), 100)) / 100 * 0.76 }
    private var spread: CGFloat { 0.8 + 0.2 * girth }

    func paint() {
        ellipse(100, 186, 56 * girth, 8, .ink, opacity: 0.1)
        if halo { wings() }
        tail()
        if genome.head != .sprout && genome.head != .antennae { headFeature() }
        feet()
        torso()
        if genome.head == .sprout || genome.head == .antennae { headFeature() }
        eyes()
        cheeks()
        mouth()
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
                ellipse(x, 62, 16, 40, body, rotation: side * tilt)
                ellipse(x + side * -2, 66, 7, 27, belly, rotation: side * tilt)
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
        switch genome.body {
        case .round:
            ctx.fill(Path(ellipseIn: CGRect(x: 34, y: 60, width: 132, height: 120)), with: .color(body))
            ctx.fill(Path(ellipseIn: CGRect(x: 60, y: 112, width: 80, height: 60)), with: .color(belly))
        case .bean:
            ctx.fill(Path(roundedRect: CGRect(x: 42, y: 54, width: 116, height: 128), cornerRadius: 58), with: .color(body))
            ctx.fill(Path(ellipseIn: CGRect(x: 64, y: 122, width: 72, height: 52)), with: .color(belly))
        case .blob:
            var path = Path()
            path.move(to: CGPoint(x: 40, y: 150))
            path.addCurve(to: CGPoint(x: 100, y: 52), control1: CGPoint(x: 30, y: 92), control2: CGPoint(x: 60, y: 52))
            path.addCurve(to: CGPoint(x: 160, y: 150), control1: CGPoint(x: 140, y: 52), control2: CGPoint(x: 170, y: 92))
            path.addCurve(to: CGPoint(x: 100, y: 182), control1: CGPoint(x: 158, y: 172), control2: CGPoint(x: 140, y: 182))
            path.addCurve(to: CGPoint(x: 40, y: 150), control1: CGPoint(x: 60, y: 182), control2: CGPoint(x: 42, y: 172))
            ctx.fill(path, with: .color(body))
            ctx.fill(Path(ellipseIn: CGRect(x: 62, y: 128, width: 76, height: 44)), with: .color(belly))
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

    private var eyesClosed: Bool {
        blinking || [.asleep, .dead, .ignoring].contains(expression)
    }

    private func eyes() {
        let centers: [CGFloat] = genome.eyes == .cyclops ? [100] : [100 - 22 * spread, 100 + 22 * spread]
        let lookShift: CGFloat = expression == .ignoring ? -12 : 0
        let lx = CGFloat(max(-1, min(1, look.dx))) * 5
        let ly = CGFloat(max(-1, min(1, look.dy))) * 4
        for cx in centers.map({ $0 + lookShift }) {
            let wide: CGFloat = genome.eyes == .cyclops ? 18 : 12
            if eyesClosed {
                var arc = Path()
                switch expression {
                case .asleep, .ignoring:
                    arc.move(to: CGPoint(x: cx - wide, y: 108))
                    arc.addQuadCurve(to: CGPoint(x: cx + wide, y: 108), control: CGPoint(x: cx, y: 118))
                default:
                    arc.move(to: CGPoint(x: cx - wide, y: 112))
                    arc.addQuadCurve(to: CGPoint(x: cx + wide, y: 112), control: CGPoint(x: cx, y: 98))
                }
                stroke(arc, .ink, width: 4.5)
                continue
            }
            if genome.eyes == .cyclops {
                ellipse(cx, 108, 24, 26, .white)
                ellipse(cx + lx * 1.4, 112 + ly, 16, 18, .ink)
                ellipse(cx + 7 + lx * 1.4, 104 + ly, 6, 6, .white)
                ellipse(cx - 5 + lx * 1.4, 119 + ly, 2.5, 2.5, .white)
            } else if expression == .sick {
                ellipse(cx, 113, 11, 7, .ink)
                var lid = Path()
                lid.move(to: CGPoint(x: cx - 13, y: 108))
                lid.addLine(to: CGPoint(x: cx + 13, y: 108))
                stroke(lid, body, width: 6)
            } else {
                let big: CGFloat = expression == .excited ? 1.2 : (expression == .sad ? 0.85 : 1)
                ellipse(cx + lx, 110 + ly, 11 * big, 13 * big, .ink)
                ellipse(cx + lx + 4 * big, 105 + ly, 4.5 * big, 4.5 * big, .white)
                ellipse(cx + lx - 3 * big, 115 + ly, 2 * big, 2 * big, .white)
            }
        }
        if [.sad, .hungry, .sick].contains(expression), genome.eyes == .big {
            for (index, cx) in centers.enumerated() {
                let side: CGFloat = index == 0 ? 1 : -1
                var brow = Path()
                brow.move(to: CGPoint(x: cx - side * 10, y: 97))
                brow.addLine(to: CGPoint(x: cx + side * 5, y: 91))
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
        let opacity = expression == .excited ? 0.6 : 0.45
        let shift: CGFloat = expression == .ignoring ? -12 : 0
        ellipse(100 - 38 * girth + shift, 128, 10, 6, color, opacity: opacity)
        ellipse(100 + 38 * girth + shift, 128, 10, 6, color, opacity: opacity)
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
            stroke(path, .ink, width: 3)
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
