import CritterKit
import SwiftUI

/// Holds the live camera for a scrolling world. Not observed: the camera steps every frame,
/// and the view only re-renders when `publish` hands it a new x.
@MainActor
final class WorldCamera {
    var camera: Camera
    private var lastPan: CGFloat?
    private var panned = false

    init(worldWidth: CGFloat, viewportWidth: CGFloat, x: CGFloat = 0) {
        camera = Camera(worldWidth: Double(worldWidth), viewportWidth: Double(viewportWidth), x: Double(x))
    }

    /// Re-creates the camera when the screen size changes, keeping the view where it was.
    func resize(worldWidth: CGFloat, viewportWidth: CGFloat) {
        guard camera.worldWidth != Double(worldWidth) || camera.viewportWidth != Double(viewportWidth) else { return }
        camera = Camera(worldWidth: Double(worldWidth), viewportWidth: Double(viewportWidth), x: camera.x)
    }

    var x: CGFloat { CGFloat(camera.x) }

    /// Finger moved; returns true once it counts as a swipe rather than a touch.
    func drag(translation: CGFloat) -> Bool {
        if !panned, abs(translation) > 12 { panned = true }
        guard panned else { return false }
        camera.pan(by: Double(translation - (lastPan ?? 0)))
        lastPan = translation
        return true
    }

    /// Finger lifted; returns true if it was a swipe.
    func endDrag(velocity: CGFloat) -> Bool {
        let wasPan = panned
        if wasPan { camera.fling(velocity: Double(velocity)) }
        panned = false
        lastPan = nil
        return wasPan
    }

    /// Runs the camera at display rate, calling `follow` for what it should keep on screen and
    /// `publish` whenever the view needs to move.
    func run(follow: @escaping () -> CGFloat?, publish: @escaping (CGFloat) -> Void) async {
        var last = Date()
        var published = x
        publish(published)
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date()
            camera.step(min(0.05, now.timeIntervalSince(last)))
            last = now
            if let target = follow() { camera.follow(Double(target)) }
            if abs(x - published) > 0.25 {
                published = x
                publish(published)
            }
        }
    }
}

/// Round pastel arrows at the screen edges: there's more to see this way. Tap to glide over.
struct EdgeArrows: View {
    let cameraX: CGFloat
    let worldWidth: CGFloat
    let size: CGSize
    var y: CGFloat
    var fill: Color = .white
    let page: (_ right: Bool) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if cameraX > 1 {
                arrow(right: false).position(x: 44, y: y)
            }
            if cameraX < worldWidth - size.width - 1 {
                arrow(right: true).position(x: size.width - 44, y: y)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func arrow(right: Bool) -> some View {
        Button { page(right) } label: {
            Image(systemName: right ? "chevron.right" : "chevron.left")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Color.ink)
                .frame(width: 64, height: 64)
                .background(Circle().fill(fill.opacity(0.92)))
                .shadow(color: Color.ink.opacity(0.12), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityIdentifier(right ? "scroll-right" : "scroll-left")
        .accessibilityValue("\(Int(cameraX))")
        .accessibilityLabel(right ? "Titta åt höger" : "Titta åt vänster")
    }
}
