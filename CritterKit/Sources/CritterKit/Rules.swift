import Foundation

/// Every tuning number in one place. Rates are per real-world hour.
public enum Rules {
    public static let hungerDecay = 6.0
    public static let thirstDecay = 8.0
    public static let energyDecayAwake = 4.0
    public static let energyGainAsleep = 14.0
    public static let hygieneDecay = 2.0
    public static let hygieneDecayPerPoop = 0.5
    public static let funDecay = 5.0
    public static let loveDecay = 3.0
    public static let asleepHungerThirstFactor = 0.5
    public static let sickDecayFactor = 1.5
    public static let traitFactor = 1.3

    public static let fallAsleepBelowEnergy = 8.0

    public static let healthyWeight = 50.0
    public static let hungryBelow = 15.0
    public static let weightLossHungry = 0.3
    public static let weightLossStarving = 0.6
    public static let weightLossDehydrated = 0.3
    public static let weightRecoveryRate = 0.3
    public static let weightSettleRate = 0.15
    public static let overflowToWeight = 0.2

    public static let digestionDelay: TimeInterval = 45 * 60

    public static let strokeLove = 4.0
    public static let missedYouAfter: TimeInterval = 24 * 3600
    public static let missedYouDuration: TimeInterval = 3600
    public static let loveFullCooldown: TimeInterval = 15 * 60
    /// Strokes and tickles closer together than this don't count, so rubbing fast isn't spam.
    public static let strokeInterval: TimeInterval = 0.9
    public static let tickleInterval: TimeInterval = 1.2
    /// Strokes after love is full: a warning first, grumpy only if you keep going.
    public static let overPetWarning = 3
    public static let overPetLimit = 7
    /// A pause this long forgives earlier over-petting.
    public static let overPetForgiveAfter: TimeInterval = 20
    public static let tickleFun = 4.0
    public static let tickleLove = 1.0
    /// Sweets put a smile on its face for this long.
    public static let sweetJoyDuration: TimeInterval = 20 * 60

    public static let dirtyPoopCount = 4
    public static let dirtyHygieneBelow = 10.0
    public static let hoursDirtyUntilSick = 6.0

    public static let shineDuration: TimeInterval = 3 * 3600
    public static let shampooShineDuration: TimeInterval = 8 * 3600

    public static let simulationStep: TimeInterval = 60

    public static let startingCoins = 100
    public static let scoopReward = 2
    public static let bathReward = 5
    public static let piggyRatePerHour = 3.0
    public static let piggyCap = 50.0
    public static let piggyMoodThreshold = 70.0
    public static let dailyGiftBase = 20
    public static let dailyGiftStreakBonus = 5
    public static let dailyGiftMax = 50
}
