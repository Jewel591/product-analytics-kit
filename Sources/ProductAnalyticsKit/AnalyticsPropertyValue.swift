import Foundation

/// The complete property-value vocabulary accepted by ProductAnalyticsKit.
///
/// Arrays, dictionaries, arbitrary objects, and dates are intentionally absent.
/// Product analytics should use bounded categories, booleans, counts, and coarse
/// buckets rather than raw records or user content. Dimension values use the
/// same bounded lowercase-token grammar as event names; arbitrary strings are
/// intentionally not representable.
public struct AnalyticsDimension: Sendable, Equatable {
    let rawValue: String

    /// Dimension values must originate from a host-owned bounded enum. Schema
    /// validation still rejects an invalid raw value at capture time.
    public init<Value>(_ value: Value)
    where Value: RawRepresentable & Sendable, Value.RawValue == String {
        rawValue = value.rawValue
    }
}

public enum AnalyticsPropertyValue: Sendable, Equatable {
    case dimension(AnalyticsDimension)
    case int(Int)
    case double(Double)
    case bool(Bool)

    var transportValue: Any {
        switch self {
        case let .dimension(value): value.rawValue
        case let .int(value): value
        case let .double(value): value
        case let .bool(value): value
        }
    }
}
