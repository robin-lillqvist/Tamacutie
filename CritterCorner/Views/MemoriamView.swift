import CritterKit
import SwiftUI

struct FarewellView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.navigate) private var navigate
    let pet: Pet

    var body: some View {
        DesignCanvas(background: Color(hex: 0xE9E0FF)) { size in
            ZStack {
                MemorialSky(size: size)
                VStack(spacing: 20) {
                    LiveCritterView(genome: pet.genome, expression: .dead, weight: Rules.healthyWeight, halo: true)
                        .frame(width: 300, height: 300)
                    Text("\(pet.name) has floated off to Cloud Meadow")
                        .font(.cute(36, .bold))
                        .multilineTextAlignment(.center)
                    Text(pet.causeOfDeath == .overeating
                         ? "Too many treats made \(pet.pronounName)'s tummy too round. Little critters need just the right amount of food."
                         : "\(pet.pronounName) went too long without food and water. Little critters need care every day.")
                        .font(.cute(21, .medium))
                        .foregroundStyle(Color(hex: 0x5E4D6E))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 700)
                    Text("\(pet.pronounName) lived \(pet.ageInDays(at: store.now)) days and will always be remembered.")
                        .font(.cute(19, .medium))
                        .foregroundStyle(Color(hex: 0x5E4D6E))
                    Button("Remember \(pet.pronounName)") {
                        store.perform { state, _ in state.sayGoodbye() }
                        navigate(.memoriam)
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 10)
                }
                .foregroundStyle(Color.ink)
                .padding(40)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

struct MemoriamView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.navigate) private var navigate

    var body: some View {
        DesignCanvas(background: Color(hex: 0xE9E0FF)) { size in
            ZStack(alignment: .top) {
                MemorialSky(size: size)
                VStack(spacing: 18) {
                    HStack {
                        RoundIconButton(systemName: "chevron.left", label: "Back", shadow: Color(hex: 0xD2C4F5)) { navigate(.home) }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("In Memoriam").font(.cute(40, .bold))
                            Text("Forever part of Critter Corner").font(.cute(18, .medium)).foregroundStyle(Color(hex: 0x5E4D6E))
                        }
                        Spacer()
                        Color.clear.frame(width: 60, height: 60)
                    }
                    if store.state.memorial.isEmpty {
                        Spacer()
                        Text("No critters here yet. Keep yours happy and healthy!")
                            .font(.cute(24, .medium))
                            .foregroundStyle(Color(hex: 0x5E4D6E))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40), count: 3), spacing: 40) {
                                ForEach(Array(store.state.memorial.enumerated()), id: \.element.id) { index, entry in
                                    Polaroid(entry: entry, tilt: [-3, 2, -2, 3][index % 4]) {
                                        store.perform { state, _ in state.lightCandle(for: entry.id) }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                    if store.pet == nil {
                        Button("Adopt a new egg") { navigate(.home) }
                            .buttonStyle(ChunkyButtonStyle())
                    }
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 40)
                .padding(.vertical, 28)
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

private struct Polaroid: View {
    let entry: MemorialEntry
    let tilt: Double
    let onCandle: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            LiveCritterView(genome: entry.genome, expression: .dead, halo: true)
                .frame(width: 210, height: 210)
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: entry.genome.palette.stage)))
            Text(entry.name).font(.cute(25, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text("Lived \(entry.daysLived) day\(entry.daysLived == 1 ? "" : "s") · \(entry.deathDate.formatted(.dateTime.month(.wide).year()))")
                .font(.cute(16, .medium))
                .foregroundStyle(Color(hex: 0x5E4D6E))
            Text(entry.epitaph)
                .font(.cute(16, .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onCandle) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.butterDeep)
                    Text(entry.candles == 0 ? "Light a candle" : "\(entry.candles) candle\(entry.candles == 1 ? "" : "s")")
                }
                .font(.cute(16))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Capsule().fill(Color.butterLight))
            }
            .buttonStyle(SquishyButtonStyle())
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16))
        .background(RoundedRectangle(cornerRadius: 18).fill(.white))
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: 0xD2C4F5)).offset(y: 10))
        .rotationEffect(.degrees(tilt))
    }
}

private struct MemorialSky: View {
    let size: CGSize

