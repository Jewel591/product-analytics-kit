import Foundation
import Testing
@testable import ProductAnalyticsKit

struct AnalyticsEventTests {
    @Test func acceptsBoundedSchemaValues() throws {
        let event = try AnalyticsEvent(
            name: "reminder_created",
            properties: [
                "source": .string("toolbar"),
                "count": .int(2),
                "latency_bucket": .double(0.5),
                "is_repeating": .bool(true),
            ]
        )

        #expect(event.name == "reminder_created")
        #expect(event.properties.count == 4)
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
            try AnalyticsEvent(name: name)
        }
    }

    @Test func reservesStudioLifecycleNamespace() {
        #expect(throws: AnalyticsValidationError.reservedEventName("studio_custom")) {
            try AnalyticsEvent(name: "studio_custom")
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
            try AnalyticsEvent(
                name: "account_signed_in",
                properties: [key: .string("bounded")]
            )
        }
    }

    @Test(arguments: [
        "person@example.com",
        "https://example.com/private/path",
        "Bearer credential",
        "phc_not_a_property",
        "eyJheader.payload.signature",
    ])
    func rejectsSensitiveStringValues(_ value: String) {
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsEvent(
                name: "account_signed_in",
                properties: ["source": .string(value)]
            )
        }
    }

    @Test func rejectsOversizedAndNonFiniteValues() {
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsEvent(
                name: "search_completed",
                properties: ["query": .string(String(repeating: "x", count: 129))]
            )
        }
        #expect(throws: AnalyticsValidationError.self) {
            try AnalyticsEvent(
                name: "search_completed",
                properties: ["duration": .double(.infinity)]
            )
        }
    }

    @Test func capsSchemaWidth() {
        let properties = Dictionary(uniqueKeysWithValues: (0..<25).map {
            ("property_\($0)", AnalyticsPropertyValue.int($0))
        })
        #expect(throws: AnalyticsValidationError.tooManyProperties(25)) {
            try AnalyticsEvent(name: "bulk_completed", properties: properties)
        }
    }
}
