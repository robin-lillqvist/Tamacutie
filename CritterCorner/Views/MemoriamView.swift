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
                    LiveCritterView(genome: pet.genome, expression: .dead, weight: Rules.healthyWeight, halo: true, style: pet.appearance)
                        .frame(width: 300, height: 300)
                    Text("\(pet.name) har svävat iväg till Molnängen")
                        .font(.cute(36, .bold))
                        .multilineTextAlignment(.center)
                    Text(pet.causeOfDeath == .overeating
                         ? "För mycket godis gjorde \(pet.pronounName)s mage alldeles för rund. Små sötisar behöver lagom mycket mat."
                         : "\(pet.pronounName) var utan mat och vatten alldeles för länge. Små sötisar behöver omsorg varje dag.")
                        .font(.cute(21, .medium))
                        .foregroundStyle(Color(hex: 0x5E4D6E))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 700)
                    Text("\(pet.pronounName) levde i \(pet.ageInDays(at: store.now)) dag\(pet.ageInDays(at: store.now) == 1 ? "" : "ar") och kommer alltid att finnas i våra hjärtan.")
                        .font(.cute(19, .medium))
                        .foregroundStyle(Color(hex: 0x5E4D6E))
                    Button("Minns \(pet.pronounName)") {
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
                        RoundIconButton(systemName: "chevron.left", label: "Tillbaka", shadow: Color(hex: 0xD2C4F5)) { navigate(.home) }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("Till minne").font(.cute(40, .bold))
                            Text("För alltid en del av Sötishörnan").font(.cute(18, .medium)).foregroundStyle(Color(hex: 0x5E4D6E))
                        }
                        Spacer()
                        Color.clear.frame(width: 60, height: 60)
                    }
                    if store.state.memorial.isEmpty {
                        Spacer()
                        Text("Inga sötisar här än. Se till att din är glad och frisk!")
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
                        Button("Välj ett nytt ägg") { navigate(.home) }
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
            LiveCritterView(genome: entry.genome, expression: .dead, halo: true, style: entry.appearance)
                .frame(width: 210, height: 210)
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: entry.genome.palette.stage)))
            Text(entry.name).font(.cute(25, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text("Levde \(entry.daysLived) dag\(entry.daysLived == 1 ? "" : "ar") · \(entry.deathDate.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "sv_SE"))))")
                .font(.cute(16, .medium))
                .foregroundStyle(Color(hex: 0x5E4D6E))
            Text(entry.epitaph)
                .font(.cute(16, .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onCandle) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.butterDeep)
                    Text(entry.candles == 0 ? "Tänd ett ljus" : "\(entry.candles) ljus")
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
                Text("Allt om \(pet.pronounName)").font(.cute(30, .bold))
                Spacer()
                Button("Klar") { dismiss() }.buttonStyle(ChunkyButtonStyle(fill: .butter, shadow: .butterDeep))
            }
            HStack(alignment: .top, spacing: 24) {
                LiveCritterView(genome: pet.genome, expression: pet.expression(at: now), weight: pet.weight, shine: pet.shine(at: now), condition: pet.condition(at: now), coat: .everyday(for: pet), style: pet.appearance)
                    .frame(width: 220, height: 220)
                    .background(RoundedRectangle(cornerRadius: 28).fill(Color(hex: pet.genome.palette.stage)))
                VStack(alignment: .leading, spacing: 10) {
                    Text(pet.name).font(.cute(26, .bold))
                    Text("Dag \(pet.ageInDays(at: now) + 1) · Färg: \(pet.genome.palette.name.lowercased())").font(.cute(18, .medium)).foregroundStyle(Color.inkSoft)
                    HStack {
                        ForEach(pet.genome.traits, id: \.self) { trait in
                            Text(trait.title).font(.cute(16)).padding(.horizontal, 12).padding(.vertical, 5)
                                .background(Capsule().fill(Color(hex: pet.genome.palette.stage)))
                        }
                    }
                    Text("Vikt: \(pet.weightStage.title.lowercased())").font(.cute(20, .bold)).padding(.top, 6)
                    WeightMeter(weight: pet.weight)
                    Text(moodLine).font(.cute(17, .medium)).foregroundStyle(Color.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Bra att veta").font(.cute(20, .bold))
                Text("• Tiden går på riktigt, även när spelet är stängt.\n• För lite mat gör \(pet.pronounName) smal. För mycket godis gör \(pet.pronounName) rund. Båda är farliga.\n• Efter en lång tid ifrån varandra vill \(pet.pronounName) gosa extra mycket. När \(pet.pronounName) är full av kärlek vill \(pet.pronounName) vara ifred en stund.\n• Plocka upp bajset! Ett smutsigt rum gör sötisar sjuka.")
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
        case .excited: "\(pet.pronounName) har saknat dig och vill ha massor av gos!"
        case .ignoring: "\(pet.pronounName) har fått nog med gos för stunden."
        case .asleep: "Sch… sov så gott."
        case .sick: "\(pet.pronounName) är sjuk. Medicin hjälper, och ett rent rum också."
        case .hungry: "\(pet.pronounName) är hungrig eller törstig."
        case .sleepy: "\(pet.pronounName) börjar bli sömnig."
        case .sad: "\(pet.pronounName) mår inte så bra."
        case .happy: "\(pet.pronounName) är jätteglad!"
        case .content, .dead: "\(pet.pronounName) mår bra."
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
        .accessibilityLabel("Viktmätare")
    }
}