    var body: some View {
        Canvas { c, _ in
            c.oval(160, 120, 70, 24, .white)
            c.oval(200, 102, 42, 28, .white)
            c.oval(1030, 90, 64, 22, .white)
            c.oval(996, 74, 36, 24, .white)
            for (x, y, r) in [(90.0, 70.0, 12.0), (1120, 186, 9), (820, 58, 9), (330, 74, 6)] {
                c.sparkle(x, y, r, .butter)
            }
            let ground = size.height - 110
            c.shape(Color(hex: 0xC9EDD6)) { p in
                p.move(to: CGPoint(x: 0, y: ground))
                p.addQuadCurve(to: CGPoint(x: 600, y: ground), control: CGPoint(x: 300, y: ground - 60))
                p.addQuadCurve(to: CGPoint(x: size.width, y: ground), control: CGPoint(x: 900, y: ground + 60))
                p.addLine(to: CGPoint(x: size.width, y: size.height))
                p.addLine(to: CGPoint(x: 0, y: size.height))
            }
            for (x, color) in [(80.0, Color.pink), (220, .lavender), (980, .white), (1110, .pink)] {
                c.line(.leafDeep, width: 4) { p in p.move(to: CGPoint(x: x, y: ground + 50)); p.addLine(to: CGPoint(x: x, y: ground + 20)) }
                c.dot(x, ground + 16, 10, color)
                c.dot(x, ground + 16, 4, .butter)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

struct AboutPetView: View {
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    let now: Date

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("All about \(pet.pronounName)").font(.cute(30, .bold))
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(ChunkyButtonStyle(fill: .butter, shadow: .butterDeep))
            }
            HStack(alignment: .top, spacing: 24) {
                LiveCritterView(genome: pet.genome, expression: pet.expression(at: now), weight: pet.weight, shine: pet.shine(at: now), condition: pet.condition(at: now), coat: .everyday(for: pet))
                    .frame(width: 220, height: 220)
                    .background(RoundedRectangle(cornerRadius: 28).fill(Color(hex: pet.genome.palette.stage)))
                VStack(alignment: .leading, spacing: 10) {
                    Text(pet.name).font(.cute(26, .bold))
                    Text("Day \(pet.ageInDays(at: now) + 1) · \(pet.genome.palette.name) critter").font(.cute(18, .medium)).foregroundStyle(Color.inkSoft)
                    HStack {
                        ForEach(pet.genome.traits, id: \.self) { trait in
                            Text(trait.title).font(.cute(16)).padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Capsule().fill(Color(hex: pet.genome.palette.stage)))
                        }
                    }
                    Text("Weight: \(pet.weightStage.title)").font(.cute(20, .bold)).padding(.top, 6)
                    WeightMeter(weight: pet.weight)
                    Text(moodLine).font(.cute(17, .medium)).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Good to know").font(.cute(20, .bold))
                Text("• Time passes for real, even when the game is closed.\n• Too little food makes \(pet.pronounName) thin. Too many treats make \(pet.pronounName) round. Both are dangerous.\n• After a long time apart, \(pet.pronounName) will be extra cuddly. Once full of love, \(pet.pronounName) wants some space.\n• Scoop the poop! A dirty room makes critters sick.")
                    .font(.cute(17, .medium))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.ink)
        .padding(32)
        .background(Color.cream)
        .presentationDetents([.large])
    }

    private var moodLine: String {
        switch pet.expression(at: now) {
        case .excited: "\(pet.pronounName) missed you and wants all the cuddles!"
        case .ignoring: "\(pet.pronounName) has had enough cuddles for now."
        case .asleep: "Shh… sweet dreams."
        case .sick: "\(pet.pronounName) feels sick. Medicine helps, and so does a clean room."
        case .hungry: "\(pet.pronounName) is hungry or thirsty."
        case .sleepy: "\(pet.pronounName) is getting sleepy."
        case .sad: "\(pet.pronounName) is not feeling great."
        case .happy: "\(pet.pronounName) is very happy!"
        case .content, .dead: "\(pet.pronounName) is doing fine."
        }
    }
}

struct WeightMeter: View {
    let weight: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(Array([Color.coralDeep, .butter, .mint, .butter, .coralDeep].enumerated()), id: \.offset) { _, color in
                        Capsule().fill(color)
                    }
                }
                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(Color.ink, lineWidth: 3))
                    .frame(width: 24, height: 24)
                    .offset(x: geo.size.width * min(max(weight, 0), 100) / 100 - 12)
            }
        }
        .frame(width: 360, height: 24)
        .accessibilityLabel("Weight meter")
    }
}
