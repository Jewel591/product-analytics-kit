import Foundation
import Testing
@_spi(Testing) @testable import ProductAnalyticsKit

@MainActor
struct ProductAnalyticsClientTests {
    private enum Dimension: String, Sendable {
        case toolbar
        case privateSearchText = "private search text"
    }

    @Test func startIsIdempotentAndCapturesOneLaunch() {
        let transport = FakeAnalyticsTransport()
        let lifecycle = FakeLifecycleSource()
        let client = makeClient(transport: transport, lifecycle: lifecycle)

        _ = client.setAuthenticatedUserID(nil)
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(client.start(projectToken: validProjectToken) == .alreadyStarted)
        #expect(transport.starts.count == 1)
        #expect(transport.starts.first?.enabled == true)
        #expect(lifecycle.startCount == 1)
        #expect(transport.captures.map(\.event) == ["studio_app_launched"])
        #expect(transport.captures.first?.properties["app_version"] as? String == "1.2.3")
    }

    @Test func rejectsInvalidOrDifferentProjectTokens() {
        let transport = FakeAnalyticsTransport()
        let client = makeClient(transport: transport)

        #expect(client.start(projectToken: "replace-me") == .rejected(.invalidProjectToken))
        _ = client.setAuthenticatedUserID(nil)
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(
            client.start(projectToken: "phc_abcdef1234567890")
                == .rejected(.differentProjectToken)
        )
        #expect(transport.starts.count == 1)
    }

