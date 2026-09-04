#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 nightWash(float2 position, half4 color, float time, float2 size) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * 2.0 - 1.0;
    p.x *= size.x / max(size.y, 1.0);

    float t = time * 0.07;
    float wave = 0.0;
    wave += 0.50 * sin(p.x * 1.6 + t);
    wave += 0.32 * sin(p.y * 2.2 - t * 1.25);
    wave += 0.22 * sin((p.x + p.y) * 3.1 + t * 0.6);
    wave += 0.12 * sin(length(p) * 4.8 - t * 0.9);

    float grain = fract(sin(dot(uv * 140.0, float2(12.9898, 78.233))) * 43758.5453);

    half3 deep = half3(0.028, 0.026, 0.024);
    half3 cool = half3(0.07, 0.09, 0.14);
    half3 warm = half3(0.14, 0.10, 0.06);
    half3 sheen = half3(0.16, 0.18, 0.22);

    half3 col = deep;
    col = mix(col, cool, half(smoothstep(-0.55, 0.75, wave) * 0.55));
    col = mix(col, warm, half(smoothstep(0.15, 1.0, (1.0 - uv.y) * 0.55 + uv.x * 0.25)));
    col = mix(col, sheen, half(pow(max(wave, 0.0), 3.0) * 0.18));
    col += half3(grain * 0.028);

    float vig = smoothstep(1.25, 0.18, length(p * float2(0.62, 0.72)));
    col *= half(0.62 + 0.38 * vig);
    return half4(col, 1.0);
}

[[ stitchable ]] half4 glazeSpec(float2 position, half4 color, float2 size) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * 2.0 - 1.0;
    float rim = pow(1.0 - smoothstep(0.15, 0.95, length(p)), 1.6);
    float slash = smoothstep(0.02, 0.0, abs(p.y + 0.55 * p.x + 0.18));
    half3 light = half3(1.0, 0.98, 0.94);
    half3 outc = color.rgb + light * half(slash * 0.16 + rim * 0.10);
    return half4(outc, color.a);
}
