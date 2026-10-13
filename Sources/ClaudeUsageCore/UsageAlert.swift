public enum UsageAlert {
    public static let thresholds: [Double] = [75, 80, 85, 90, 95, 100]

    /// The highest threshold passed when usage moved from `previous` to `current`, so a jump over several
    /// thresholds between two checks alerts once.
    public static func threshold(crossedFrom previous: Double, to current: Double) -> Double? {
        thresholds.last { previous < $0 && $0 <= current }
    }
}
