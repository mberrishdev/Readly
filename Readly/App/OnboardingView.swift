import SwiftUI

/// The Screen Recording conversation, as a real window instead of a modal
/// alert — laid out as two step-by-step flows: how Readly itself works, and
/// how to grant the one permission it needs. Readly needs this permission
/// for its one and only feature to work at all, so the request has to be
/// framed *before* the system dialog appears — a cold TCC prompt the user
/// hasn't been told about yet reads as broken, not as a permission request.
struct OnboardingView: View {
  enum AccessStatus {
    case notGranted
    case granted
  }

  let status: AccessStatus
  /// The user's configured hotkey, read fresh each render so a rebind in
  /// Settings shows up here too.
  let shortcutDescription: String
  let onRequestAccess: () -> Void
  let onOpenSystemSettings: () -> Void
  let onContinue: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 16) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 56, height: 56)
        VStack(alignment: .leading, spacing: 4) {
          Text("Welcome to Readly")
            .font(.title2.bold())
          Text("Select any area of your screen and copy its text.")
            .foregroundStyle(.secondary)
        }
      }

      Divider()

      flowSection(
        heading: "HOW IT WORKS",
        steps: [
          (title: "Press \(shortcutDescription)", subtitle: "Anywhere on your Mac", isDone: true),
          (title: "Drag over any text", subtitle: "A screenshot, a video frame, a PDF scan — anything", isDone: true),
          (title: "Paste anywhere", subtitle: "The recognized text is already on your clipboard", isDone: true),
        ]
      )

      Divider()

      VStack(alignment: .leading, spacing: 14) {
        sectionHeading("SCREEN RECORDING ACCESS")

        Text("""
          Readly needs this to capture the area you select. Recognition happens \
          entirely on this Mac — nothing is uploaded anywhere.
          """)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        FlowStepRow(
          number: 1,
          title: "Access requested",
          subtitle: "Readly now appears under Privacy & Security → Screen Recording",
          isDone: true
        )
        FlowStepRow(
          number: 2,
          title: "Approve both dialogs",
          subtitle: "macOS shows a second one confirming Readly captures your selection "
            + "directly, instead of through the system's window picker — that's expected",
          isDone: true
        )
        FlowStepRow(
          number: 3,
          title: "Turn Readly on",
          subtitle: "In System Settings → Privacy & Security → Screen Recording",
          isDone: status == .granted
        )

        if status == .granted {
          Label(
            "Access granted — if a capture doesn't work right away, reopen Readly once",
            systemImage: "checkmark.circle.fill"
          )
          .font(.caption)
          .foregroundStyle(.green)
        }
      }

      HStack {
        Button("Open System Settings", action: onOpenSystemSettings)
        Spacer()
        switch status {
        case .notGranted:
          Button("Skip for now", action: onContinue)
          Button("Try Again", action: onRequestAccess)
            .keyboardShortcut(.defaultAction)
        case .granted:
          Button("Continue", action: onContinue)
            .keyboardShortcut(.defaultAction)
        }
      }
    }
    .padding(24)
    .frame(width: 440)
  }

  private func sectionHeading(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .semibold))
      .tracking(0.6)
      .foregroundStyle(.secondary)
  }

  private func flowSection(
    heading: String,
    steps: [(title: String, subtitle: String, isDone: Bool)]
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeading(heading)
      ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
        FlowStepRow(number: index + 1, title: step.title, subtitle: step.subtitle, isDone: step.isDone)
      }
    }
  }
}

/// One numbered step: a filled circle that becomes a checkmark once the step
/// is done, title, and an optional detail line.
private struct FlowStepRow: View {
  let number: Int
  let title: String
  var subtitle: String = ""
  var isDone: Bool = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Circle()
          .fill(isDone ? Color.accentColor : Color.secondary.opacity(0.18))
          .frame(width: 22, height: 22)
        if isDone {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
        } else {
          Text("\(number)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 13, weight: .medium))
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 0)
    }
  }
}

#Preview {
  OnboardingView(
    status: .notGranted,
    shortcutDescription: "⇧⌘2",
    onRequestAccess: {},
    onOpenSystemSettings: {},
    onContinue: {}
  )
}
