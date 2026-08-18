# Project settings

`Readly.xcodeproj` is hand-authored and committed directly — no `xcodegen`,
no `project.yml`, no generation step. It uses Xcode 16's file-system
synchronized groups (`PBXFileSystemSynchronizedRootGroup`), so adding or
removing a Swift file under `Readly/` or `ReadlyTests/` never touches
`project.pbxproj`; only build settings and package references live there.

## Identity

- Bundle ID: `com.readly.app`
- Product: macOS app, deployment target macOS 14.0, `arm64` only
- Marketing version `0.1.0`, build `1`
- Category: `public.app-category.productivity`

## Info.plist keys that matter

- `LSUIElement` = true (menu-bar-only, no Dock icon)
- `NSPrincipalClass` = `NSApplication`
- No usage-description keys needed — Screen Recording access is gated by
  `CGPreflightScreenCaptureAccess`/`CGRequestScreenCaptureAccess`, which
  (unlike camera or microphone) needs no `Info.plist` string; the system
  supplies the TCC prompt's text itself
- No `Info.plist` file in the target at all — every key above is generated
  from `INFOPLIST_KEY_*` build settings (`GENERATE_INFOPLIST_FILE = YES`)
- No Sparkle / update feed yet — distribution is manual `dist/*.dmg` builds
  for now (see the README's Roadmap)

## Entitlements (`Readly.entitlements`)

Empty. App Sandbox off (`ENABLE_APP_SANDBOX = NO`) — Screen Recording access
needs no sandbox entitlement, and sandboxing isn't otherwise required for
anything Readly does. Hardened Runtime on (for eventual notarization). The
file lives at the repo root, sibling to `Readly.xcodeproj`, rather than
inside `Readly/` — that keeps it out of the synchronized source group
entirely, so it's referenced purely via `CODE_SIGN_ENTITLEMENTS` and never
risks being swept into a build phase as a stray resource.

## Build settings

Base: `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`,
`DEAD_CODE_STRIPPING = YES`, `ONLY_ACTIVE_ARCH = YES` for Debug (`NO` for
Release).

Debug and Release signing are both `CODE_SIGN_STYLE = Automatic` with
`CODE_SIGN_IDENTITY = "-"` ("Sign to Run Locally") — no Apple Developer Team
is configured yet, so builds are ad-hoc signed. That's sufficient for local
dev/run; a Developer ID Application identity (and notarization) is deferred
until real distribution is actually planned.

One consequence worth knowing: ad-hoc signatures are regenerated on every
build, and macOS's TCC grants are partly keyed to the code signature — so a
Screen Recording grant can appear to "reset" across rebuilds during
development. That's expected, not a bug in the onboarding flow.
