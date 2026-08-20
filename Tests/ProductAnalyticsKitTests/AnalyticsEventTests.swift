import Testing
@testable import ProductAnalyticsKit

struct AnalyticsEventTests {
    private enum Dimension: String, Sendable {
        case toolbar
        case bounded
        case freeForm = "how to hide a purchase"
        case uuid = "550e8400-e29b-41d4-a716-446655440000"
        case email = "person@example.com"
        case filename = "report.pdf"
        case nonASCII = "提醒内容"
        case oversized = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    }

    @Test func acceptsBoundedSchemaValues() throws {
        try AnalyticsValidation.validateEventName(
            "reminder_created",
            allowsStudioPrefix: false
        )
        try AnalyticsValidation.validateProperties([
            "source": .dimension(AnalyticsDimension(Dimension.toolbar)),
            "count": .int(2),
            "latency_bucket": .double(0.5),
            "is_repeating": .bool(true),
        ])
    }

    @Test(arguments: [
        "ReminderCreated",
        "reminder created",
        "reminder.created",
        "reminder__created",
        "reminder_created_",
        "2_reminders_created",
        "提醒已创建",
    ])
    func rejectsUnstableEventNames(_ name: String) {
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsValidation.validateEventName(
                name,
                allowsStudioPrefix: false
            )
        }
    }

    @Test func reservesStudioLifecycleNamespace() {
        #expect(throws: AnalyticsValidationError.reservedEventName("studio_custom")) {
            try AnalyticsValidation.validateEventName(
                "studio_custom",
                allowsStudioPrefix: false
            )
        }
    }

    @Test(arguments: [
        "email",
        "user_id",
        "display_name",
        "api_token",
        "authorization_header",
        "account_secret",
    ])
    func rejectsSensitivePropertyKeys(_ key: String) {
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsValidation.validateProperties([
                key: .dimension(AnalyticsDimension(Dimension.bounded))
            ])
        }
    }

    @Test(arguments: [
        Dimension.freeForm,
        Dimension.uuid,
        Dimension.email,
        Dimension.filename,
        Dimension.nonASCII,
    ])
    private func rejectsFreeFormDimensions(_ value: Dimension) {
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsValidation.validateProperties([
                "source": .dimension(AnalyticsDimension(value))
            ])
        }
    }

    @Test func rejectsOversizedAndNonFiniteValues() {
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsValidation.validateProperties([
                "source": .dimension(AnalyticsDimension(Dimension.oversized))
            ])
        }
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsValidation.validateProperties([
                "duration": .double(.infinity)
            ])
        }
    }

    @Test func capsSchemaWidth() {
        let properties = Dictionary(uniqueKeysWithValues: (0..<25).map {
            ("property_\($0)", AnalyticsPropertyValue.int($0))
        })
        #expect(throws: AnalyticsValidationError.tooManyProperties(25)) {
            try AnalyticsValidation.validateProperties(properties)
        }
    }
}
