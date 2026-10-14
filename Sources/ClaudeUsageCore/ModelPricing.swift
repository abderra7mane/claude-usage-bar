import Foundation

/// Token counts of one API response, as Claude Code records them in `message.usage`.
/// Decoded with `convertFromSnakeCase`.
struct TokenUsage: Decodable {
    struct CacheCreation: Decodable {
        let ephemeral1hInputTokens: Int?

        /// `convertFromSnakeCase` would turn `1h` into `1H`.
        enum CodingKeys: String, CodingKey {
            case ephemeral1hInputTokens = "ephemeral1HInputTokens"
        }
    }

    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheCreation: CacheCreation?
    let speed: String?

    var promptTokens: Int {
        (inputTokens ?? 0) + (cacheReadInputTokens ?? 0) + (cacheCreationInputTokens ?? 0)
    }
}

/// Anthropic API prices in USD per million tokens. Cache writes cost 1.25x input for the 5-minute TTL
/// and 2x for the 1-hour TTL.
struct ModelPricing: Sendable {
    struct Rates: Sendable {
        let input: Double
        let output: Double
        let cacheRead: Double

        init(input: Double, output: Double, cacheRead: Double? = nil) {
            self.input = input
            self.output = output
            self.cacheRead = cacheRead ?? input * 0.1
        }
    }

    let rates: Rates
    /// Rates for prompts above `longContextThreshold` tokens.
    var longContextRates: Rates?
    var longContextThreshold = 0
    /// Price multiplier for fast mode requests.
    var fastMultiplier = 1.0

    /// Keyed by model id prefix, so dated ids (`claude-haiku-4-5-20251001`) match too.
    static let known: [String: ModelPricing] = [
        "claude-fable-5-1": ModelPricing(rates: Rates(input: 10, output: 50, cacheRead: 0.25)),
        "claude-mythos-5-1": ModelPricing(rates: Rates(input: 10, output: 50, cacheRead: 0.25)),
        "claude-fable-5": ModelPricing(rates: Rates(input: 10, output: 50)),
        "claude-mythos-5": ModelPricing(rates: Rates(input: 10, output: 50)),
        "claude-opus-5-5": ModelPricing(rates: Rates(input: 4, output: 20, cacheRead: 0.2), fastMultiplier: 2),
        "claude-opus-5": ModelPricing(rates: Rates(input: 5, output: 25), fastMultiplier: 2),
        "claude-opus-4-8": ModelPricing(rates: Rates(input: 5, output: 25)),
        "claude-opus-4-7": ModelPricing(rates: Rates(input: 5, output: 25)),
        "claude-opus-4-6": ModelPricing(rates: Rates(input: 5, output: 25)),
        "claude-sonnet-5-5": ModelPricing(rates: Rates(input: 2, output: 10)),
        "claude-sonnet-5": ModelPricing(rates: Rates(input: 2, output: 10)),
        "claude-sonnet-4-6": ModelPricing(rates: Rates(input: 3, output: 15)),
        "claude-haiku-5-5": ModelPricing(
            rates: Rates(input: 0.1, output: 0.5),
            longContextRates: Rates(input: 0.5, output: 2.5),
            longContextThreshold: 100_000
        ),
        "claude-haiku-4-5": ModelPricing(rates: Rates(input: 1, output: 5)),
    ]

    /// The longest matching prefix wins, so `claude-opus-5-5` isn't priced as `claude-opus-5`.
    static func forModel(_ model: String) -> ModelPricing? {
        known
            .filter { model.hasPrefix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
    }

    func cost(of usage: TokenUsage) -> Double {
        let rates = usage.promptTokens > longContextThreshold ? longContextRates ?? rates : rates
        let cacheWrites = usage.cacheCreationInputTokens ?? 0
        let oneHourWrites = min(usage.cacheCreation?.ephemeral1hInputTokens ?? 0, cacheWrites)
        let fiveMinuteWrites = cacheWrites - oneHourWrites

        let total = Double(usage.inputTokens ?? 0) * rates.input
            + Double(usage.outputTokens ?? 0) * rates.output
            + Double(usage.cacheReadInputTokens ?? 0) * rates.cacheRead
            + Double(fiveMinuteWrites) * rates.input * 1.25
            + Double(oneHourWrites) * rates.input * 2
        let multiplier = usage.speed == "fast" ? fastMultiplier : 1
        return total * multiplier / 1_000_000
    }
}
