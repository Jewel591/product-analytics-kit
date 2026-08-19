# ProductAnalyticsKit

This repository is the canonical implementation and integration contract for
the studio's Apple product analytics package. `CLAUDE.md` is only a compatibility
symlink to this file.

## Product position

- This is an internal, opinionated Kit distributed from a public repository.
- Reduce host configuration. Fixed portfolio policy belongs here; product
  funnel semantics stay in the host.
- The production transport is PostHog US Cloud. Do not add a provider protocol,
  alternate host, configuration bag, or direct PostHog escape hatch.
- A mainland-China Supabase analytics pipeline is a separate infrastructure
  concern and must not become a switch in this package.
- Public source and history must not contain real project tokens, product event
  catalogs, internal funnel targets, or campaign parameters.

## Privacy invariants

- Keep method swizzling, screen/element autocapture, replay, surveys, feature
  flags, error capture, logs, and push integrations disabled.
- Never add IDFA, ATT, advertising attribution, device fingerprinting, raw user
  content, contact information, credentials, URLs, or nested property payloads.
- The public event boundary validates names, keys, values, and identity before
  the transport sees them. Invalid data drops fail-safe.
- Logout identity reset must remain correct when the user has opted out.
- Changes to collected data require updating `PrivacyInfo.xcprivacy`, README,
  the integration skill, and the App Store disclosure guidance together.

## API boundary

- Production API remains one shared `ProductAnalyticsClient` with `start`,
  `track`, `identify`, `reset`, and `setCollectionEnabled`.
- PostHog types must not appear in public declarations.
- Testing injection exists only through the `Testing` SPI. Do not make it a
  second production construction path.
- Analytics failures must never throw through or block a product action.

## Verification

Run before handoff:

```sh
swift test
swift build -c release
xcodebuild -scheme ProductAnalyticsKit -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/xcode-ios -quiet build
xcodebuild -scheme ProductAnalyticsKit -destination 'generic/platform=visionOS Simulator' -derivedDataPath .build/xcode-visionos -quiet build
python3 /Users/ivensliao/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/integrate-productanalyticskit
```

Tests use injected fakes. They must not initialize the real PostHog singleton or
send network traffic.
