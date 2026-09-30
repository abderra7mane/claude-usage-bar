public enum UsageLevel: Sendable, Equatable {
    case ok
    case warning
    case critical

    public static let warningThreshold = 75.0
    public static let criticalThreshold = 100.0

    public init(utilization: Double) {
        switch utilization {
        case ..<Self.warningThreshold: self = .ok
        case ..<Self.criticalThreshold: self = .warning
        default: self = .critical
        }
    }
}
