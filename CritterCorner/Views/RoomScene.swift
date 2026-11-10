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

/// The pet's room: furniture, a window onto the real time of day, and little things that move.
struct RoomBackdrop: View {
    let size: CGSize
    var waterLevel: Double = 1
    var foodInBowl = true
    /// The game clock; decides what the window shows and how the room is lit.
    var time: Date = .now

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoomStatic(size: size, waterLevel: waterLevel, foodInBowl: foodInBowl)
            TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                RoomLiving(size: size, time: time, tick: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

/// Where the room's fixed pieces sit, shared by the static and animated layers.
private struct RoomGeometry {
    let size: CGSize
    var floorTop: CGFloat { size.height * 0.66 }
    var window: CGRect { CGRect(x: 720, y: floorTop - 320, width: 240, height: 190) }
    var clock: CGPoint { CGPoint(x: 590, y: floorTop - 280) }
    var shelfY: CGFloat { floorTop - 210 }
    var fishBowl: CGPoint { CGPoint(x: 462, y: shelfY - 24) }
    var lampShade: CGPoint { CGPoint(x: 1090, y: floorTop - 186) }
}

private struct RoomStatic: View {
    let size: CGSize
    let waterLevel: Double
    let foodInBowl: Bool

    var body: some View {
        Canvas { c, _ in
            let g = RoomGeometry(size: size)
            let floorTop = g.floorTop
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

            // Round rug where the critter likes to stand.
            c.oval(640, floorTop + 150, 250, 52, Color(hex: 0xFFD1DC))
            c.outline(Path(ellipseIn: CGRect(x: 640 - 210, y: floorTop + 150 - 38, width: 420, height: 76)), .white, width: 5, dash: [2, 14])

            // Wall shelf with books, a framed heart and the fish bowl.
            c.box(300, g.shelfY, 210, 12, radius: 6, .wood)
            c.box(318, g.shelfY + 12, 10, 22, radius: 4, .woodDeep)
            c.box(482, g.shelfY + 12, 10, 22, radius: 4, .woodDeep)
            c.box(312, g.shelfY - 46, 14, 46, radius: 3, .coral)
            c.box(328, g.shelfY - 54, 14, 54, radius: 3, .mint)
            c.box(344, g.shelfY - 40, 14, 40, radius: 3, .butter)
            c.box(372, g.shelfY - 50, 44, 50, radius: 6, .white)
            c.box(378, g.shelfY - 44, 32, 38, radius: 4, .lavender)
            c.heart(394, g.shelfY - 26, 20, .pink)

            // Floor lamp in the corner; it glows in the evening.
            c.oval(g.lampShade.x, floorTop + 12, 26, 7, Color(hex: 0x8B6B5A))
            c.box(g.lampShade.x - 5, g.lampShade.y + 10, 10, floorTop + 10 - g.lampShade.y - 10, radius: 5, Color(hex: 0x8B6B5A))
            c.shape(.butter) { $0.addLines([
                CGPoint(x: g.lampShade.x - 40, y: g.lampShade.y + 18), CGPoint(x: g.lampShade.x + 40, y: g.lampShade.y + 18),
                CGPoint(x: g.lampShade.x + 26, y: g.lampShade.y - 30), CGPoint(x: g.lampShade.x - 26, y: g.lampShade.y - 30),
            ]) }

            // A potted plant and a stack of toy blocks.
            c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: 1120, y: floorTop + 30), CGPoint(x: 1176, y: floorTop + 30), CGPoint(x: 1168, y: floorTop + 84), CGPoint(x: 1128, y: floorTop + 84)]) }
            c.shape(.leaf) { p in p.move(to: CGPoint(x: 1148, y: floorTop + 30)); p.addQuadCurve(to: CGPoint(x: 1132, y: floorTop - 60), control: CGPoint(x: 1104, y: floorTop - 20)); p.addQuadCurve(to: CGPoint(x: 1148, y: floorTop + 30), control: CGPoint(x: 1152, y: floorTop - 20)) }
            c.shape(.leafDeep) { p in p.move(to: CGPoint(x: 1148, y: floorTop + 30)); p.addQuadCurve(to: CGPoint(x: 1190, y: floorTop - 40), control: CGPoint(x: 1192, y: floorTop)); p.addQuadCurve(to: CGPoint(x: 1148, y: floorTop + 30), control: CGPoint(x: 1160, y: floorTop - 10)) }
            c.box(46, floorTop + 150, 40, 40, radius: 6, .sky)
            c.box(90, floorTop + 150, 40, 40, radius: 6, .butter)
            c.box(66, floorTop + 110, 40, 40, radius: 6, .coral)
            c.star(86, floorTop + 130, 10, .white)

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
    }
}

