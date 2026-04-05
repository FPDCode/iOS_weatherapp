// WeatherHorizon.metal — Sky horizon shader for the weather header
// Uses SwiftUI's colorEffect protocol (iOS 17+)

#include <metal_stdlib>
using namespace metal;

// MARK: - Sky Horizon Color Effect
// Applied via .colorEffect() — receives each pixel position and returns a color.
// Parameters:
//   position:  pixel coordinate
//   args[0]:   float2 size (width, height)
//   args[1]:   float  timeOfDay (0.0 = midnight, 0.5 = noon, 1.0 = midnight)
//   args[2]:   float  weatherFactor (0.0 = clear, 1.0 = heavy overcast/storm)
//   args[3]:   float  animTime (elapsed seconds for subtle animation)

[[ stitchable ]]
half4 weatherHorizon(float2 position, half4 currentColor,
                     float2 size, float timeOfDay, float weatherFactor, float animTime) {

    float2 uv = position / size;

    // Horizon sits at ~65% from top
    float horizonY = 0.65;

    // Distance from horizon (positive = below, negative = above)
    float horizonDist = uv.y - horizonY;

    // --- Time-based sky colors ---

    // Map timeOfDay (0-1) through a day cycle
    // 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset, 1.0 = midnight
    float sunAngle = sin(timeOfDay * M_PI_F); // 0 at midnight, 1 at noon

    // Sunrise/sunset glow factor (peaks at 0.25 and 0.75)
    float goldenHour = pow(sin(timeOfDay * 2.0 * M_PI_F), 2.0);
    goldenHour = max(goldenHour, 0.0);
    // Specifically boost at sunrise (0.2-0.3) and sunset (0.7-0.8)
    float sunriseFactor = smoothstep(0.15, 0.25, timeOfDay) * smoothstep(0.35, 0.25, timeOfDay);
    float sunsetFactor = smoothstep(0.65, 0.75, timeOfDay) * smoothstep(0.85, 0.75, timeOfDay);
    float twilight = max(sunriseFactor, sunsetFactor);

    // Sky zenith color (top of sky)
    half3 zenithNight = half3(0.04, 0.06, 0.12);   // Deep dark blue
    half3 zenithDay   = half3(0.13, 0.45, 0.85);    // Bright blue
    half3 zenithTwilight = half3(0.15, 0.12, 0.35);  // Purple-indigo
    half3 zenithOvercast = half3(0.25, 0.28, 0.32);  // Gray

    half3 zenith = mix(zenithNight, zenithDay, half(sunAngle));
    zenith = mix(zenith, zenithTwilight, half(twilight * 0.6));
    zenith = mix(zenith, zenithOvercast, half(weatherFactor * 0.7));

    // Horizon color
    half3 horizonNight = half3(0.08, 0.10, 0.18);
    half3 horizonDay   = half3(0.55, 0.75, 0.95);
    half3 horizonTwilight = half3(0.95, 0.45, 0.15); // Warm orange
    half3 horizonOvercast = half3(0.40, 0.42, 0.45);

    half3 horizon = mix(horizonNight, horizonDay, half(sunAngle));
    horizon = mix(horizon, horizonTwilight, half(twilight * 0.8));
    horizon = mix(horizon, horizonOvercast, half(weatherFactor * 0.6));

    // Ground/below horizon color
    half3 groundNight = half3(0.03, 0.04, 0.08);
    half3 groundDay   = half3(0.08, 0.15, 0.22);
    half3 groundOvercast = half3(0.12, 0.14, 0.16);

    half3 ground = mix(groundNight, groundDay, half(sunAngle * 0.5));
    ground = mix(ground, groundOvercast, half(weatherFactor * 0.5));

    // --- Compose sky ---

    half3 color;
    if (horizonDist < 0.0) {
        // Above horizon: blend zenith → horizon
        float t = smoothstep(-0.65, 0.0, horizonDist);
        color = mix(zenith, horizon, half(t));
    } else {
        // Below horizon: blend horizon → ground
        float t = smoothstep(0.0, 0.35, horizonDist);
        color = mix(horizon, ground, half(t));
    }

    // --- Horizon glow ---

    // Atmospheric scattering glow near the horizon
    float glowWidth = 0.12 + twilight * 0.08;
    float glow = exp(-abs(horizonDist) / glowWidth);
    glow *= (0.3 + twilight * 0.7 + sunAngle * 0.2);

    half3 glowColor = mix(half3(0.7, 0.85, 1.0), half3(1.0, 0.6, 0.2), half(twilight));
    glowColor = mix(glowColor, half3(0.5, 0.55, 0.6), half(weatherFactor * 0.8));

    color += glowColor * half(glow * 0.4);

    // --- Sun/Moon disc ---

    float sunX = 0.5 + cos(timeOfDay * 2.0 * M_PI_F - M_PI_F / 2.0) * 0.3;
    float sunY = horizonY - sin(timeOfDay * M_PI_F) * 0.45;

    float2 sunPos = float2(sunX, sunY);
    float distToSun = length(uv - sunPos);

    if (sunAngle > 0.05) {
        // Sun glow
        float sunGlow = exp(-distToSun * distToSun * 80.0) * sunAngle;
        sunGlow *= (1.0 - weatherFactor * 0.8);
        half3 sunColor = mix(half3(1.0, 0.85, 0.5), half3(1.0, 0.4, 0.1), half(twilight));
        color += sunColor * half(sunGlow * 0.5);

        // Subtle sun halo
        float halo = exp(-distToSun * 8.0) * sunAngle * 0.15;
        halo *= (1.0 - weatherFactor * 0.9);
        color += sunColor * half(halo);
    } else {
        // Moon glow at night
        float moonGlow = exp(-distToSun * distToSun * 200.0) * (1.0 - sunAngle);
        moonGlow *= (1.0 - weatherFactor * 0.6);
        color += half3(0.7, 0.75, 0.85) * half(moonGlow * 0.3);
    }

    // --- Subtle animated atmospheric haze ---

    float haze = sin(uv.x * 12.0 + animTime * 0.3) * 0.5 + 0.5;
    haze *= sin(uv.y * 8.0 - animTime * 0.2) * 0.5 + 0.5;
    haze *= 0.015 * weatherFactor;
    color += half3(haze);

    // --- Cloud layer (for overcast weather) ---

    if (weatherFactor > 0.2) {
        float cloudY = smoothstep(0.1, 0.5, 1.0 - uv.y);
        float cloudNoise = sin(uv.x * 20.0 + animTime * 0.4) * 0.5 + 0.5;
        cloudNoise *= sin(uv.x * 7.0 - animTime * 0.15 + uv.y * 5.0) * 0.5 + 0.5;
        float clouds = cloudNoise * cloudY * weatherFactor * 0.12;
        color += half3(clouds);
    }

    return half4(color, 1.0);
}
