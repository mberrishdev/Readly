#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// A soft, breathing glow around the selection border while the user drags.
/// Reads the already-rasterized stroke (`layer`) and accumulates samples
/// across several concentric rings around each pixel, so light visibly
/// bleeds outward from the thin line rather than the single-ring average
/// this started as — with only one ring, most samples missed the 1.5pt
/// line entirely and the effect was nearly invisible in practice.
///
/// `time` drives the pulse; SwiftUI supplies it every frame via
/// `SelectionGlowView`'s `TimelineView`.
[[ stitchable ]]
half4 selectionGlow(float2 position, SwiftUI::Layer layer, float time) {
  half4 original = layer.sample(position);

  float pulse = 0.5 + 0.5 * sin(time * 2.4);
  float maxRadius = mix(5.0, 11.0, pulse);

  half4 glow = half4(0);
  const int ringCount = 4;
  const int samplesPerRing = 10;
  for (int r = 1; r <= ringCount; r++) {
    float ringFraction = float(r) / float(ringCount);
    float radius = maxRadius * ringFraction;
    // Closer rings contribute more, so the glow reads as falling off with
    // distance rather than one flat haze.
    half weight = half(1.0 - ringFraction * 0.6);
    for (int i = 0; i < samplesPerRing; i++) {
      float angle = (2.0 * M_PI_F * float(i)) / float(samplesPerRing);
      float2 offset = float2(cos(angle), sin(angle)) * radius;
      glow += layer.sample(position + offset) * weight;
    }
  }
  glow /= float(ringCount * samplesPerRing) * 0.7;

  // Readly's indigo accent (SettingsTheme.accentColor), brightened — the
  // glow is the brand color bleeding out of the border, not a faint haze.
  half3 accent = half3(0.55, 0.45, 1.0);
  half glowStrength = min(glow.a * half(2.4), half(1.0)) * half(0.6 + 0.4 * pulse);

  half3 outColor = original.rgb + accent * glowStrength * (1.0 - original.a);
  half outAlpha = max(original.a, glowStrength * half(0.9));
  return half4(outColor, outAlpha);
}
