---
name: integrate-productanalyticskit
description: Integrate, migrate, review, or troubleshoot an Apple app that uses the studio ProductAnalyticsKit Swift package. Use when adding PostHog product analytics, replacing app-local telemetry or direct PostHog/Mixpanel/Amplitude/Firebase Analytics code, defining product events, handling anonymous-to-account identity and logout reset, adding an analytics privacy toggle, auditing analytics PII, or updating App Store privacy disclosures for product interaction data.
---

# Integrate ProductAnalyticsKit

Use ProductAnalyticsKit as the only product-analytics implementation in an
Apple application target. It fixes the portfolio on PostHog US Cloud, explicit
events, one identity lifecycle, and one privacy policy. Do not add per-App SDK
options or a second analytics transport.

## Read the contract first

Read the Kit repository's `README.md`, `AGENTS.md`, public declarations under
`Sources/ProductAnalyticsKit/`, and the target app's `AGENTS.md` before editing.
Do not reconstruct API names or PostHog defaults from memory.

This package is for overseas-reachable Apple products. A product intended for
mainland-China networks uses the playbook's Supabase event pipeline instead;
do not add a provider switch or alternate host to ProductAnalyticsKit.

## Audit before editing

Inventory the full production analytics surface:

1. Package references and imports for PostHog, TelemetryDeck, Mixpanel,
   Amplitude, Firebase Analytics, or custom event-upload clients.
2. Every capture, screen, identify, alias, group, reset, opt-in/out, flush,
   lifecycle, replay, survey, feature-flag, and push-analytics call.
3. Existing event names and properties, including dynamic construction and raw
   user content.
4. Login, account switching, logout, anonymous usage, and extension processes.
5. Existing analytics consent/opt-out UserDefaults keys and their default.
6. Privacy policy text, App Store Connect App Privacy answers, ATT usage, and
   any app-owned `PrivacyInfo.xcprivacy` declarations.

Record the old user privacy key before deleting it. A migration must preserve a
person's existing opt-out choice.

## Install one canonical package

Add `https://github.com/Jewel591/product-analytics-kit` with an up-to-next-major
version requirement and link `ProductAnalyticsKit` to the application target.
Do not use a local path, branch, revision, copied source, exact version, or
direct `posthog-ios` package dependency.

The app supplies one public PostHog project token. A `phc_...` client token is
shipped in every app binary and may live in source; never put PostHog personal
API keys or server secrets in the app.

## Report session truth, then start once

```swift
import ProductAnalyticsKit

enum AnalyticsConfiguration {
    static let projectToken = "phc_REPLACE_WITH_THIS_APP_PROJECT_TOKEN"
}

@main
struct ExampleApp: App {
    init() {
        // Use the synchronously restored account UUID, or nil when anonymous.
        ProductAnalyticsClient.shared.setAuthenticatedUserID(
            SessionStore.shared.restoredAccountID
        )
        ProductAnalyticsKit.ProductAnalyticsClient.shared.start(
            projectToken: AnalyticsConfiguration.projectToken
        )
    }

    var body: some Scene { /* ... */ }
}
```

If session restoration is asynchronous, `start` may run first, but analytics
remains dormant until the restoration path calls `setAuthenticatedUserID` with
either the UUID or an explicit `nil`. Do not infer anonymous state before auth
restoration has reached an authoritative result.

Keep one PostHog project per product. Do not expose host, queue sizes, retry,
batching, swizzling, screen capture, replay, surveys, flags, error capture, or
push switches. Do not import `PostHog` in the application target.

## Preserve an existing privacy choice

ProductAnalyticsKit owns the stable preference and defaults first-party
analytics to enabled. Before the first `start`, let the Kit seed it from any
legacy value. The Kit owns the one-time marker; do not add another host marker:

```swift
let defaults = UserDefaults.standard
if defaults.object(forKey: "legacy.analytics.enabled") != nil {
    ProductAnalyticsClient.shared.seedCollectionPreferenceIfUnset(
        legacyValue: defaults.bool(forKey: "legacy.analytics.enabled")
    )
}
```

Use the app's real legacy keys and preserve their semantics exactly. Never
reinterpret an old opt-out as opt-in. Remove the legacy reader only after the
migration has shipped.

If the app offers a privacy setting, bind it to
`ProductAnalyticsClient.shared.isCollectionEnabled` and call
`setCollectionEnabled(_:)`. This is a user choice, not an SDK configuration
surface. Do not show an ATT prompt: first-party analytics without cross-company
advertising linkage is not ATT tracking, and the Kit does not access IDFA.

## Define a small host-owned event catalog

Keep product funnel semantics in one host file, using stable names and bounded
properties:

