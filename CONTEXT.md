# Readly — domain context

Menu-bar-only macOS utility: press a hotkey, drag a selection over anything
on screen, and the text inside is recognized on-device and copied to the
clipboard. This is the domain model and the decisions behind it — read it
before changing how the pipeline behaves.

## Terminology

Use these terms in code, comments, and commit messages; avoid inventing
synonyms.

- **Capture** — one full run of the pipeline, hotkey press to clipboard.
- **Selection** — the dragged rectangle, plus the display and backing scale
  it was drawn on (`SelectionOverlayController.Selection`).
- **Recognition result** — the OCR output for one capture: joined text plus
  the per-line detail (`RecognitionResult`, `RecognizedLine`).
- **Outcome** — what a finished capture is reported as: `.copied`,
  `.noTextFound`, or `.failed(reason)` (`CaptureOutcome`). "No text found" is
  a distinct outcome, not an error — see below.

## The pipeline

```
Hotkey → Selection overlay → Screen capture → OCR (Vision) → Clipboard + HUD
```

`CaptureFlowMachine` is the pure reducer for this: four states
(`idle`/`selecting`/`capturing`/`recognizing`), actions in, effects out, no
AppKit or Vision types anywhere in it. `CaptureCoordinator` is the impure
half — it turns real events (hotkey callbacks, overlay completions, service
results) into actions, and executes the effects against the real services.
Async completions come back in as new actions, same shape as everything
else.

## Decisions (already made, do not relitigate)

- **A second hotkey press while selecting cancels, it does not stack.**
  Handled by the reducer itself (`(.selecting, .hotkeyPressed)` → cancel),
  not by a flag the coordinator has to remember to check.
- **"No text found" is never silent.** Copying an empty string onto the
  clipboard would overwrite whatever the user had there for no reason they
  could see. Every outcome — success, empty, or error — gets its own HUD
  message.
- **All coordinate math lives in `CoordinateMapper`.** Cocoa screen space
  (bottom-left origin, y-up) → Core Graphics display space (top-left, y-down)
  → pixel space (× backing scale) is the single hardest part of this app to
  get right on a second monitor, and it's the one thing kept pure and
  fully unit-tested (`CoordinateMapperTests`) rather than eyeballed.
- **Screen Recording is asked for through onboarding, never cold.** A TCC
  prompt firing off a hotkey press the user hasn't been told about yet reads
  as broken. `OnboardingWindowController` is the only place that calls
  `requestScreenRecordingAccess()`; `CaptureCoordinator` just routes to it
  when access is missing.
- **Two system dialogs, not one.** Building an `SCContentFilter` directly
  (instead of using the system's own content-sharing picker — the whole
  point of Readly's custom selection overlay) makes macOS show a second,
  separate "bypasses the picker" consent the first time the real capture
  APIs are called. `CaptureService.primeScreenCaptureKitAccess()` triggers
  it during onboarding, alongside the classic Screen Recording prompt, so
  both appear together with context instead of the second one appearing
  cold later.
- **Services are protocols** (`OCRServicing`, `CaptureServicing`,
  `OutputServicing`, `PermissionsManaging`, `HotkeySourcing`) so
  `CaptureCoordinator` can be tested against a mock, and so Vision or
  ScreenCaptureKit could be swapped later without touching flow logic.
- **Two third-party dependencies, and no plan for a third without raising
  it first:** `KeyboardShortcuts` (Sindre Sorhus), for the rebindable global
  hotkey, and `Sparkle`, for self-updates.
- **Updates are a static file, not a server.** Readly ships no backend;
  `appcast.xml` at the repo root is the whole update feed, and
  `scripts/release.sh` is what keeps it, `Casks/readly.rb`, and the GitHub
  release in sync on every cut.
- Scaffolding values (bundle ID, entitlements, signing, Info.plist keys):
  [`docs/ProjectSettings.md`](docs/ProjectSettings.md)

## Layout

- `Readly/App/` — composition root (`AppDelegate`), the status menu, and the
  onboarding window/view.
- `Readly/Coordinator/` — `CaptureFlowMachine` (the pure reducer) and
  `CaptureCoordinator` (the impure orchestrator).
- `Readly/Overlay/` — the per-screen selection window/view and
  `CoordinateMapper`.
- `Readly/Services/` — `HotkeyManager`, `CaptureService` (ScreenCaptureKit),
  `OCRService` (Vision), `OutputService` + `CaptureHUDController` (clipboard
  and the confirmation toast), `PermissionsManager`.
- `Readly/Settings/` — the settings window, its `SettingsStore`, and the
  reusable card/row design system under `Components/`.
- `Readly/Updates/` — `SparkleUpdaterService`, wrapping Sparkle so nothing
  else in the app imports it.

## Where to put a test

Test the pure seams: `CaptureFlowMachine` (flow and re-entrancy rules) and
`CoordinateMapper` (the coordinate-space math). Both are pure, so their
rules pin down without a screen, a window, or a Vision request attached.
When a bug turns out to live in the impure coordinator, the fix is usually
to move the rule into the reducer and test that, not to mock the world.

## Roadmap

- Language auto-detection
- Capture history
- Table detection → paste as CSV
- Translate after capture
- Real code signing + notarization once distribution is actually planned —
  Sparkle updates and the Homebrew cask both already work ad-hoc signed, but
  a first launch from a fresh download still shows Gatekeeper's "damaged"
  message until then