/// Everything in the room that moves or follows the clock.
private struct RoomLiving: View {
    let size: CGSize
    let time: Date
    let tick: TimeInterval

    var body: some View {
        Canvas { c, _ in
            let g = RoomGeometry(size: size)
            let phase = DayPhase(date: time)
            drawOutside(c, g: g, phase: phase)
            drawWindowAndCurtains(c, g: g)
            drawClock(c, g: g)
            drawBunting(c)
            drawFishBowl(c, g: g)
            drawLight(c, g: g, phase: phase)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: Window

    private func drawOutside(_ base: GraphicsContext, g: RoomGeometry, phase: DayPhase) {
        let w = g.window
        var c = base
        let pane = Path(roundedRect: w, cornerRadius: 24)
        c.clip(to: pane)
        let sky: (UInt32, UInt32) = switch phase {
        case .dawn: (0xFFB8A0, 0xFFE6D0)
        case .day: (0x86C5FF, 0xD9EEFF)
        case .dusk: (0x9C86E0, 0xFFB38A)
        case .night: (0x232958, 0x433C78)
        }
        c.fill(pane, with: .linearGradient(Gradient(colors: [Color(hex: sky.0), Color(hex: sky.1)]), startPoint: CGPoint(x: w.midX, y: w.minY), endPoint: CGPoint(x: w.midX, y: w.maxY)))

        if phase == .night {
            for (index, (x, y)) in [(0.12, 0.15), (0.3, 0.3), (0.5, 0.12), (0.68, 0.25), (0.86, 0.12), (0.4, 0.5), (0.78, 0.45), (0.2, 0.55)].enumerated() {
                let twinkle = 0.55 + 0.45 * sin(tick * 2 + Double(index) * 1.7)
                c.sparkle(w.minX + w.width * x, w.minY + w.height * y, 5 * twinkle + 2, Color(hex: 0xFFE7A0).opacity(twinkle))
            }
            let p = DayPhase.moonProgress(time)
            let moon = CGPoint(x: w.minX + 28 + p * (w.width - 56), y: w.maxY - 60 - sin(p * .pi) * (w.height - 100))
            c.dot(moon.x, moon.y, 20, Color(hex: 0xFFF3C4).opacity(0.25))
            c.dot(moon.x, moon.y, 15, Color(hex: 0xFFF3C4))
            c.dot(moon.x + 7, moon.y - 4, 13, Color(hex: sky.0))
        } else {
            let p = DayPhase.sunProgress(time)
            let sun = CGPoint(x: w.minX + 28 + p * (w.width - 56), y: w.maxY - 50 - sin(p * .pi) * (w.height - 90))
            let sunColor: Color = phase == .day ? .butter : Color(hex: 0xFF9F68)
            c.dot(sun.x, sun.y, 30, sunColor.opacity(0.3))
            c.dot(sun.x, sun.y, 20, sunColor)
            let cloudTint: Color = phase == .day ? .white : Color(hex: 0xFFE0E8)
            for (index, speed) in [(0, 9.0), (1, 6.0)] {
                let span = w.width + 160
                let x = w.minX - 80 + (tick * speed + Double(index) * 130).truncatingRemainder(dividingBy: span)
                let y = w.minY + 40 + CGFloat(index) * 38
                c.oval(x, y, 32, 12, cloudTint.opacity(0.95))
                c.oval(x + 16, y - 9, 20, 13, cloudTint.opacity(0.95))
            }
            if phase == .day {
                let birdX = w.minX - 30 + (tick * 22).truncatingRemainder(dividingBy: w.width + 60)
                for (dx, dy) in [(0.0, 0.0), (18, 8)] {
                    let flap = sin(tick * 10 + dx) * 4
                    c.line(.ink.opacity(0.6), width: 2.5) { path in
                        let x = birdX + dx, y = w.minY + 60 + dy
                        path.move(to: CGPoint(x: x - 7, y: y - flap)); path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 3, y: y - 4))
                        path.addQuadCurve(to: CGPoint(x: x + 7, y: y - flap), control: CGPoint(x: x + 3, y: y - 4))
                    }
                }
            }
        }

        let hills: (UInt32, UInt32) = switch phase {
        case .dawn: (0xB5D69A, 0x9BC983)
        case .day: (0xA8E3B8, 0x7BC96F)
        case .dusk: (0x9C8DC4, 0x7E6FAE)
        case .night: (0x2E3A5C, 0x222C48)
        }
        c.shape(Color(hex: hills.0)) { p in
            p.move(to: CGPoint(x: w.minX, y: w.maxY - 50))
            p.addQuadCurve(to: CGPoint(x: w.maxX, y: w.maxY - 40), control: CGPoint(x: w.midX, y: w.maxY - 96))
            p.addLine(to: CGPoint(x: w.maxX, y: w.maxY)); p.addLine(to: CGPoint(x: w.minX, y: w.maxY))
        }
        c.shape(Color(hex: hills.1)) { p in
            p.move(to: CGPoint(x: w.minX, y: w.maxY - 22))
            p.addQuadCurve(to: CGPoint(x: w.maxX, y: w.maxY - 30), control: CGPoint(x: w.minX + w.width * 0.7, y: w.maxY - 60))
            p.addLine(to: CGPoint(x: w.maxX, y: w.maxY)); p.addLine(to: CGPoint(x: w.minX, y: w.maxY))
        }
        // A little house and a tree on the hill; its window lights up after dark.
        let house = CGPoint(x: w.minX + 70, y: w.maxY - 66)
        c.box(house.x - 16, house.y, 32, 24, Color(hex: phase == .night ? 0x5A5378 : 0xFFF3E3))
        c.shape(Color(hex: phase == .night ? 0x8E4A5E : 0xFF7A8A)) { $0.addLines([CGPoint(x: house.x - 21, y: house.y + 1), CGPoint(x: house.x, y: house.y - 16), CGPoint(x: house.x + 21, y: house.y + 1)]) }
        c.box(house.x - 5, house.y + 7, 10, 9, Color(hex: phase == .night || phase == .dusk ? 0xFFD66B : 0x8EC9FF))
        let tree = CGPoint(x: w.maxX - 56, y: w.maxY - 70)
        c.box(tree.x - 3, tree.y + 4, 6, 24, Color(hex: 0x8B6B5A))
        c.dot(tree.x, tree.y, 17, Color(hex: phase == .night ? 0x2F5245 : 0x5CB85C))
    }

