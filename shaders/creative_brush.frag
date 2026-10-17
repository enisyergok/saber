#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec3 uColor;
out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 cell = floor(p);
  vec2 local = fract(p);
  local = local * local * (3.0 - 2.0 * local);
  return mix(
    mix(hash(cell), hash(cell + vec2(1.0, 0.0)), local.x),
    mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), local.x),
    local.y
  );
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float grain = noise(p * vec2(0.12, 0.32));
  float fibers = noise(p * vec2(0.035, 0.18));
  float opacity = 0.76 + 0.18 * grain + 0.06 * fibers;
  fragColor = vec4(uColor * opacity, opacity);
}
