import CritterKit
import SwiftUI

enum Screen: String, Hashable {
    case home, market, bath, park, decor, memoriam
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen = Screen.home
    @State private var toaster = Toaster()

    var body: some View {
        ZStack(alignment: .top) {
            content
                .transition(.opacity)
            if let message = toaster.message {
                ToastView(text: message)
                    .padding(.top, 24)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .environment(toaster)
        .environment(\.navigate) { screen = $0 }
        .task {
            #if DEBUG
            applyDebugLaunchArguments()
            #endif
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                store.tick()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: welcomeBack()
            case .background:
                store.save()
                Reminders.schedule(for: store.pet)
            default: break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if screen == .memoriam {
            MemoriamView()
        } else if let pet = store.pet {
            if !pet.isAlive {
                FarewellView(pet: pet)
            } else {
                switch screen {
                case .home: HomeView()
                case .market: MarketView()
                case .bath: BathView()
                case .park: ParkView()
                case .decor: DecorView()
                case .memoriam: MemoriamView()
                }
            }
        } else {
            AdoptView()
        }
    }

    #if DEBUG
    /// `-demoPet YES -screen park` jumps straight to a screen with a pet, for screenshots.
    private func applyDebugLaunchArguments() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "demoPet"), store.pet == nil {
            store.perform { state, now in
                _ = state.adopt(genome: Genome(seed: 2024), name: NameGenerator.name(seed: 2024), now: now)
                state.earn(400)
            }
        }
        if let raw = defaults.string(forKey: "screen"), let target = Screen(rawValue: raw) {
            screen = target
        }
    }
    #endif

    private func welcomeBack() {
        store.tick()
        guard store.pet?.isAlive == true else { return }
        let missed = store.perform { state, now in state.pet?.registerVisit(at: now) ?? false }
        if missed, let pet = store.pet {
            toaster.show("\(pet.pronounName) missed you so much!")
        } else if let gift = store.perform({ state, now in state.claimDailyGift(now: now) }) {
            toaster.show("Daily gift: +\(gift) coins!")
        }
    }
}

private struct NavigateKey: EnvironmentKey {
    static let defaultValue: (Screen) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigate: (Screen) -> Void {
        get { self[NavigateKey.self] }
        set { self[NavigateKey.self] = newValue }
    }
}
