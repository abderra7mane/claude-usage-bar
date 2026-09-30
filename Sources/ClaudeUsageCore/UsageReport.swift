import Foundation

public struct UsageWindow: Decodable, Sendable, Equatable {
    public let utilization: Double
    public let resetsAt: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    /// A window whose reset time has passed is back at zero, even before the next fetch confirms it.
    public func effectiveUtilization(at now: Date) -> Double {
        if let resetsAt, resetsAt <= now { return 0 }
        return utilization
    }

    public func level(at now: Date) -> UsageLevel {
        UsageLevel(utilization: effectiveUtilization(at: now))
    }

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        utilization = try container.decode(Double.self, forKey: .utilization)
        resetsAt = try container.decodeIfPresent(String.self, forKey: .resetsAt).flatMap(Self.parseDate)
    }

    static func parseDate(_ string: String) -> Date? {
        if let date = try? Date(string, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .colon)) {
            return date
        }
        return try? Date(string, strategy: .iso8601)
    }
}

public struct UsageReport: Decodable, Sendable, Equatable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?

    public init(fiveHour: UsageWindow?, sevenDay: UsageWindow?) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}
