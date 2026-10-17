#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec2 uStart;
uniform vec2 uEnd;
uniform float uRadius;
uniform vec4 uColor;

// Signed distance to a capsule. This is the same geometric primitive used by
// modern low-latency ink renderers: one smooth shape joins two pen samples
// without the visible gaps that overlapping circles can create.
float capsuleDistance(vec2 point, vec2 a, vec2 b, float radius) {
  vec2 ab = b - a;
  vec2 ap = point - a;
  float denominator = max(dot(ab, ab), 0.0001);
  float t = clamp(dot(ap, ab) / denominator, 0.0, 1.0);
  return distance(point, a + ab * t) - radius;
}

void main() {
  vec2 point = FlutterFragCoord().xy;
  float distanceToInk = capsuleDistance(point, uStart, uEnd, uRadius);
  float alpha = 1.0 - smoothstep(-1.0, 1.0, distanceToInk);
  fragColor = vec4(uColor.rgb, uColor.a * alpha);
}
