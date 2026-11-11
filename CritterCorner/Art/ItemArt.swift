import SwiftUI

/// Shop items and supplies, drawn in a 100×100 space.
struct ItemArt: View {
    let id: String

    var body: some View {
        SketchView(width: 100, height: 100) { c in
            switch id {
            case "kibble":
                c.shape(Color(hex: 0xF2814A)) { $0.addLines([CGPoint(x: 24, y: 22), CGPoint(x: 76, y: 22), CGPoint(x: 73, y: 12), CGPoint(x: 27, y: 12)]) }
                c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: 24, y: 22), CGPoint(x: 76, y: 22), CGPoint(x: 70, y: 92), CGPoint(x: 30, y: 92)]) }
                c.dot(50, 56, 16, .butterLight)
                c.box(40, 52, 20, 8, radius: 4, .poopLight)
                for (x, y) in [(40.0, 52.0), (40, 60), (60, 52), (60, 60)] { c.dot(x, y, 4.5, .poopLight) }
            case "fish":
                c.shape(.skyDeep) { $0.addLines([CGPoint(x: 70, y: 50), CGPoint(x: 92, y: 34), CGPoint(x: 92, y: 66)]) }
                c.oval(46, 50, 32, 20, .sky)
                c.shape(.skyDeep) { p in p.move(to: CGPoint(x: 40, y: 32)); p.addQuadCurve(to: CGPoint(x: 58, y: 32), control: CGPoint(x: 48, y: 20)) }
                c.dot(28, 46, 4, .ink)
                c.dot(29.5, 44.5, 1.4, .white)
                c.line(Color(hex: 0xD6ECFF), width: 3) { p in
                    p.move(to: CGPoint(x: 48, y: 40)); p.addQuadCurve(to: CGPoint(x: 48, y: 60), control: CGPoint(x: 54, y: 50))
                    p.move(to: CGPoint(x: 58, y: 40)); p.addQuadCurve(to: CGPoint(x: 58, y: 60), control: CGPoint(x: 64, y: 50))
                }
            case "carrot":
                c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: 50, y: 90), CGPoint(x: 30, y: 34), CGPoint(x: 70, y: 34)]) }
                c.line(Color(hex: 0xF2814A), width: 3) { p in
                    p.move(to: CGPoint(x: 38, y: 52)); p.addLine(to: CGPoint(x: 62, y: 52))
                    p.move(to: CGPoint(x: 42, y: 66)); p.addLine(to: CGPoint(x: 58, y: 66))
                }
                c.shape(.leaf) { p in p.move(to: CGPoint(x: 50, y: 34)); p.addQuadCurve(to: CGPoint(x: 40, y: 10), control: CGPoint(x: 32, y: 18)); p.addQuadCurve(to: CGPoint(x: 50, y: 34), control: CGPoint(x: 48, y: 18)) }
                c.shape(.leafDeep) { p in p.move(to: CGPoint(x: 50, y: 34)); p.addQuadCurve(to: CGPoint(x: 72, y: 24), control: CGPoint(x: 66, y: 16)); p.addQuadCurve(to: CGPoint(x: 50, y: 34), control: CGPoint(x: 62, y: 32)) }
            case "berries":
                c.dot(36, 60, 16, .lavenderDeep)
                c.dot(64, 60, 16, Color(hex: 0x8E6CF0))
                c.dot(50, 40, 16, .lavender)
                c.dot(45, 35, 4, .white.opacity(0.7))
                c.line(.leafDeep, width: 4) { p in p.move(to: CGPoint(x: 50, y: 24)); p.addQuadCurve(to: CGPoint(x: 64, y: 14), control: CGPoint(x: 54, y: 14)) }
            case "cupcake":
                c.shape(Color(hex: 0xFFD1DC)) { $0.addLines([CGPoint(x: 26, y: 52), CGPoint(x: 74, y: 52), CGPoint(x: 66, y: 88), CGPoint(x: 34, y: 88)]) }
                c.line(.pink, width: 3) { p in for x in stride(from: 36.0, through: 64, by: 9) { p.move(to: CGPoint(x: x, y: 56)); p.addLine(to: CGPoint(x: x, y: 86)) } }
                c.dot(36, 46, 13, .cream)
                c.dot(64, 46, 13, .cream)
                c.dot(50, 38, 16, .cream)
                c.dot(50, 20, 7, .coralDeep)
                c.dot(42, 40, 2, .mint)
                c.dot(58, 44, 2, .butter)
                c.dot(50, 48, 2, .lavender)
            case "cookie":
                c.star(50, 52, 38, Color(hex: 0xE8B27A))
                c.star(50, 52, 30, Color(hex: 0xF3C99B))
                c.dot(44, 48, 3, .poop)
                c.dot(56, 58, 3, .poop)
                c.dot(52, 42, 2.5, .coral)
            case "lollipop":
                c.box(47, 52, 6, 42, radius: 3, .white)
                c.dot(50, 36, 30, .coral)
                c.dot(50, 36, 23, .butter)
                c.dot(50, 36, 16, .mint)
                c.dot(50, 36, 9, .sky)
                c.dot(50, 36, 4, .lavender)
                c.dot(40, 24, 5, .white.opacity(0.7))
            case "icecream":
                c.shape(Color(hex: 0xE8B27A)) { $0.addLines([CGPoint(x: 30, y: 50), CGPoint(x: 70, y: 50), CGPoint(x: 50, y: 94)]) }
                c.line(Color(hex: 0xC98E55), width: 2.5) { p in
                    p.move(to: CGPoint(x: 36, y: 56)); p.addLine(to: CGPoint(x: 58, y: 78))
                    p.move(to: CGPoint(x: 64, y: 56)); p.addLine(to: CGPoint(x: 42, y: 78))
                }
                c.dot(40, 44, 14, .pinkLight)
                c.dot(60, 44, 14, Color(hex: 0xFFE3A3))
                c.dot(50, 28, 16, .mintLight)
                c.dot(50, 10, 6, .coralDeep)
                c.dot(44, 24, 4, .white.opacity(0.8))
            case "soda":
                c.box(30, 24, 40, 68, radius: 12, .pink)
                c.box(30, 24, 40, 18, radius: 12, .pinkLight)
                c.box(30, 34, 40, 8, .pinkLight)
                c.line(.white, width: 5) { p in p.move(to: CGPoint(x: 58, y: 30)); p.addLine(to: CGPoint(x: 70, y: 4)) }
                c.dot(42, 60, 4, .white.opacity(0.8))
                c.dot(54, 72, 3, .white.opacity(0.8))
                c.dot(46, 80, 2.5, .white.opacity(0.8))
                c.star(50, 56, 9, .butter)
            case "water":
                c.box(36, 10, 28, 12, radius: 4, .skyDeep)
                c.box(30, 22, 40, 68, radius: 12, Color(hex: 0xD6ECFF))
                c.box(30, 46, 40, 26, .sky)
                c.shape(.white) { p in p.move(to: CGPoint(x: 50, y: 50)); p.addCurve(to: CGPoint(x: 50, y: 68), control1: CGPoint(x: 58, y: 60), control2: CGPoint(x: 56, y: 68)); p.addCurve(to: CGPoint(x: 50, y: 50), control1: CGPoint(x: 44, y: 68), control2: CGPoint(x: 42, y: 60)) }
            case "shampoo":
                c.box(44, 8, 12, 14, radius: 3, .lavenderDeep)
                c.box(36, 22, 28, 8, .lavender)
                c.box(30, 30, 40, 60, radius: 14, Color(hex: 0xECE4FF))
                c.dot(50, 60, 12, .white)
                c.dot(46, 56, 4, .lavender)
                c.dot(55, 63, 3, .lavender)
                c.dot(74, 22, 6, .white)
                c.dot(82, 34, 4, .white)
            case "medicine":
                c.box(20, 36, 60, 28, radius: 14, .white)
                c.box(50, 36, 30, 28, radius: 14, .coral)
                c.box(50, 36, 14, 28, .coral)
                c.line(.coral, width: 4) { p in
                    p.move(to: CGPoint(x: 30, y: 50)); p.addLine(to: CGPoint(x: 40, y: 50))
                    p.move(to: CGPoint(x: 35, y: 45)); p.addLine(to: CGPoint(x: 35, y: 55))
                }
                c.outline(Path(roundedRect: CGRect(x: 20, y: 36, width: 60, height: 28), cornerRadius: 14), .coral, width: 3)
            default:
                DecorArt.draw(id, in: c, size: CGSize(width: 100, height: 100))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Room decorations, each drawn in its own natural size (design points in the 1194-wide room).