    @Test func productEventsNeverThrowAndRespectCollectionState() {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(collectionEnabled: false)
        let client = makeClient(transport: transport, preferences: preferences)

        #expect(client.track(name: "reminder_created") == .dropped(.notStarted))
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(client.track(name: "reminder_created") == .dropped(.identityNotReported))
        _ = client.setAuthenticatedUserID(nil)
        #expect(client.track(name: "reminder_created") == .dropped(.collectionDisabled))
        #expect(transport.captures.isEmpty)

        client.setCollectionEnabled(true)
        #expect(client.track(
            name: "reminder_created",
            properties: ["source": .dimension(AnalyticsDimension(Dimension.toolbar))]
        ) == .captured)
        #expect(transport.captures.map(\.event) == ["reminder_created"])
    }

    @Test func invalidSchemaIsDroppedWithoutConstructingAThrowingEvent() {
        let transport = FakeAnalyticsTransport()
        let client = makeClient(transport: transport)
        _ = client.setAuthenticatedUserID(nil)
        client.start(projectToken: validProjectToken)

        #expect(client.track(
            name: "Reminder Created",
            properties: ["query": .dimension(AnalyticsDimension(Dimension.privateSearchText))]
        ) == .dropped(.invalidSchema))
        #expect(transport.captures.map(\.event) == ["studio_app_launched"])
    }

    @Test func identityCanArriveBeforeStartup() {
        let transport = FakeAnalyticsTransport()
        let client = makeClient(transport: transport)

        #expect(client.setAuthenticatedUserID(accountA) == .deferred)
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(transport.identifiedUserIDs == [accountA.uuidString])
    }

    @Test func startupWaitsForAuthoritativeAnonymousSessionTruth() {
        let transport = FakeAnalyticsTransport()
        let lifecycle = FakeLifecycleSource()
        let client = makeClient(transport: transport, lifecycle: lifecycle)

        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(transport.starts.isEmpty)
        #expect(transport.captures.isEmpty)
        #expect(lifecycle.startCount == 0)

        #expect(client.setAuthenticatedUserID(nil) == .unchanged)
        #expect(transport.starts.count == 1)
        #expect(transport.captures.map(\.event) == ["studio_app_launched"])
        #expect(lifecycle.startCount == 1)
    }

    @Test func accountSwitchAlwaysResetsBeforeIdentifyingTheNewUUID() {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(authenticatedUserID: accountA)
        let client = makeClient(transport: transport, preferences: preferences)
        _ = client.setAuthenticatedUserID(accountA)
        client.start(projectToken: validProjectToken)

        #expect(client.setAuthenticatedUserID(accountB) == .applied)
        #expect(transport.actions.suffix(2) == [
            "reset",
            "identify:\(accountB.uuidString)",
        ])
        #expect(preferences.authenticatedUserID == accountB)
    }

    @Test func accountSwitchPersistsResetMarkerBeforeNewIdentity() {
        let preferences = FakeAnalyticsPreferences(authenticatedUserID: accountA)
        let client = makeClient(preferences: preferences)

        _ = client.setAuthenticatedUserID(accountB)

        #expect(preferences.writes.prefix(2) == [
            "pending:true",
            "identity:\(accountB.uuidString)",
        ])
    }

    @Test func logoutWhileOptedOutResetsBeforeFutureIdentification() {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(
            collectionEnabled: false,
            authenticatedUserID: accountA
        )
        let client = makeClient(transport: transport, preferences: preferences)

        _ = client.setAuthenticatedUserID(accountA)
        client.start(projectToken: validProjectToken)
        #expect(client.setAuthenticatedUserID(nil) == .deferred)
        #expect(preferences.hasPendingIdentityReset)
        #expect(transport.resetCount == 0)

        #expect(client.setAuthenticatedUserID(accountB) == .deferred)
        client.setCollectionEnabled(true)

        #expect(transport.actions.suffix(3) == [
            "reset",
            "enabled:true",
            "identify:\(accountB.uuidString)",
        ])
        #expect(!preferences.hasPendingIdentityReset)
    }

    @Test func pendingLogoutStartsOptedOutAndResetsBeforeLaunch() {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(
            collectionEnabled: true,
            hasPendingIdentityReset: true
        )
        let client = makeClient(transport: transport, preferences: preferences)

        _ = client.setAuthenticatedUserID(nil)
        client.start(projectToken: validProjectToken)

        #expect(transport.actions.prefix(4) == [
            "start:false",
            "reset",
            "enabled:true",
            "capture:studio_app_launched",
        ])
        #expect(!preferences.hasPendingIdentityReset)
    }

    @Test func optedOutStartupNeverTemporarilyEnablesProviderForPendingReset() {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(
            collectionEnabled: false,
            hasPendingIdentityReset: true
        )
        let client = makeClient(transport: transport, preferences: preferences)

        _ = client.setAuthenticatedUserID(nil)
        client.start(projectToken: validProjectToken)

        #expect(transport.actions == ["start:false"])
        #expect(preferences.hasPendingIdentityReset)
    }

    @Test func legacyPreferenceSeedsOnceWithoutAHostMigrationMarker() {
        let preferences = FakeAnalyticsPreferences(
            collectionEnabled: true,
            isCollectionPreferenceInitialized: false
        )
        let client = makeClient(preferences: preferences)

        #expect(client.seedCollectionPreferenceIfUnset(legacyValue: false))
        #expect(!preferences.collectionEnabled)
        #expect(!client.seedCollectionPreferenceIfUnset(legacyValue: true))
        #expect(!preferences.collectionEnabled)
    }

    @Test func lifecycleUsesSeparateBackgroundAndInactiveSemantics() {
        let transport = FakeAnalyticsTransport()
        let lifecycle = FakeLifecycleSource()
        let client = makeClient(transport: transport, lifecycle: lifecycle)
        _ = client.setAuthenticatedUserID(nil)
        client.start(projectToken: validProjectToken)

        lifecycle.send(.becameActive)
        lifecycle.send(.enteredBackground)
        lifecycle.send(.becameInactive)

        #expect(transport.captures.map(\.event) == [
            "studio_app_launched",
            "studio_app_became_active",
            "studio_app_entered_background",
            "studio_app_became_inactive",
        ])
        #expect(transport.flushCount == 2)
    }
}

private let accountA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
private let accountB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
