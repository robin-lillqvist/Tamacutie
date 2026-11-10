import CritterKit
import SwiftUI

struct EggChoice: Identifiable {
    let genome: Genome
    var name: String
    var id: UInt64 { genome.seed }

    static func random() -> EggChoice {
        let genome = Genome.random()
        return EggChoice(genome: genome, name: NameGenerator.name(seed: genome.seed))
    }
}

struct AdoptView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.navigate) private var navigate
    @State private var eggs = (0..<6).map { _ in EggChoice.random() }
    @State private var picked = 0
    @State private var hatching = false
    @State private var style = CritterStyle.vinyl

    var body: some View {
        DesignCanvas(background: .cream) { size in
            ZStack(alignment: .topLeading) {
                SketchView(width: 1194, height: 834) { c in
                    c.dot(1120, 70, 120, .pinkLight)
                    c.dot(60, 800, 140, .mintLight)
                    c.sparkle(980, 60, 20, .butter)
                    c.sparkle(140, 772, 13, .lavender)
                }
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

                VStack(spacing: 22) {
                    header
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 22), count: 3), spacing: 22) {
                        ForEach(Array(eggs.enumerated()), id: \.element.id) { index, egg in
                            EggCard(egg: egg, selected: index == picked, style: style) { picked = index }
                        }
                    }
                    Spacer(minLength: 0)
                    footer
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 32)
                .frame(width: size.width, height: size.height)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    SketchView(width: 48, height: 48) { c in
                        c.dot(24, 30, 12, .coral)
                        for (x, y) in [(11.0, 17.0), (20, 10), (30, 10), (38, 17)] { c.dot(x, y, 5.5, .coral) }
                    }
                    .frame(width: 48, height: 48)
                    Text("Kryphörnan").font(.cute(44, .bold))
                }
                Text(store.state.memorial.isEmpty ? "Välj ett ägg. Varje kryp som kläcks är helt unikt." : "Redo för en ny vän? Välj ett ägg.")
                    .font(.cute(20, .medium))
                    .foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if !store.state.memorial.isEmpty {
                Button { navigate(.memoriam) } label: {
                    Label("Minnen", systemImage: "heart.text.square.fill")
                }
                .buttonStyle(ChunkyButtonStyle(fill: .white, shadow: .lavender))
            }
            Button {
                withAnimation(.spring) {
                    eggs = (0..<6).map { _ in EggChoice.random() }
                    picked = 0
                }
            } label: {
                Label("Nya ägg", systemImage: "dice.fill")
            }
            .buttonStyle(ChunkyButtonStyle(fill: .white, shadow: Color(hex: 0xF3E3D3)))
        }
        .foregroundStyle(Color.ink)
    }

    private var footer: some View {
        let egg = eggs[picked]
        let parts = egg.name.split(separator: " ")
        return HStack(spacing: 10) {
            Text("Namnmaskinen:").font(.cute(18, .medium)).foregroundStyle(Color.inkSoft)
            ForEach(parts.map(String.init), id: \.self) { part in
                Text(part)
                    .font(.cute(18))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Color(hex: 0xE0CDBE), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
            }
            Button {
                withAnimation(.spring) { eggs[picked].name = NameGenerator.name(seed: UInt64.random(in: .min ... .max)) }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white))
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel("Nytt namn")
            Spacer()
            stylePicker(for: egg)
            Spacer()
            Button("Kläck \(egg.name)") { hatch(egg) }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(hatching)
        }
        .foregroundStyle(Color.ink)
    }

    /// The picked egg drawn in each style; tap one to choose how your critter will look.
    private func stylePicker(for egg: EggChoice) -> some View {
        HStack(spacing: 8) {
            Text("Stil:").font(.cute(18, .medium)).foregroundStyle(Color.inkSoft)
            ForEach(CritterStyle.allCases, id: \.self) { candidate in
                Button {
                    withAnimation(.spring) { style = candidate }
                    SoundFX.play(.boop)
                } label: {
                    VStack(spacing: 0) {
                        CritterView(genome: egg.genome, expression: .happy, style: candidate)
                            .frame(width: 52, height: 52)
                        Text(candidate.title).font(.cute(12)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(Color.ink)
                    .frame(width: 74, height: 76)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(candidate == style ? Color.coral : Color(hex: 0xF3E3D3), lineWidth: candidate == style ? 4 : 2))
                }
                .buttonStyle(SquishyButtonStyle())
                .accessibilityIdentifier("style-\(candidate.rawValue)")
                .accessibilityLabel("Stil: \(candidate.title)")
                .accessibilityAddTraits(candidate == style ? .isSelected : [])
            }
        }
    }

    private func hatch(_ egg: EggChoice) {
        hatching = true
        Reminders.requestPermission()
        let chosen = style
        store.perform { state, now in _ = state.adopt(genome: egg.genome, name: egg.name, style: chosen, now: now) }
        navigate(.home)
    }
}

private struct EggCard: View {
    let egg: EggChoice
    let selected: Bool
    let style: CritterStyle
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            VStack(spacing: 8) {
                LiveCritterView(genome: egg.genome, expression: selected ? .excited : .content, style: style)
                    .frame(width: 140, height: 140)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: egg.genome.palette.stage)))
                Text(egg.name)
                    .font(.cute(24, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    ForEach(egg.genome.traits, id: \.self) { trait in
                        Text(trait.title)
                            .font(.cute(15, .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(hex: egg.genome.palette.stage)))
                    }
                }
            }
            .foregroundStyle(Color.ink)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(selected ? Color.coral : Color(hex: 0xF3E3D3), lineWidth: 4))
            .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(selected ? Color(hex: 0xFFD0DA) : Color(hex: 0xF3E3D3)).offset(y: 10))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.coral))
                        .padding(14)
                }
            }
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel("\(egg.name), \(egg.genome.traits.map(\.title).joined(separator: ", "))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