    private func drawWindowAndCurtains(_ c: GraphicsContext, g: RoomGeometry) {
        let w = g.window
        c.outline(Path(roundedRect: w, cornerRadius: 24), .white, width: 14)
        c.line(.white, width: 10) { p in
            p.move(to: CGPoint(x: w.midX, y: w.minY)); p.addLine(to: CGPoint(x: w.midX, y: w.maxY))
            p.move(to: CGPoint(x: w.minX, y: w.midY)); p.addLine(to: CGPoint(x: w.maxX, y: w.midY))
        }
        // Sill with a tiny cactus.
        c.box(w.minX - 20, w.maxY + 2, w.width + 40, 16, radius: 6, .white)
        c.box(w.maxX - 44, w.maxY - 18, 20, 20, radius: 4, .coral)
        c.box(w.maxX - 40, w.maxY - 42, 12, 26, radius: 6, .leaf)
        // Curtain rod and two tied-back curtains that sway a little.
        let rodY = w.minY - 26
        c.box(w.minX - 60, rodY - 4, w.width + 120, 8, radius: 4, .wood)
        c.dot(w.minX - 62, rodY, 8, .woodDeep)
        c.dot(w.maxX + 62, rodY, 8, .woodDeep)
        let sway = sin(tick * 1.1) * 4
        for side in [-1.0, 1.0] {
            let outer = side < 0 ? w.minX - 54 : w.maxX + 54
            let inner = side < 0 ? w.minX + 26 : w.maxX - 26
            let tie = CGPoint(x: side < 0 ? w.minX - 18 : w.maxX + 18, y: w.minY + 110)
            c.shape(.pink) { p in
                p.move(to: CGPoint(x: outer, y: rodY))
                p.addLine(to: CGPoint(x: inner, y: rodY))
                p.addQuadCurve(to: tie, control: CGPoint(x: inner, y: w.minY + 60))
                p.addQuadCurve(to: CGPoint(x: inner - side * 10 + sway, y: w.maxY + 52), control: CGPoint(x: tie.x + side * 4, y: w.maxY))
                p.addLine(to: CGPoint(x: outer + sway, y: w.maxY + 52))
                p.closeSubpath()
            }
            for k in 0..<4 {
                c.dot(outer + (inner - outer) * 0.35 + side * 6, rodY + 30 + CGFloat(k) * 50, 4, .white.opacity(0.7))
            }
            c.oval(tie.x, tie.y, 14, 6, .coralDeep)
        }
    }

