# ProductAnalyticsKit

> **项目状态：暂停。** 保留源码与历史，但不再新增消费端或发布版本。Apple App
> 现行路线为直接接入官方 PostHog SDK；不得让本 Kit 与官方 SDK 直连并行投递。
> 恢复本项目须由 Ivens 明确决定。

An opinionated Swift package for first-party product analytics across Ivens'
Apple app portfolio. It fixes the portfolio on one safe PostHog integration,
one event contract, one identity lifecycle, and one privacy policy instead of
letting every app configure an analytics SDK independently.

The package is internal portfolio infrastructure despite its public GitHub
distribution. It is intentionally not a general analytics abstraction.

## Architecture decision

ProductAnalyticsKit wraps the official PostHog Apple SDK. It does not implement
an ingestion backend, expose PostHog types, or define a replaceable provider
protocol for production use.

- PostHog already owns durable offline queues, batching, retry, anonymous IDs,
  identity merging, and transport maintenance.
- Apps cannot import or configure PostHog directly.
- Products intended primarily for mainland-China networks use a separate
  Supabase event pipeline; that different deployment model does not become an
  option inside this Apple package.

## Fixed portfolio policy

- The ingestion region is PostHog US Cloud. Apps provide only their public
  `phc_...` project token.
- Only explicit, schema-reviewed product events and the Kit's lifecycle events
  are captured.
- Screen autocapture, element autocapture, method swizzling, session replay,
  surveys, feature-flag preloading/events, error autocapture, logs, and PostHog
  push integrations are disabled and not configurable.
- Events use stable `snake_case` object/action names. Dynamic user content,
  account identifiers, contact details, URLs, credentials, and nested values
  are rejected before they reach PostHog.
- Collection is enabled by default for first-party analytics and can be changed
  through the single persistent user privacy choice owned by the Kit.
- Identity accepts only a `UUID` stable internal account identifier. The Kit
  owns account switches, logout reset, and persisted pending-reset recovery; it
  never accepts email, phone number, display name, or person properties.
- Analytics never blocks product behavior. Invalid or unavailable analytics are
  reported as local outcomes and dropped fail-safe.

## Composition root

After restoring the current session, report its identity truth (including an
explicit `nil` for an anonymous session), then start the shared client once:

```swift
import ProductAnalyticsKit

ProductAnalyticsClient.shared.setAuthenticatedUserID(restoredAccount?.id)
let outcome = ProductAnalyticsKit.ProductAnalyticsClient.shared.start(
    projectToken: AnalyticsConfiguration.postHogProjectToken
)
```

Calling `start` again with the same token is harmless. A different token is
rejected so one process cannot silently mix two PostHog projects.
If startup runs before session restoration, the Kit defers provider startup,
lifecycle events, and product events until `setAuthenticatedUserID` supplies
current session truth. This prevents a persisted identity from a previous
process receiving early events.

The Kit automatically records these fixed lifecycle events after startup:

- `studio_app_launched`
- `studio_app_became_active`
- `studio_app_entered_background`
- `studio_app_became_inactive` (macOS only; distinct from background)

It does not automatically inspect screen names, controls, view hierarchies, or
user-entered text.

## Capture a product event

Product event names and their bounded, non-sensitive properties stay in the
host app because they express that product's funnel. String dimensions must
come from a host-owned enum; arbitrary strings are not representable:

```swift
enum EventSource: String, Sendable {
    case toolbar
}

let outcome = ProductAnalyticsClient.shared.track(
    name: "reminder_created",
    properties: [
        "source": .dimension(AnalyticsDimension(EventSource.toolbar)),
        "has_repeat_rule": .bool(true),
        "reminder_count": .int(2),
    ]
)
```

Use bounded enums, booleans, counts, and coarse buckets. Do not send record IDs,
free-form text, search queries, notification copy, filenames, URLs, or error
messages. RevenueCatKit remains the source of subscription truth; the host may
emit a small product event such as `purchase_completed`, but this package does
not ingest receipts or implement revenue attribution.

## Identity and logout

```swift
ProductAnalyticsClient.shared.setAuthenticatedUserID(account.id) // UUID
ProductAnalyticsClient.shared.setAuthenticatedUserID(nil)        // logout
```

The Kit compares the persisted previous account, resets before an account
switch, and remembers logout while collection is disabled. A pending reset is
applied before lifecycle or product events can resume, preventing identity
inheritance across launches and accounts.

## User privacy choice

```swift
let analytics = ProductAnalyticsClient.shared
analytics.setCollectionEnabled(false)
let enabled = analytics.isCollectionEnabled
```

This is a user privacy preference, not a per-App SDK configuration option. The
Kit persists it under one stable key and starts PostHog opted out when disabled.
First-party product analytics that is not combined with third-party data for
advertising is not App Tracking Transparency tracking; ProductAnalyticsKit does
not access IDFA or request ATT permission.

Apps must still describe Product Interaction, Other Usage Data, Device ID, and,
when `identify` is used, User ID as linked analytics data in App Store Connect
and in their privacy policy. The package includes a conservative privacy
manifest; the host remains responsible for its complete App Privacy answers.

## Boundary

ProductAnalyticsKit does not contain:

- product-specific events, funnels, retention rules, or A/B-test decisions;
- UI, privacy-policy copy, or Settings presentation;
- feature flags, experiments, surveys, session replay, error monitoring, logs,
  push notification analytics, or marketing attribution;
- RevenueCat receipts, prices, entitlement logic, or transaction payloads;
- a mainland-China transport or a generic analytics-provider abstraction.

Agent integration and migration guidance lives in
[`.agents/skills/integrate-productanalyticskit/`](.agents/skills/integrate-productanalyticskit/SKILL.md).

## Requirements

- iOS 17+
- macOS 14+
- visionOS 1+
- Swift 6
Opinionated product analytics infrastructure for the studio Apple app portfolio