```swift
enum ProductEvent {
    enum Source: String, Sendable { case toolbar, shortcut }

    static func reminderCreated(source: Source, repeating: Bool)
        -> AnalyticsCaptureOutcome
    {
        ProductAnalyticsClient.shared.track(
            name: "reminder_created",
            properties: [
                "source": .dimension(AnalyticsDimension(source)),
                "is_repeating": .bool(repeating),
            ]
        )
    }
}
```

Use `object_action` snake case. Prefer events that answer a product decision:
activation, adoption, retention, or conversion. Do not mirror every button tap.
Do not dynamically build names from IDs, localized strings, screen titles, or
user input.

Properties may contain only dimensions originating from bounded `String` raw-
value enums, booleans, integers, finite doubles, counts, and coarse buckets.
The capture API never throws or blocks product behavior; invalid schemas return
`.dropped(.invalidSchema)`. Never send:

- email, phone, name, username, address, account/device ID, IDFA, or IDFV;
- record UUIDs, distinct IDs, URLs, filenames, notification copy, search text,
  prompts, notes, imported content, error messages, or stack traces;
- access tokens, authorization headers, secrets, receipts, transaction blobs,
  nested dictionaries, or arrays.

The Kit rejects sensitive keys and values and caps schema width, but host review
still owns event meaning. Do not weaken validation to make a questionable event
pass; redesign the event as a bounded category or aggregate.

## Wire identity without leaking account data

Whenever session restoration reaches an authoritative result, including an
anonymous result:

```swift
ProductAnalyticsClient.shared.setAuthenticatedUserID(account?.id) // UUID or nil
```

Use an internal stable account ID only. Never use email, phone, display name, or
a shared literal such as `"user"` or `"anonymous"`. Anonymous users need no
identify call; PostHog supplies an anonymous ID.

On logout or account deletion, report `nil` before or as session truth changes:

```swift
ProductAnalyticsClient.shared.setAuthenticatedUserID(nil)
await auth.signOut()
```

Report identity even while collection is disabled. The Kit persists a pending
reset and applies it before later collection resumes. On account switching,
pass the new UUID; the Kit resets the old identity before identifying the new
one. Do not call PostHog identify/reset directly or keep a host-side previous-
account marker.

## Keep adjacent systems outside

- Sentry owns crashes, errors, hangs, and diagnostics. Do not enable PostHog
  error capture or logs.
- RevenueCatKit owns entitlements, offerings, receipts, and purchase truth. A
  host may emit a bounded event such as `purchase_completed`; never send receipt
  or transaction payloads through analytics.
- NotificationKit owns notification mechanics. Do not enable PostHog push token
  capture or notification delegate swizzling.
- Feature flags, experiments, surveys, session replay, screen tracking, and
  marketing attribution are not ProductAnalyticsKit features.
- v1 does not support extension analytics. Do not link PostHog directly into a
  Widget/App Intent as a workaround; add support only after a repeated, reviewed
  portfolio need.

## Update privacy declarations

The Kit privacy manifest conservatively declares User ID, Device ID, Product
Interaction, and Other Usage Data as linked analytics data and declares no
tracking. For every adopting app:

1. Update App Store Connect App Privacy answers to match actual event use.
2. Describe first-party product analytics and the opt-out path in the privacy
   policy.
3. If `identify` is used, declare User ID and affected usage data as linked.
4. Keep tracking false unless the product later combines data with third-party
   data for advertising or advertising measurement. Such a change is outside
   this Kit and requires a separate policy decision.
5. Generate and inspect Xcode's aggregate privacy report before release.

Do not claim that a privacy manifest replaces App Store Connect disclosures.

## Migrate atomically

1. Add ProductAnalyticsKit and seed the old privacy choice through
   `seedCollectionPreferenceIfUnset(legacyValue:)`.
2. Create the host event catalog and map only decision-useful legacy events.
3. Wire composition-root start, session identity truth, logout `nil`, and privacy UI.
4. Replace direct capture calls.
5. Remove direct analytics SDK dependencies, imports, lifecycle observers,
   screen tracking, and custom transport/storage code in the same change.
6. Update privacy declarations and policy text.

Do not dual-write old and new pipelines: it duplicates events, splits identity,
and makes migration evidence misleading.

## Verify behavior

Use an injected fake or host wrapper test; do not send test events to production.
Prove:

- startup is called once and a second call cannot switch project tokens;
- event names and properties are stable and contain no raw user content;
- anonymous events precede identify, identified events follow it, and logout
  reset prevents identity inheritance;
- an existing opt-out survives migration and produces no events;
- re-enabling after an opted-out logout resets before identifying the next user;
- App Store privacy declarations match the implemented event catalog;
- production source has no direct PostHog or second analytics implementation.
