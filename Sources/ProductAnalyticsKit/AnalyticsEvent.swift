import Foundation

public struct AnalyticsEvent: Sendable, Equatable {
    public let name: String
    public let properties: [String: AnalyticsPropertyValue]

    public init(
        name: String,
        properties: [String: AnalyticsPropertyValue] = [:]
    ) throws {
        try AnalyticsValidation.validateEventName(name, allowsStudioPrefix: false)
        try AnalyticsValidation.validateProperties(properties)
        self.name = name
        self.properties = properties
    }

    init(
        studioEvent name: String,
        properties: [String: AnalyticsPropertyValue]
    ) throws {
        try AnalyticsValidation.validateEventName(name, allowsStudioPrefix: true)
        try AnalyticsValidation.validateProperties(properties)
        self.name = name
        self.properties = properties
    }
}