struct DecorArt: View {
    let id: String
    var flipped = false

    static func size(for id: String) -> CGSize {
        switch id {
        case "sofa": CGSize(width: 320, height: 170)
        case "royalBed": CGSize(width: 240, height: 100)
        case "bookshelf": CGSize(width: 160, height: 300)
        case "rug": CGSize(width: 440, height: 110)
        case "fern": CGSize(width: 120, height: 170)
        case "cactus": CGSize(width: 90, height: 130)
        case "moonLamp": CGSize(width: 100, height: 200)
        case "fairyLights": CGSize(width: 320, height: 60)
        case "starPoster": CGSize(width: 130, height: 150)
        case "clock": CGSize(width: 100, height: 160)
        case "rainbow": CGSize(width: 170, height: 110)
        default: CGSize(width: 100, height: 100)
        }
    }

    var body: some View {
        let size = Self.size(for: id)
        SketchView(width: size.width, height: size.height) { c in
            Self.draw(id, in: c, size: size)
        }
        .scaleEffect(x: flipped ? -1 : 1)
        .accessibilityHidden(true)
    }

    /// Draws into `size`; when used as a shop thumbnail the context gets the item's natural size fitted into a square.
    static func draw(_ id: String, in context: GraphicsContext, size: CGSize) {
        var c = context
        let natural = Self.size(for: id)
        if natural != size {
            let scale = min(size.width / natural.width, size.height / natural.height)
            c.translateBy(x: (size.width - natural.width * scale) / 2, y: (size.height - natural.height * scale) / 2)
            c.scaleBy(x: scale, y: scale)
        }
        switch id {
        case "sofa":
            c.box(0, 40, 320, 110, radius: 40, .lavenderDeep)
            c.box(20, 0, 280, 90, radius: 36, .lavender)
            c.box(0, 70, 70, 86, radius: 30, Color(hex: 0x8E6CF0))
            c.box(250, 70, 70, 86, radius: 30, Color(hex: 0x8E6CF0))
            c.box(70, 86, 90, 42, radius: 18, Color(hex: 0xD9CCFF))
            c.box(160, 86, 90, 42, radius: 18, Color(hex: 0xD9CCFF))
            c.box(30, 150, 14, 20, radius: 5, Color(hex: 0x6B4F86))
            c.box(276, 150, 14, 20, radius: 5, Color(hex: 0x6B4F86))
            c.oval(110, 42, 30, 22, .butter)
        case "royalBed":
            c.oval(120, 60, 118, 38, .lavenderDeep)
            c.oval(120, 50, 92, 24, Color(hex: 0xD9CCFF))
            c.oval(160, 44, 28, 12, .white)
            c.star(70, 26, 14, .butter)
        case "bookshelf":
            c.box(0, 0, 160, 300, radius: 18, .wood)
            for y in [16.0, 110, 204] { c.box(14, y, 132, 80, radius: 10, .woodDeep) }
            c.box(24, 42, 16, 54, radius: 4, .coral)
            c.box(44, 32, 16, 64, radius: 4, .mint)
            c.box(64, 46, 16, 50, radius: 4, .butter)
            c.dot(110, 166, 18, .leaf)
            c.box(98, 166, 24, 20, radius: 6, Color(hex: 0xFF9F68))
            c.box(30, 240, 40, 44, radius: 8, .lavender)
        case "rug":
            c.oval(220, 55, 218, 52, .pinkLight)
            c.outline(Path(ellipseIn: CGRect(x: 52, y: 20, width: 336, height: 70)), .white, width: 6, dash: [2, 16])
            c.heart(220, 52, 40, .pink)
        case "fern":
            c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: 30, y: 110), CGPoint(x: 90, y: 110), CGPoint(x: 80, y: 168), CGPoint(x: 40, y: 168)]) }
            c.shape(.leaf) { p in p.move(to: CGPoint(x: 60, y: 110)); p.addQuadCurve(to: CGPoint(x: 52, y: 6), control: CGPoint(x: 20, y: 40)); p.addQuadCurve(to: CGPoint(x: 60, y: 110), control: CGPoint(x: 70, y: 60)) }
            c.shape(.leafDeep) { p in p.move(to: CGPoint(x: 60, y: 110)); p.addQuadCurve(to: CGPoint(x: 118, y: 30), control: CGPoint(x: 112, y: 70)); p.addQuadCurve(to: CGPoint(x: 60, y: 110), control: CGPoint(x: 80, y: 60)) }
            c.shape(.leafDeep) { p in p.move(to: CGPoint(x: 60, y: 110)); p.addQuadCurve(to: CGPoint(x: 2, y: 50), control: CGPoint(x: 8, y: 90)); p.addQuadCurve(to: CGPoint(x: 60, y: 110), control: CGPoint(x: 40, y: 70)) }
        case "cactus":
            c.box(25, 90, 40, 38, radius: 8, .coral)
            c.box(30, 10, 30, 86, radius: 15, .leaf)
            c.box(8, 40, 18, 34, radius: 9, .leaf)
            c.box(64, 30, 18, 30, radius: 9, .leaf)
            c.dot(40, 44, 2.5, .ink)
            c.dot(52, 44, 2.5, .ink)
            c.line(.ink, width: 2) { p in p.move(to: CGPoint(x: 42, y: 52)); p.addQuadCurve(to: CGPoint(x: 50, y: 52), control: CGPoint(x: 46, y: 57)) }
            c.dot(45, 6, 7, .pink)
        case "moonLamp":
            c.box(44, 70, 12, 120, radius: 6, Color(hex: 0x8B6B5A))
            c.oval(50, 192, 34, 8, Color(hex: 0x8B6B5A))
            c.shape(.butter) { $0.addLines([CGPoint(x: 12, y: 74), CGPoint(x: 88, y: 74), CGPoint(x: 74, y: 14), CGPoint(x: 26, y: 14)]) }
            c.shape(.butterDeep) { p in p.addArc(center: CGPoint(x: 50, y: 44), radius: 14, startAngle: .degrees(-60), endAngle: .degrees(160), clockwise: false); p.addQuadCurve(to: CGPoint(x: 57, y: 32), control: CGPoint(x: 50, y: 46)) }
        case "fairyLights":
            c.line(.ink.opacity(0.4), width: 2) { p in
                p.move(to: CGPoint(x: 0, y: 10))
                for i in 0..<4 { let x = CGFloat(i) * 80; p.addQuadCurve(to: CGPoint(x: x + 80, y: 10), control: CGPoint(x: x + 40, y: 46)) }
            }
            for (i, color) in [Color.butter, .pink, .sky, .butter, .pink, .sky, .butter, .pink].enumerated() {
                let x = 20 + CGFloat(i) * 40
                c.dot(x, 30 + (i.isMultiple(of: 2) ? 0 : 6), 9, color)
            }
        case "starPoster":
            c.box(0, 0, 130, 150, radius: 16, .white)
            c.box(12, 12, 106, 126, radius: 10, .lavender)
            c.star(65, 74, 34, .butter)
        case "clock":
            c.shape(.wood) { $0.addLines([CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 40), CGPoint(x: 0, y: 40)]) }
            c.box(10, 36, 80, 80, radius: 14, .woodDeep)
            c.dot(50, 76, 28, .cream)
            c.line(.ink, width: 4) { p in p.move(to: CGPoint(x: 50, y: 76)); p.addLine(to: CGPoint(x: 50, y: 58)); p.move(to: CGPoint(x: 50, y: 76)); p.addLine(to: CGPoint(x: 64, y: 82)) }
            c.line(.butterDeep, width: 3) { p in p.move(to: CGPoint(x: 40, y: 116)); p.addLine(to: CGPoint(x: 40, y: 146)); p.move(to: CGPoint(x: 60, y: 116)); p.addLine(to: CGPoint(x: 60, y: 136)) }
            c.dot(40, 150, 7, .butterDeep)
            c.dot(60, 140, 7, .butterDeep)
        case "rainbow":
            for (i, color) in [Color.coral, .butter, .mint, .sky, .lavender].enumerated() {
                let r = 80 - CGFloat(i) * 12
                c.outline(Path { p in p.addArc(center: CGPoint(x: 85, y: 100), radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false) }, color, width: 11)
            }
            c.oval(26, 98, 24, 12, .white)
            c.oval(144, 98, 24, 12, .white)
        default:
            c.dot(size.width / 2, size.height / 2, min(size.width, size.height) / 3, .lavender)
        }
    }
}
