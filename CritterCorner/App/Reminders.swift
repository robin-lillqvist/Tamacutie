import CritterKit
import Foundation
import UserNotifications

/// Gentle local notifications so a pet is not forgotten while the app is closed.
enum Reminders {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(for pet: Pet?) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard let pet, pet.isAlive else { return }
        let first = pet.pronounName

        func remind(_ id: String, after hours: Double, _ body: String) {
            guard hours > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "Kryphörnan"
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, hours * 3600), repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        remind("hungry", after: (pet.needs.hunger - 20) / Rules.hungerDecay, "\(first) börjar bli hungrig!")
        remind("thirsty", after: (pet.needs.thirst - 20) / Rules.thirstDecay, "\(first)s vattenskål är nästan tom.")
        remind("lonely", after: 12, "\(first) saknar dig. Kom och säg hej!")
        remind("worried", after: 30, "\(first) har inte ätit på länge och börjar bli smal. Snälla, kom tillbaka!")
        if pet.weightStage.isDangerous {
            remind("danger", after: 1, "\(first) mår inte bra. Kom och titta till!")
        }
    }
}
