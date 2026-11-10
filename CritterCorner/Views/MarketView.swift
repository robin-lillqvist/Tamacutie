import CritterKit
import SwiftUI

struct MarketView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate
    @State private var aisle = Aisle.food
    @State private var basket: [String: Int] = [:]
    @State private var cashierLine = "Welcome to Paws & Peas!"

    private static let cashier = Genome(seed: 77, body: .round, head: .pointyEars, eyes: .big, tail: .lightning, marking: .forehead, paletteIndex: 3, traits: [])
    private let shadow = Color(hex: 0xBFE5D8)

    private var total: Int {
        basket.reduce(0) { sum, entry in sum + (Catalog.item(entry.key)?.price ?? 0) * entry.value }
    }

    var body: some View {
        DesignCanvas(background: Color(hex: 0xE9F7F2)) { size in
            ZStack(alignment: .top) {
                Awning(width: size.width).frame(width: size.width, height: 100)
                VStack(spacing: 20) {
                    HStack {
                        RoundIconButton(systemName: "chevron.left", label: "Back home", shadow: shadow) { navigate(.home) }
                        Spacer()
                        TitlePill(title: "Paws & Peas Market", shadow: shadow)
                        Spacer()
                        CoinPill(coins: store.state.coins, shadow: shadow)
                    }
                    .padding(.top, 8)
                    HStack(alignment: .top, spacing: 20) {
                        aisles
                        shelves
                        basketPanel(height: size.height - 140)
                    }
                }
                .padding(24)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private var aisles: some View {
        VStack(spacing: 10) {
            ForEach(Aisle.allCases, id: \.self) { candidate in
                Button { aisle = candidate } label: {
                    Text(candidate.title)
                        .font(.cute(19))
                        .foregroundStyle(candidate == aisle ? .white : Color.ink)
                        .frame(width: 160, height: 64)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(candidate == aisle ? Color.ink : .white))
                }
                .buttonStyle(SquishyButtonStyle())
                .accessibilityAddTraits(candidate == aisle ? .isSelected : [])
            }
            Text("Too many treats make your critter chubby!")
                .font(.cute(15, .medium))
                .padding(14)
                .frame(width: 160)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color.butterLight))
                .padding(.top, 8)
        }
    }

    private var shelves: some View {
        let items = Catalog.items(in: aisle)
        let rows = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
        return VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    ForEach(row) { item in productCard(item) }
                    ForEach(0..<(4 - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                }
                .padding(.horizontal, 14)
                Capsule().fill(Color.wood).frame(height: 22)
                    .background(Capsule().fill(Color.woodDeep).offset(y: 8))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func productCard(_ item: Item) -> some View {
        VStack(spacing: 6) {
            ItemArt(id: item.id).frame(width: 96, height: 96)
            Text(item.packSize > 1 ? "\(item.name) ×\(item.packSize)" : item.name)
                .font(.cute(18)).lineLimit(1).minimumScaleFactor(0.7)
            Text(item.blurb)
                .font(.cute(14, .medium))
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(Capsule().fill(Color.peachLight))
            Text("You have \(store.state.count(of: item.id))")
                .font(.cute(13, .medium)).foregroundStyle(Color.inkSoft)
            Button {
                basket[item.id, default: 0] += 1
                cashierLine = ["Ooh, good choice!", "Yummy pick!", "Anything else?", "Your critter will love that!"].randomElement()!
            } label: {
                HStack(spacing: 4) {
                    CoinIcon(size: 22)
                    Text("\(item.price)")
                }
                .font(.cute(18, .bold))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(Color.coral))
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel("Add \(item.name) to basket, \(item.price) coins")
        }
        .foregroundStyle(Color.ink)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white))
    }

    private func basketPanel(height: CGFloat) -> some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Basket", systemImage: "basket.fill").font(.cute(22, .bold))
                if basket.isEmpty {
                    Text("Tap a price to add it.").font(.cute(17, .medium)).foregroundStyle(Color.inkSoft)
                }
                ForEach(basket.keys.sorted(), id: \.self) { id in
                    if let item = Catalog.item(id) {
                        HStack {
                            Text("\(item.name) ×\(basket[id]!)").font(.cute(17, .medium))
                            Spacer()
                            Text("\(item.price * basket[id]!)").font(.cute(17))
                            Button { removeOne(id) } label: {
                                Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundStyle(Color.coralDeep)
                            }
                            .accessibilityLabel("Remove one \(item.name)")
                        }
                    }
                }
                Rectangle().fill(Color(hex: 0xF0E6EE)).frame(height: 2)
                HStack {
                    Text("Total").font(.cute(20, .bold))
                    Spacer()
                    Text("\(total) coins").font(.cute(20, .bold))
                        .foregroundStyle(total > store.state.coins ? Color.coralDeep : Color.ink)
                }
                Button("Pay at the till") { checkout() }
                    .buttonStyle(ChunkyButtonStyle(fill: .butter, shadow: .butterDeep))
                    .frame(maxWidth: .infinity)
                    .disabled(basket.isEmpty)
                    .opacity(basket.isEmpty ? 0.5 : 1)
            }
            .foregroundStyle(Color.ink)
            .padding(18)
            .card(shadow: shadow)

            Spacer(minLength: 0)
            ZStack(alignment: .topLeading) {
                VStack(spacing: -40) {
                    LiveCritterView(genome: Self.cashier, expression: .happy)
                        .frame(width: 150, height: 150)
                    SketchView(width: 270, height: 90) { c in
                        c.box(0, 0, 270, 90, radius: 20, .mint)
                        c.box(0, 0, 270, 18, radius: 9, .mintDeep)
                        c.line(.white.opacity(0.7), width: 6) { p in
                            p.move(to: CGPoint(x: 30, y: 44)); p.addLine(to: CGPoint(x: 90, y: 44))
                            p.move(to: CGPoint(x: 30, y: 64)); p.addLine(to: CGPoint(x: 70, y: 64))
                        }
                        c.box(180, 30, 70, 44, radius: 10, .pink)
                        c.box(190, 38, 50, 16, radius: 5, .ink)
                    }
                    .frame(width: 270, height: 90)
                }
                .padding(.top, 40)
                SpeechBubble(text: cashierLine)
            }
        }
        .frame(width: 290, height: height)
    }

    private func removeOne(_ id: String) {
        basket[id, default: 0] -= 1
        if basket[id]! <= 0 { basket[id] = nil }
    }

    private func checkout() {
        guard total <= store.state.coins else {
            cashierLine = "Not enough coins! Scoop poop or play at the park to earn more."
            return
        }
        let order = basket
        store.perform { state, _ in
            for (id, quantity) in order { _ = state.buy(id, quantity: quantity) }
        }
        basket = [:]
        cashierLine = "Thank you! Come again!"
        toaster.show("Bought! Find it in your fridge and cupboard.")
    }
}

private struct Awning: View {
    let width: CGFloat

    var body: some View {
        Canvas { c, _ in
            let scallop: CGFloat = 75
            var x: CGFloat = 0
            var index = 0
            while x < width {
                let color: Color = index.isMultiple(of: 2) ? .white : .mint
                c.shape(color) { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + scallop, y: 0))
                    p.addLine(to: CGPoint(x: x + scallop, y: 60))
                    p.addQuadCurve(to: CGPoint(x: x, y: 60), control: CGPoint(x: x + scallop / 2, y: 90))
                    p.closeSubpath()
                }
                x += scallop
                index += 1
            }
        }
        .allowsHitTesting(false)
    }
}
