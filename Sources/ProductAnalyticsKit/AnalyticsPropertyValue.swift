import Foundation

/// The complete property-value vocabulary accepted by ProductAnalyticsKit.
///
/// Arrays, dictionaries, arbitrary objects, and dates are intentionally absent.
/// Product analytics should use bounded categories, booleans, counts, and coarse
/// buckets rather than raw records or user content.
public enum AnalyticsPropertyValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var transportValue: Any {
        switch self {
        case let .string(value): value
        case let .int(value): value
        case let .double(value): value
        case let .bool(value): value
        }
    }
}
