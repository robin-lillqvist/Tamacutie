import SwiftUI

/// Small drawing vocabulary so the scene art reads like the mockup SVGs.
extension GraphicsContext {
    func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: Color, rotation: Double = 0) {
        let path = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            .applying(CGAffineTransform(translationX: cx, y: cy).rotated(by: rotation * .pi / 180))
        fill(path, with: .color(color))
    }

    func dot(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: Color) {
        oval(cx, cy, r, r, color)
    }

    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0, _ color: Color) {
        fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius, style: .continuous), with: .color(color))
    }

    func outline(_ path: Path, _ color: Color, width: CGFloat, dash: [CGFloat] = []) {
        stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    func shape(_ color: Color, _ build: (inout Path) -> Void) {
        var path = Path()
        build(&path)
        fill(path, with: .color(color))
    }

    func line(_ color: Color, width: CGFloat, dash: [CGFloat] = [], _ build: (inout Path) -> Void) {
        var path = Path()
        build(&path)
        outline(path, color, width: width, dash: dash)
    }

    func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: Color) {
        shape(color) { p in
            for i in 0..<10 {
                let radius = i.isMultiple(of: 2) ? r : r * 0.45
                let angle = Double(i) * .pi / 5 - .pi / 2
                let point = CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
        }
    }

    func heart(_ cx: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ color: Color) {
        shape(color) { p in
            let s = size / 20
            p.move(to: CGPoint(x: cx, y: cy + 8 * s))
            p.addCurve(to: CGPoint(x: cx, y: cy - 6 * s), control1: CGPoint(x: cx - 14 * s, y: cy - 2 * s), control2: CGPoint(x: cx - 8 * s, y: cy - 14 * s))
            p.addCurve(to: CGPoint(x: cx, y: cy + 8 * s), control1: CGPoint(x: cx + 8 * s, y: cy - 14 * s), control2: CGPoint(x: cx + 14 * s, y: cy - 2 * s))
        }
    }

    func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ color: Color) {
        shape(color) { p in
            p.move(to: CGPoint(x: cx, y: cy - r))
            p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.15, y: cy - r * 0.15))
            p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + r * 0.15, y: cy + r * 0.15))
            p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.15, y: cy + r * 0.15))
            p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - r * 0.15, y: cy - r * 0.15))
        }
    }
}

/// A canvas drawn in a fixed design space and scaled to whatever frame it gets.
struct SketchView: View {
    let width: CGFloat
    let height: CGFloat
    let draw: (GraphicsContext) -> Void

    init(width: CGFloat, height: CGFloat, draw: @escaping (GraphicsContext) -> Void) {
        self.width = width
        self.height = height
        self.draw = draw
    }

    var body: some View {
        Canvas { context, size in
            var context = context
            context.scaleBy(x: size.width / width, y: size.height / height)
            draw(context)
        }
        .aspectRatio(width / height, contentMode: .fit)
    }
}

struct CoinIcon: View {
    var size: CGFloat = 34

    var body: some View {
        SketchView(width: 40, height: 40) { c in
            c.dot(20, 20, 17, .butterDeep)
            c.dot(20, 20, 13, .butter)
            c.star(20, 20, 8, .butterDeep)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct HeartIcon: View {
    var size: CGFloat = 30
    var color: Color = .coral

    var body: some View {
        SketchView(width: 30, height: 30) { c in
            c.heart(15, 14, 26, color)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