    // MARK: Wall bits

    private func drawClock(_ c: GraphicsContext, g: RoomGeometry) {
        let center = g.clock
        c.dot(center.x, center.y, 44, .woodDeep)
        c.dot(center.x, center.y, 36, .cream)
        for hour in 0..<12 {
            let angle = Double(hour) / 12 * 2 * .pi
            c.dot(center.x + sin(angle) * 29, center.y - cos(angle) * 29, hour.isMultiple(of: 3) ? 3 : 1.6, .ink)
        }
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
        let minutes = Double(parts.minute ?? 0) + Double(parts.second ?? 0) / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        func hand(_ fraction: Double, _ length: CGFloat, _ width: CGFloat, _ color: Color) {
            let angle = fraction * 2 * .pi
            c.line(color, width: width) { p in
                p.move(to: center)
                p.addLine(to: CGPoint(x: center.x + sin(angle) * length, y: center.y - cos(angle) * length))
            }
        }
        hand(hours / 12, 18, 5, .ink)
        hand(minutes / 60, 27, 3.5, .ink)
        hand((tick.truncatingRemainder(dividingBy: 60)) / 60, 28, 1.5, .coralDeep)
        c.dot(center.x, center.y, 4, .coralDeep)
    }

    private func drawBunting(_ c: GraphicsContext) {
        let start = CGPoint(x: 300, y: 104)
        let end = CGPoint(x: 660, y: 104)
        let sag: CGFloat = 26
        c.line(.ink.opacity(0.35), width: 2) { p in
            p.move(to: start)
            p.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: start.y + sag * 2))
        }
        let colors: [Color] = [.coral, .butter, .mint, .sky, .lavender, .pink, .butter, .mint]
        for (index, color) in colors.enumerated() {
            let t = (Double(index) + 0.5) / Double(colors.count)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + sag * 2 * 2 * t * (1 - t)
            let swing = sin(tick * 1.6 + Double(index)) * 3
            c.shape(color) { $0.addLines([CGPoint(x: x - 16, y: y), CGPoint(x: x + 16, y: y), CGPoint(x: x + swing, y: y + 30)]) }
        }
    }

    private func drawFishBowl(_ c: GraphicsContext, g: RoomGeometry) {
        let bowl = g.fishBowl
        c.dot(bowl.x, bowl.y, 25, Color(hex: 0xD6ECFF).opacity(0.85))
        c.oval(bowl.x, bowl.y + 6, 22, 16, Color.sky.opacity(0.6))
        let swim = sin(tick * 0.9)
        let fish = CGPoint(x: bowl.x + swim * 9, y: bowl.y + 6 + sin(tick * 2.3) * 3)
        let facing: CGFloat = cos(tick * 0.9) > 0 ? 1 : -1
        c.oval(fish.x, fish.y, 7, 5, Color(hex: 0xFF9F68))
        c.shape(Color(hex: 0xFF9F68)) { $0.addLines([CGPoint(x: fish.x - facing * 6, y: fish.y), CGPoint(x: fish.x - facing * 12, y: fish.y - 5), CGPoint(x: fish.x - facing * 12, y: fish.y + 5)]) }
        c.dot(fish.x + facing * 3, fish.y - 1, 1.2, .ink)
        let rise = CGFloat((tick * 0.6).truncatingRemainder(dividingBy: 1))
        c.dot(fish.x + facing * 8, fish.y - 6 - rise * 20, 2, .white.opacity(1 - rise))
        c.outline(Path(ellipseIn: CGRect(x: bowl.x - 25, y: bowl.y - 25, width: 50, height: 50)), .white.opacity(0.9), width: 3)
        c.oval(bowl.x - 11, bowl.y - 12, 5, 9, .white.opacity(0.6), rotation: 30)
    }

    // MARK: Light

    private func drawLight(_ c: GraphicsContext, g: RoomGeometry, phase: DayPhase) {
        let full = Path(CGRect(origin: .zero, size: size))
        switch phase {
        case .day, .dawn:
            // A sunbeam from the window onto the floor, with dust floating in it.
            let w = g.window
            let shift = (0.5 - DayPhase.sunProgress(time)) * 340
            let beam = Path { p in
                p.move(to: CGPoint(x: w.minX + 10, y: w.maxY + 18))
                p.addLine(to: CGPoint(x: w.maxX - 10, y: w.maxY + 18))
                p.addLine(to: CGPoint(x: w.maxX + shift + 60, y: g.floorTop + 150))
                p.addLine(to: CGPoint(x: w.minX + shift - 60, y: g.floorTop + 150))
                p.closeSubpath()
            }
            c.fill(beam, with: .color(.white.opacity(phase == .day ? 0.16 : 0.1)))
            for index in 0..<8 {
                let rise = CGFloat((tick * 0.05 + Double(index) * 0.13).truncatingRemainder(dividingBy: 1))
                let x = w.minX + 20 + CGFloat(index) * 28 + shift * rise + sin(tick + Double(index)) * 6
                let y = g.floorTop + 140 - rise * (g.floorTop + 140 - w.maxY - 20)
                c.dot(x, y, 2, .white.opacity(0.7 * sin(rise * .pi)))
            }
            if phase == .dawn { c.fill(full, with: .color(Color(hex: 0xFFB38A).opacity(0.06))) }
        case .dusk:
            c.fill(full, with: .color(Color(hex: 0xFF8F5A).opacity(0.08)))
            lampGlow(c, g: g, strength: 0.6)
        case .night:
            c.fill(full, with: .color(Color.ink.opacity(0.16)))
            lampGlow(c, g: g, strength: 1)
        }
    }

    private func lampGlow(_ c: GraphicsContext, g: RoomGeometry, strength: Double) {
        let center = g.lampShade
        let flicker = 0.95 + 0.05 * sin(tick * 3)
        c.fill(
            Path(ellipseIn: CGRect(x: center.x - 220, y: center.y - 160, width: 440, height: 420)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE7A0).opacity(0.55 * strength * flicker), Color(hex: 0xFFE7A0).opacity(0)]),
                center: CGPoint(x: center.x, y: center.y + 10), startRadius: 10, endRadius: 220
            )
        )
        c.dot(center.x, center.y + 4, 22, Color(hex: 0xFFF3C4).opacity(0.9 * strength))
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

