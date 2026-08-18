import CoreGraphics
import Foundation
import Vision

/// One recognized line of text and where it sat in the source image, as a
/// normalized rect (origin bottom-left, 0...1 on each axis — Vision's own
/// convention).
struct RecognizedLine: Equatable, Sendable {
  let text: String
  let boundingBox: CGRect
}

/// The recognized text and its per-line detail. Keeping the observations
/// alongside the joined string — rather than returning just a `String` —
/// means a later feature (table detection, a "keep line breaks" toggle,
/// tap-to-copy-one-line) reads them out of this instead of re-running Vision.
struct RecognitionResult: Equatable, Sendable {
  let lines: [RecognizedLine]

  var text: String {
    lines.map(\.text).joined(separator: "\n")
  }

  /// The delivered text honors the user's line-break preference; emptiness
  /// and character counts are always measured against the line-preserving
  /// join, so the setting can never change whether a capture counts as
  /// "no text found."
  func text(keepLineBreaks: Bool) -> String {
    keepLineBreaks ? text : lines.map(\.text).joined(separator: " ")
  }

  var characterCount: Int { text.count }
  var isEmpty: Bool { lines.isEmpty }
}

/// Errors `OCRService` can throw. Vision's own request errors are wrapped
/// rather than passed through, so callers depend on one small error surface.
enum OCRError: Error {
  case requestFailed(Error)
}

/// OCR as a protocol so `CaptureCoordinator` can be tested against a mock
/// and so Vision could be swapped for another recognizer later without
/// touching the coordinator's flow logic.
protocol OCRServicing: Sendable {
  func recognizeText(in image: CGImage, languages: [String]) async throws -> RecognitionResult
}

/// Wraps `VNRecognizeTextRequest`. Runs off the main actor — `.accurate`
/// mode costs 100–500 ms, and the coordinator is not allowed to block on it.
struct OCRService: OCRServicing {
  func recognizeText(in image: CGImage, languages: [String]) async throws -> RecognitionResult {
    try await Task.detached(priority: .userInitiated) {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      if !languages.isEmpty {
        request.recognitionLanguages = languages
      }

      let handler = VNImageRequestHandler(cgImage: image, options: [:])
      do {
        try handler.perform([request])
      } catch {
        throw OCRError.requestFailed(error)
      }

      let observations = request.results ?? []
      let lines = observations.compactMap { observation -> RecognizedLine? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        return RecognizedLine(text: candidate.string, boundingBox: observation.boundingBox)
      }
      return RecognitionResult(lines: lines)
    }.value
  }
}
