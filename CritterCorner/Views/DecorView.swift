import CritterKit
import SwiftUI

struct DecorView: View {
    @Environment(GameStore.self) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.navigate) private var navigate

    @State private var category = DecorCategory.furniture
    @State private var chosenItem = "sofa"
    @State private var selectedDecor: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var draggingID: UUID?

    private let shadow = Color(hex: 0xD9CCFF)

    var body: some View {
        DesignCanvas(background: .lavenderLight) { size in
            let layout = RoomLayout(size: size)
            ZStack(alignment: .topLeading) {
                RoomBackdrop(size: size)
                floorGrid(layout: layout)

                ForEach(store.state.room) { decor in
                    decorItem(decor, layout: layout)
                }

                if let pet = store.pet {
                    LiveCritterView(genome: pet.genome, expression: .happy, weight: pet.weight, shine: pet.shine(at: store.now), condition: pet.condition(at: store.now), coat: .everyday(for: pet), style: pet.appearance)
                        .frame(width: 150, height: 150)
                        .position(x: 110, y: size.height - 120)
                        .allowsHitTesting(false)
                }

                topBar
                    .position(x: 400, y: 24 + 32)

                if let id = selectedDecor, let decor = store.state.room.first(where: { $0.id == id }) {
                    selectionTools(for: decor, layout: layout)
                }

                shopPanel(height: size.height)
                    .position(x: size.width - 187, y: size.height / 2)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            RoundIconButton(systemName: "chevron.left", label: "Tillbaka hem", shadow: shadow) { navigate(.home) }
            VStack(alignment: .leading, spacing: 2) {
                Text("Mysighet").font(.cute(15, .medium)).foregroundStyle(Color.inkSoft)
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: 0xF0E8FA))
                            Capsule().fill(Color.coral).frame(width: geo.size.width * CGFloat(store.state.cosiness) / 100)
                        }
                    }
                    .frame(width: 140, height: 12)
                    Text("\(store.state.cosiness)").font(.cute(18, .bold))
                }
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 20)
            .frame(height: 64)
            .card(shadow: shadow, radius: 32)
            Text("Dra för att flytta · tryck för att välja")
                .font(.cute(16))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Capsule().fill(Color.ink))
        }
        .frame(width: 760, alignment: .leading)
    }

    private func floorGrid(layout: RoomLayout) -> some View {
        Canvas { c, size in
            c.line(.white.opacity(0.7), width: 2) { p in
                for x in stride(from: 0.0, through: size.width, by: 60) {
                    p.move(to: CGPoint(x: x, y: layout.floorTop + 4)); p.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: layout.floorTop + 64, through: size.height, by: 60) {
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .allowsHitTesting(false)
    }

    private func decorItem(_ decor: PlacedDecor, layout: RoomLayout) -> some View {
        let size = DecorArt.size(for: decor.itemID)
        let isDragging = draggingID == decor.id
        let point = layout.point(for: decor)
        return DecorArt(id: decor.itemID, flipped: decor.flipped)
            .frame(width: size.width, height: size.height)
            .overlay {
                if selectedDecor == decor.id {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                        .padding(-12)
                }
            }
            .scaleEffect(isDragging ? 1.05 : 1)
            .position(x: point.x + (isDragging ? dragOffset.width : 0), y: point.y + (isDragging ? dragOffset.height : 0))
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        draggingID = decor.id
                        selectedDecor = decor.id
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let target = CGPoint(x: point.x + value.translation.width, y: point.y + value.translation.height)
                        let normalised = layout.normalised(target)
                        store.perform { state, _ in state.move(decor.id, x: normalised.x, y: normalised.y) }
                        draggingID = nil
                        dragOffset = .zero
                    }
            )
            .onTapGesture { selectedDecor = selectedDecor == decor.id ? nil : decor.id }
            .accessibilityLabel(Catalog.item(decor.itemID)?.name ?? "Dekoration")
            .accessibilityAddTraits(.isButton)
    }

    private func selectionTools(for decor: PlacedDecor, layout: RoomLayout) -> some View {
        let size = DecorArt.size(for: decor.itemID)
        let point = layout.point(for: decor)
        return HStack(spacing: 10) {
            Button { store.perform { state, _ in state.flip(decor.id) } } label: {
                Label("Vänd", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
            }
            .buttonStyle(ChunkyButtonStyle(fill: .white, shadow: shadow))
            Button {
                store.perform { state, _ in state.putAway(decor.id) }
                selectedDecor = nil
            } label: {
                Label("Plocka undan", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(ChunkyButtonStyle())
        }
        .position(x: min(max(point.x, 220), 600), y: max(130, point.y - size.height / 2 - 50))
    }

    private func shopPanel(height: CGFloat) -> some View {
        let items = Catalog.decor(in: category)
        let chosen = Catalog.item(chosenItem)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Myshörnans butik").font(.cute(26, .bold))
                Spacer()
                HStack(spacing: 4) {
                    CoinIcon(size: 28)
                    Text("\(store.state.coins)").font(.cute(20, .bold))
                }
            }
            HStack(spacing: 8) {
                ForEach(DecorCategory.allCases, id: \.self) { candidate in
                    Button { category = candidate } label: {
                        Text(candidate.title)
                            .font(.cute(15))
                            .foregroundStyle(candidate == category ? .white : Color.ink)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Capsule().fill(candidate == category ? Color.ink : Color.lavenderLight))
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
            }
            VGrid(columns: 2, spacing: 12, items: items) { item in
                        Button { chosenItem = item.id } label: {
                            VStack(spacing: 4) {
                                ItemArt(id: item.id).frame(width: 110, height: 80)
                                Text(item.name).font(.cute(16)).lineLimit(1).minimumScaleFactor(0.8)
                                Text(store.state.count(of: item.id) > 0 ? "Du har ×\(store.state.count(of: item.id))" : "\(item.price) mynt")
                                    .font(.cute(15, .bold))
                                    .foregroundStyle(store.state.count(of: item.id) > 0 ? Color.mintDeep : Color.ink)
                            }
                            .foregroundStyle(Color.ink)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xF7F2FF)))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.ink, lineWidth: chosenItem == item.id ? 3 : 0))
                        }
                        .buttonStyle(SquishyButtonStyle())
                }
            .padding(4)
            Spacer(minLength: 0)
            if let chosen {
                Text("\(chosen.name) · \(chosen.blurb) · +\(chosen.cosiness) mys")
                    .font(.cute(15, .medium))
                    .foregroundStyle(Color.inkSoft)
                HStack(spacing: 10) {
                    Button("Köp · \(chosen.price)") { buy(chosen) }
                        .buttonStyle(ChunkyButtonStyle(fill: .white, shadow: shadow))
                    Button("Ställ ut") { place(chosen) }
                        .buttonStyle(ChunkyButtonStyle())
                        .disabled(store.state.count(of: chosen.id) == 0)
                        .opacity(store.state.count(of: chosen.id) == 0 ? 0.5 : 1)
                }
            }
        }
        .foregroundStyle(Color.ink)
        .padding(24)
        .frame(width: 374, height: height)
        .background(UnevenRoundedRectangle(topLeadingRadius: 36, bottomLeadingRadius: 36, style: .continuous).fill(.white))
        .background(UnevenRoundedRectangle(topLeadingRadius: 36, bottomLeadingRadius: 36, style: .continuous).fill(shadow).offset(x: -6))
    }

    private func buy(_ item: Item) {
        switch store.perform({ state, _ in state.buy(item.id) }) {
        case .bought: toaster.show("\(item.name) köpt! Tryck på ”Ställ ut”.")
        case .notEnoughCoins: toaster.show("Inte tillräckligt med mynt än. Ta hand om ditt kryp så tjänar du mer!")
        case .unknownItem: break
        }
    }

    private func place(_ item: Item) {
        let y = item.decorLayer == .wall ? 0.3 : 0.78
        let placed = store.perform { state, _ in state.place(item.id, x: .random(in: 0.2...0.55), y: y) }
        selectedDecor = placed?.id
    }
}
