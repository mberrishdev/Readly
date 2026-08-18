# Readly

Menu-bar-only macOS utility (Swift 6, Apple Silicon). Press a hotkey, drag a
selection, get the text on your clipboard — fully on-device.

Read [`CONTEXT.md`](CONTEXT.md) before changing how the capture pipeline
behaves. Its terminology and decisions are binding: use the terms it lists
(Capture, Selection, Recognition result, Outcome), and don't relitigate a
decision it records without saying so.

## Style

- **Two-space indentation**, everywhere, in every Swift file. See
  `.editorconfig`.
- **No `// MARK:` comments.** A file that needs section markers needs
  splitting instead.
- **Comments explain *why*, never *what*.** Well-named identifiers already
  say what the code does; a comment earns its place only for a hidden
  constraint, a subtle invariant, or a workaround worth remembering.
- **Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest**, for
  every new test.
- **Services are protocols**, named `...ing` (`OCRServicing`,
  `CaptureServicing`, ...), with a concrete struct/class implementation and
  a `@MainActor` coordinator wiring them together by closures — see
  `CaptureCoordinator`. Keep new flow logic in a pure reducer
  (`CaptureFlowMachine`'s shape: `State`/`Action`/`Effect`, `reduce(_:)`
  returns effects) rather than inline in the coordinator, so it stays
  testable without touching AppKit, Vision, or ScreenCaptureKit.

## Stack decisions (already made, do not relitigate)

- Plain committed `Readly.xcodeproj` (no Tuist, no `xcodegen`), Swift 6,
  strict concurrency complete
- AppKit is the shell: `AppDelegate`, the status item, the selection overlay
  windows
- SwiftUI for windowed UI (Settings, onboarding), hosted in the AppKit shell
- ScreenCaptureKit for capture, Vision for OCR — both first-party, no model
  or capture library swapped in
- Exactly one third-party dependency: `KeyboardShortcuts`, for the
  rebindable global hotkey. Adding a second is a decision to raise, not to
  make.
- Scaffolding values (bundle ID, entitlements, signing, Info.plist keys):
  [`docs/ProjectSettings.md`](docs/ProjectSettings.md)

## Build and test

```bash
xcodebuild -project Readly.xcodeproj -scheme Readly -configuration Debug build
xcodebuild test -project Readly.xcodeproj -scheme Readly -destination 'platform=macOS'
```

Both must pass before handing work back.

## Where to put a test

Test the pure seams: `CaptureFlowMachine` and `CoordinateMapper`. See
`CONTEXT.md` for why.

## State of the repo

Buildable and working end to end: press the hotkey, drag a selection, the
text lands on the clipboard, confirmed by a HUD. Onboarding walks through
Screen Recording access on first launch rather than a cold system prompt.
