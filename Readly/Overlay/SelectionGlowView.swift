import SwiftUI

/// The animated glow drawn around the selection rectangle while dragging —
/// hosted inside `SelectionView` (AppKit) via `NSHostingView`, sized to
/// track the drag rect each frame. `SelectionView` still owns the dim and
/// the mouse tracking; this is purely the border's visual treatment.
struct SelectionGlowView: View {
  /// The empty margin `SelectionView` padded its hosting frame by, so the
  /// traced rectangle sits where the actual selection is rather than
  /// filling the padded frame — the padding is bleed room for the glow,
  /// not part of the shape.
  let padding: CGFloat

  var body: some View {
    TimelineView(.animation) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .inset(by: padding)
        .stroke(Color.white, lineWidth: 1.5)
        .layerEffect(
          Shader(
            function: .init(library: .default, name: "selectionGlow"),
            arguments: [.float(time)]
          ),
          maxSampleOffset: CGSize(width: 12, height: 12)
        )
    }
  }
}
