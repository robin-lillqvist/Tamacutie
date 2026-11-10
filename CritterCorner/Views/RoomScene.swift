import CritterKit
import SwiftUI

/// The pet's room: wallpaper, floor, window and the built-in bed and bowls, plus any placed decor.
struct RoomLayout {
    let size: CGSize
    var floorTop: CGFloat { size.height * 0.66 }
    var petCenter: CGPoint { CGPoint(x: 640, y: size.height * 0.86 - 150) }
    var bowlCenter: CGPoint { CGPoint(x: 960, y: floorTop + 90) }

    func point(for decor: PlacedDecor) -> CGPoint {
        CGPoint(x: decor.x * size.width, y: decor.y * size.height)
    }

    func normalised(_ point: CGPoint) -> (x: Double, y: Double) {
        (Double(point.x / size.width), Double(point.y / size.height))
    }

    /// Poops land on the floor, clear of the dock at the bottom.
    func point(for poop: Poop) -> CGPoint {
        let usableHeight = max(40, size.height - floorTop - 190)
        return CGPoint(x: 80 + poop.x * (size.width - 160), y: floorTop + 40 + poop.y * usableHeight)
    }
}

struct RoomBackdrop: View {
    let size: CGSize
    var waterLevel: Double = 1
    var foodInBowl = true

    var body: some View {
        Canvas { c, _ in
            let floorTop = size.height * 0.66
            c.box(0, 0, size.width, floorTop, .pinkLight)
            var y: CGFloat = 11
            var row = 0
            while y < floorTop {
                var x: CGFloat = row.isMultiple(of: 2) ? 11 : 33
                while x < size.width {
                    c.dot(x, y, 4, Color(hex: 0xFFD0DE))
                    x += 44
                }
                y += 22
                row += 1
            }
            c.box(0, floorTop - 14, size.width, 18, .white)
            c.box(0, floorTop + 4, size.width, size.height - floorTop, Color(hex: 0xF3C99B))
            c.line(Color(hex: 0xE5B585), width: 3) { p in
                for offset in stride(from: 54.0, to: size.height - floorTop, by: 74) {
                    p.move(to: CGPoint(x: 0, y: floorTop + offset)); p.addLine(to: CGPoint(x: size.width, y: floorTop + offset))
                }
                for (x, row) in [(200.0, 0.0), (520, 1), (860, 0), (340, 2), (1000, 2), (680, 3)] {
                    let top = floorTop + 4 + row * 74
                    p.move(to: CGPoint(x: x, y: top)); p.addLine(to: CGPoint(x: x, y: top + 50))
                }
            }

            // Window with a little sky.
            c.box(770, 104, 230, 180, radius: 28, Color(hex: 0xBFE6FF))
            c.outline(Path(roundedRect: CGRect(x: 770, y: 104, width: 230, height: 180), cornerRadius: 28), .white, width: 14)
            c.line(.white, width: 10) { p in
                p.move(to: CGPoint(x: 885, y: 104)); p.addLine(to: CGPoint(x: 885, y: 284))
                p.move(to: CGPoint(x: 770, y: 194)); p.addLine(to: CGPoint(x: 1000, y: 194))
            }
            c.dot(950, 146, 22, .butter)
            c.oval(820, 240, 34, 14, .white)
            c.oval(840, 230, 22, 16, .white)
            c.shape(.pink) { p in
                p.move(to: CGPoint(x: 760, y: 90))
                p.addQuadCurve(to: CGPoint(x: 1010, y: 90), control: CGPoint(x: 885, y: 130))
                p.addLine(to: CGPoint(x: 1010, y: 120))
                p.addQuadCurve(to: CGPoint(x: 760, y: 120), control: CGPoint(x: 885, y: 150))
                p.closeSubpath()
            }

            // Bed.
            c.oval(300, floorTop + 40, 112, 40, .lavenderDeep)
            c.oval(300, floorTop + 30, 86, 24, Color(hex: 0xD9CCFF))
            c.oval(340, floorTop + 24, 28, 12, .white)

            // Food and water bowls.
            let bowl = CGPoint(x: 930, y: floorTop + 100)
            if foodInBowl {
                c.dot(bowl.x - 18, bowl.y - 16, 6, .poopLight)
                c.dot(bowl.x - 4, bowl.y - 20, 6, Color(hex: 0xC48B5C))
                c.dot(bowl.x + 10, bowl.y - 16, 6, .poopLight)
            }
            c.oval(bowl.x, bowl.y, 44, 14, .coralDeep)
            c.shape(.coral) { $0.addLines([CGPoint(x: bowl.x - 44, y: bowl.y - 14), CGPoint(x: bowl.x + 44, y: bowl.y - 14), CGPoint(x: bowl.x + 36, y: bowl.y + 2), CGPoint(x: bowl.x - 36, y: bowl.y + 2)]) }
            let water = CGPoint(x: 1040, y: floorTop + 120)
            c.oval(water.x, water.y, 44, 14, .skyDeep)
            c.shape(.sky) { $0.addLines([CGPoint(x: water.x - 44, y: water.y - 14), CGPoint(x: water.x + 44, y: water.y - 14), CGPoint(x: water.x + 36, y: water.y + 2), CGPoint(x: water.x - 36, y: water.y + 2)]) }
            if waterLevel > 0.05 {
                c.oval(water.x, water.y - 14, 36 * min(1, 0.4 + waterLevel), 6, Color(hex: 0xD6ECFF))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

struct PoopView: View {
    var body: some View {
        SketchView(width: 64, height: 60) { c in
            c.oval(32, 54, 32, 6, .ink.opacity(0.12))
            c.oval(32, 44, 28, 11, .poop)
            c.oval(32, 32, 20, 10, .poopLight)
            c.shape(Color(hex: 0xC48B5C)) { p in
                p.move(to: CGPoint(x: 24, y: 26))
                p.addQuadCurve(to: CGPoint(x: 38, y: 22), control: CGPoint(x: 32, y: 6))
                p.closeSubpath()
            }
            c.dot(26, 32, 2.6, .ink)
            c.dot(38, 32, 2.6, .ink)
        }
        .frame(width: 64, height: 60)
    }
}

struct StinkLines: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            SketchView(width: 70, height: 40) { c in
                for i in 0..<3 {
                    let x = 12 + CGFloat(i) * 22
                    let sway = sin(t * 3 + Double(i)) * 4
                    c.line(Color(hex: 0x9AB87A), width: 3) { p in
                        p.move(to: CGPoint(x: x, y: 38))
                        p.addQuadCurve(to: CGPoint(x: x, y: 4), control: CGPoint(x: x + sway * 2, y: 20))
                    }
                }
            }
        }
        .frame(width: 70, height: 40)
        .opacity(0.8)
        .allowsHitTesting(false)
    }
}

struct PlacedDecorView: View {
    let decor: PlacedDecor
    let layout: RoomLayout

    var body: some View {
        let size = DecorArt.size(for: decor.itemID)
        DecorArt(id: decor.itemID, flipped: decor.flipped)
            .frame(width: size.width, height: size.height)
            .position(layout.point(for: decor))
    }
}
