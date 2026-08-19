import Testing
@_spi(Testing) @testable import ProductAnalyticsKit

@MainActor
struct ProductAnalyticsClientTests {
    @Test func startIsIdempotentAndCapturesOneLaunch() {
        let transport = FakeAnalyticsTransport()
        let lifecycle = FakeLifecycleSource()
        let client = makeClient(transport: transport, lifecycle: lifecycle)

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
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(
            client.start(projectToken: "phc_abcdef1234567890")
                == .rejected(.differentProjectToken)
        )
        #expect(transport.starts.count == 1)
    }

    @Test func productEventsNeverBlockAndRespectCollectionState() throws {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(collectionEnabled: false)
        let client = makeClient(transport: transport, preferences: preferences)
        let event = try AnalyticsEvent(name: "reminder_created")

        #expect(client.track(event) == .dropped(.notStarted))
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(client.track(event) == .dropped(.collectionDisabled))
        #expect(transport.captures.isEmpty)

        client.setCollectionEnabled(true)
        #expect(client.track(event) == .captured)
        #expect(transport.captures.map(\.event) == ["reminder_created"])
    }

    @Test func identityCanArriveBeforeStartup() {
        let transport = FakeAnalyticsTransport()
        let client = makeClient(transport: transport)

        #expect(client.identify(userID: "account-42") == .deferred)
        #expect(client.start(projectToken: validProjectToken) == .started)
        #expect(transport.identifiedUserIDs == ["account-42"])
    }

    @Test(arguments: [
        "",
        " person ",
        "person@example.com",
        "https://example.com/person",
    ])
    func rejectsUnsafeIdentity(_ userID: String) {
        let transport = FakeAnalyticsTransport()
        let client = makeClient(transport: transport)

        #expect(client.identify(userID: userID) == .rejected)
        #expect(transport.identifiedUserIDs.isEmpty)
    }

    @Test func logoutWhileOptedOutResetsBeforeFutureIdentification() {
        let transport = FakeAnalyticsTransport()
        let preferences = FakeAnalyticsPreferences(collectionEnabled: false)
        let client = makeClient(transport: transport, preferences: preferences)

        client.start(projectToken: validProjectToken)
        #expect(client.identify(userID: "next-account") == .deferred)
        client.reset()
        #expect(preferences.hasPendingIdentityReset)
        #expect(transport.resetCount == 0)

        #expect(client.identify(userID: "next-account") == .deferred)
        client.setCollectionEnabled(true)

        #expect(transport.actions.suffix(3) == [
            "enabled:true",
            "reset",
            "identify:next-account",
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

        client.start(projectToken: validProjectToken)

        #expect(transport.actions.prefix(4) == [
            "start:false",
            "enabled:true",
            "reset",
            "capture:studio_app_launched",
        ])
        #expect(!preferences.hasPendingIdentityReset)
    }

    @Test func lifecycleIsExplicitAndBackgroundFlushes() {
        let transport = FakeAnalyticsTransport()
        let lifecycle = FakeLifecycleSource()
        let client = makeClient(transport: transport, lifecycle: lifecycle)
        client.start(projectToken: validProjectToken)

        lifecycle.send(.becameActive)
        lifecycle.send(.enteredBackground)

        #expect(transport.captures.map(\.event) == [
            "studio_app_launched",
            "studio_app_became_active",
            "studio_app_entered_background",
        ])
        #expect(transport.flushCount == 1)
    }
}
