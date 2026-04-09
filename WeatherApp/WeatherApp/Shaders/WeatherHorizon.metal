// WeatherHorizon.metal — Realistic weather sky renderer
// Three [[ stitchable ]] colorEffect shaders for layered compositing:
//   1. atmosphericSky  — Rayleigh/Mie scattering, sun/moon, arc path, ground
//   2. proceduralClouds — FBM noise clouds driven by real cloud cover data
//   3. weatherParticles — Rain streaks + splashes, snow

#include <metal_stdlib>
using namespace metal;

// ============================================================
// MARK: - Shared Utilities
// ============================================================

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < octaves; i++) {
        value += amp * valueNoise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// Domain-warped FBM (Inigo Quilez technique) for organic cloud shapes
float warpedFbm(float2 p, float time, int octaves) {
    float2 q = float2(
        fbm(p + float2(0.0, 0.0) + time * 0.08, 3),
        fbm(p + float2(5.2, 1.3) + time * 0.06, 3)
    );
    return fbm(p + 3.0 * q, octaves);
}

// ============================================================
// MARK: - Layer 1: Atmospheric Sky
// ============================================================
// Params: size, sunElevation (-1..1), sunAzimuth (0..1),
//         animTime, visibility (0..1), humidity (0..1),
//         groundColor (float3), isNight (0 or 1)

[[ stitchable ]]
half4 atmosphericSky(float2 position, half4 currentColor,
                     float2 size, float sunElevation, float sunAzimuth,
                     float animTime, float visibility, float humidity,
                     float3 groundColor, float isNight) {

    float2 uv = position / size;
    float horizonY = 0.78; // Lower horizon — arc sits in bottom portion

    // --- Atmospheric scattering approximation ---

    float sunElClamped = max(sunElevation, -0.3);
    float dayFactor = smoothstep(-0.1, 0.3, sunElevation);

    // Rayleigh-like color: blue zenith, warm horizon at low sun
    float3 betaR = float3(0.15, 0.35, 0.85); // Blue scattering
    float viewAngle = max(1.0 - uv.y / horizonY, 0.0); // 0 at top, 1 at horizon
    float opticalDepth = 1.0 / (max(1.0 - viewAngle, 0.05));

    // Zenith color
    float3 zenithDay = float3(0.15, 0.38, 0.82);
    float3 zenithTwilight = float3(0.12, 0.08, 0.28);
    float3 zenithNight = float3(0.02, 0.03, 0.08);

    float twilightFactor = smoothstep(-0.1, 0.0, sunElevation) * smoothstep(0.3, 0.0, sunElevation);

    float3 zenith = mix(zenithNight, zenithDay, dayFactor);
    zenith = mix(zenith, zenithTwilight, twilightFactor * 0.7);

    // Horizon color — warm at sunrise/sunset
    float3 horizonDay = float3(0.55, 0.70, 0.90);
    float3 horizonTwilight = float3(0.95, 0.50, 0.15);
    float3 horizonNight = float3(0.05, 0.06, 0.12);

    float3 horizon = mix(horizonNight, horizonDay, dayFactor);
    horizon = mix(horizon, horizonTwilight, twilightFactor * 0.85);

    // Sky gradient
    float3 skyColor;
    if (uv.y < horizonY) {
        float t = pow(uv.y / horizonY, 1.5); // Stronger curve
        skyColor = mix(zenith, horizon, t);
    } else {
        // Below horizon — immediate dark silhouette (reference style)
        skyColor = float3(0.03, 0.03, 0.04);
    }

    // --- Atmospheric haze near horizon (above only) ---
    float hazeDist = uv.y < horizonY ? horizonY - uv.y : 10.0; // Only above horizon
    float haze = exp(-hazeDist * hazeDist * 80.0);
    float3 hazeColor = mix(float3(0.6, 0.55, 0.5), float3(0.85, 0.55, 0.25), twilightFactor);
    hazeColor = mix(hazeColor, float3(0.15, 0.15, 0.18), isNight);
    float hazeStrength = 0.25 + humidity * 0.15 + (1.0 - visibility) * 0.2;
    skyColor = mix(skyColor, hazeColor, haze * hazeStrength);

    // --- Horizon glow band (above horizon only) ---
    float glowWidth = 0.06 + twilightFactor * 0.04;
    float horizonGlow = (uv.y < horizonY) ? exp(-hazeDist / glowWidth) : 0.0;
    float3 glowColor = mix(float3(0.5, 0.6, 0.8), float3(1.0, 0.6, 0.2), twilightFactor);
    glowColor = mix(glowColor, float3(0.08, 0.08, 0.12), isNight * 0.8);
    skyColor += glowColor * horizonGlow * 0.3 * (1.0 - isNight * 0.7);

    // --- Sun disc + bloom ---
    if (isNight < 0.5) {
        // Sun position on elliptical arc
        float arcRadiusX = 0.42;
        float arcRadiusY = 0.28;
        float angle = M_PI_F * (1.0 - sunAzimuth);
        float2 sunPos = float2(
            0.5 + arcRadiusX * cos(angle),
            horizonY - arcRadiusY * sin(angle)
        );

        float distToSun = length((uv - sunPos) * float2(1.0, size.y / size.x));

        // Hard disc core
        float disc = smoothstep(0.018, 0.012, distToSun);
        // Inner bloom (tight)
        float bloom1 = exp(-distToSun * distToSun * 800.0) * 1.5;
        // Medium bloom
        float bloom2 = exp(-distToSun * 20.0) * 0.5;
        // Wide atmospheric glow
        float bloom3 = exp(-distToSun * 5.0) * 0.2;

        // Sun color: white-hot at high elevation, orange at horizon
        float3 sunCore = mix(float3(1.0, 0.75, 0.35), float3(1.0, 1.0, 0.92), sunElevation);
        float3 sunGlow = mix(float3(1.0, 0.5, 0.12), float3(1.0, 0.85, 0.6), sunElevation);

        skyColor += sunCore * disc * 8.0;
        skyColor += sunCore * bloom1;
        skyColor += sunGlow * bloom2;
        skyColor += sunGlow * bloom3;
    } else {
        // Moon disc + glow
        float angle = M_PI_F * (1.0 - sunAzimuth);
        float2 moonPos = float2(
            0.5 + 0.42 * cos(angle),
            horizonY - 0.22 * sin(angle)
        );

        float distToMoon = length((uv - moonPos) * float2(1.0, size.y / size.x));

        // Moon disc
        float moonDisc = smoothstep(0.016, 0.010, distToMoon);
        // Subtle surface detail
        float surface = 0.85 + 0.15 * valueNoise(uv * 80.0);
        // Glow
        float moonGlow1 = exp(-distToMoon * 30.0) * 0.3;
        float moonGlow2 = exp(-distToMoon * 8.0) * 0.1;

        float3 moonColor = float3(0.90, 0.88, 0.82) * surface;
        skyColor += moonColor * moonDisc * 2.0;
        skyColor += float3(0.6, 0.65, 0.8) * moonGlow1;
        skyColor += float3(0.4, 0.45, 0.6) * moonGlow2;

        // Stars — each with random blink rate and opacity range
        if (uv.y < horizonY - 0.05) {
            float2 starGrid = floor(uv * 120.0);
            float starHash = hash21(starGrid);
            if (starHash > 0.982) {
                float2 starCenter = (starGrid + 0.5) / 120.0;
                float starDist = length(uv - starCenter) * 300.0;
                // Random blink speed (0.3 to 3.0) and phase per star
                float blinkSpeed = 0.3 + hash21(starGrid * 3.7) * 2.7;
                float blinkPhase = hash21(starGrid * 7.1) * 100.0;
                // Random base brightness (0.2 to 0.8) — dimmer stars don't dip as much
                float baseBright = 0.2 + hash21(starGrid * 11.3) * 0.6;
                float flicker = baseBright + (1.0 - baseBright) * (0.5 + 0.5 * sin(animTime * blinkSpeed + blinkPhase));
                float starBright = exp(-starDist * starDist) * flicker;
                // Random color temperature (warm to cool stars)
                float temp = hash21(starGrid * 5.3);
                float3 starColor = mix(float3(0.8, 0.85, 1.0), float3(1.0, 0.9, 0.7), temp);
                skyColor += starColor * starBright * 0.5;
            }
        }
    }

    // --- Sun/Moon arc path (dotted) — flat ellipse like reference images ---
    {
        float arcRX = 0.42;
        float arcRY = isNight > 0.5 ? 0.22 : 0.28;
        float bestDist = 1000.0;
        float bestParam = 0.0;

        // Sample points along the elliptical arc to find closest
        for (int i = 0; i <= 40; i++) {
            float t = float(i) / 40.0;
            float a = M_PI_F * (1.0 - t);
            float2 arcPt = float2(0.5 + arcRX * cos(a), horizonY - arcRY * sin(a));
            float d = length((uv - arcPt) * float2(1.0, size.y / size.x));
            if (d < bestDist) {
                bestDist = d;
                bestParam = t;
            }
        }

        // Dotted pattern
        float dotFreq = 50.0;
        float dotPattern = smoothstep(0.45, 0.55, fract(bestParam * dotFreq));

        // Arc line
        float arcLine = smoothstep(0.005, 0.002, bestDist);
        arcLine *= dotPattern;

        // Progress: completed portion is brighter
        float completed = step(bestParam, sunAzimuth);
        float arcAlpha = arcLine * mix(0.12, 0.35, completed);

        skyColor += float3(arcAlpha);
    }

    // Tone mapping (prevent oversaturation)
    skyColor = skyColor / (1.0 + skyColor * 0.3);

    return half4(half3(skyColor), 1.0h);
}

// ============================================================
// MARK: - Layer 2: Procedural Clouds
// ============================================================
// Params: size, cloudCover (float3: low,mid,high), windSpeed,
//         sunElevation, weatherCode, animTime

[[ stitchable ]]
half4 proceduralClouds(float2 position, half4 currentColor,
                       float2 size, float3 cloudCover, float windSpeed,
                       float sunElevation, float weatherCode, float animTime) {

    float2 uv = position / size;
    float horizonY = 0.78; // Lower horizon — arc sits in bottom portion

    // Early return below horizon or if no clouds
    float totalCover = cloudCover.x + cloudCover.y + cloudCover.z;
    if (uv.y > horizonY + 0.02 || totalCover < 0.02) {
        return currentColor;
    }

    float3 color = float3(currentColor.rgb);
    float dayFactor = smoothstep(-0.1, 0.3, sunElevation);
    float2 wind = float2(animTime * windSpeed * 0.02, animTime * windSpeed * 0.005);

    // Cloud base color — bright during day, dark during storms/night
    float3 cloudBright = mix(float3(0.25, 0.27, 0.35), float3(0.92, 0.90, 0.88), dayFactor);
    float3 cloudDark = mix(float3(0.08, 0.08, 0.12), float3(0.45, 0.43, 0.42), dayFactor);

    // Darken for storms
    float stormDarken = smoothstep(80.0, 99.0, weatherCode) * 0.5;
    cloudBright -= stormDarken;
    cloudDark -= stormDarken * 0.5;

    // Golden hour tint
    float twilight = smoothstep(-0.1, 0.0, sunElevation) * smoothstep(0.3, 0.0, sunElevation);
    cloudBright = mix(cloudBright, float3(1.0, 0.75, 0.45), twilight * 0.4);

    // --- High clouds (cirrus) — thin, wispy, top of sky ---
    if (cloudCover.z > 0.02) {
        float yMask = smoothstep(horizonY, 0.0, uv.y); // Strongest at top
        float2 hUV = uv * float2(3.0, 8.0) + wind * 1.5;
        float highCloud = warpedFbm(hUV, animTime * 0.5, 5);
        highCloud = smoothstep(0.45 - cloudCover.z * 0.25, 0.65, highCloud);
        highCloud *= yMask * cloudCover.z;

        float3 hColor = mix(cloudDark, cloudBright, 0.7 + highCloud * 0.3);
        color = mix(color, hColor, highCloud * 0.4);
    }

    // --- Mid clouds (altocumulus) — mid-sky, medium density ---
    if (cloudCover.y > 0.02) {
        float yMask = smoothstep(horizonY, 0.15, uv.y) * smoothstep(0.0, 0.2, uv.y);
        float2 mUV = uv * float2(2.5, 5.0) + wind;
        float midCloud = warpedFbm(mUV, animTime * 0.3, 4);
        midCloud = smoothstep(0.42 - cloudCover.y * 0.22, 0.62, midCloud);
        midCloud *= yMask * cloudCover.y;

        // Light/shadow on clouds
        float light = 0.6 + 0.4 * fbm(mUV + float2(0.1, 0.0), 2);
        float3 mColor = mix(cloudDark, cloudBright, light);
        color = mix(color, mColor, midCloud * 0.55);
    }

    // --- Low clouds (stratus) — near horizon, thick and opaque ---
    if (cloudCover.x > 0.02) {
        float yMask = smoothstep(horizonY, 0.25, uv.y) * smoothstep(0.1, 0.35, uv.y);
        float2 lUV = uv * float2(2.0, 3.0) + wind * 0.6;
        float lowCloud = warpedFbm(lUV, animTime * 0.2, 3);
        lowCloud = smoothstep(0.38 - cloudCover.x * 0.20, 0.58, lowCloud);
        lowCloud *= yMask * cloudCover.x;

        float light = 0.5 + 0.5 * fbm(lUV + float2(0.05, -0.05), 2);
        float3 lColor = mix(cloudDark * 0.8, cloudBright, light);
        color = mix(color, lColor, lowCloud * 0.65);
    }

    return half4(half3(color), currentColor.a);
}

// ============================================================
// MARK: - Layer 3: Weather Particles (Rain/Snow)
// ============================================================
// Params: size, precipAmount (mm), isSnow, windSpeed, animTime

[[ stitchable ]]
half4 weatherParticles(float2 position, half4 currentColor,
                       float2 size, float precipAmount, float isSnow,
                       float windSpeed, float animTime) {

    // Early return if no precipitation
    if (precipAmount < 0.05) {
        return currentColor;
    }

    float2 uv = position / size;
    float3 color = float3(currentColor.rgb);
    float horizonY = 0.78; // Lower horizon — arc sits in bottom portion
    float intensity = min(precipAmount / 3.0, 1.0); // Normalize to 0-1

    if (isSnow < 0.5) {
        // --- Rain ---
        float rain = 0.0;
        float windTilt = windSpeed * 0.12;

        // Layer 1: foreground rain (large, fast)
        {
            float2 cellSize = float2(0.04, 0.25);
            float2 cell = floor(uv / cellSize);
            float rng = hash21(cell);
            float xOff = hash21(cell * 1.7) * 0.7 + 0.15;
            float speed = 1.2 + rng * 0.4;
            float yAnim = fract(uv.y / cellSize.y + animTime * speed + rng);
            float xDist = abs(fract(uv.x / cellSize.x) - xOff + yAnim * windTilt);
            float streak = smoothstep(0.012, 0.004, xDist);
            streak *= smoothstep(0.0, 0.04, yAnim) * smoothstep(0.35, 0.15, yAnim);
            rain += streak * (0.3 + 0.7 * rng) * 0.5;
        }

        // Layer 2: midground rain
        {
            float2 cellSize = float2(0.055, 0.3);
            float2 cell = floor(uv / cellSize + 7.0);
            float rng = hash21(cell);
            float xOff = hash21(cell * 2.3) * 0.6 + 0.2;
            float speed = 1.0 + rng * 0.3;
            float yAnim = fract(uv.y / cellSize.y + animTime * speed + rng);
            float xDist = abs(fract(uv.x / cellSize.x) - xOff + yAnim * windTilt * 0.8);
            float streak = smoothstep(0.01, 0.003, xDist);
            streak *= smoothstep(0.0, 0.03, yAnim) * smoothstep(0.3, 0.12, yAnim);
            rain += streak * (0.2 + 0.6 * rng) * 0.35;
        }

        // Layer 3: background rain (faint, slow)
        {
            float2 cellSize = float2(0.07, 0.4);
            float2 cell = floor(uv / cellSize + 13.0);
            float rng = hash21(cell);
            float xOff = hash21(cell * 3.1) * 0.5 + 0.25;
            float speed = 0.7 + rng * 0.3;
            float yAnim = fract(uv.y / cellSize.y + animTime * speed + rng);
            float xDist = abs(fract(uv.x / cellSize.x) - xOff + yAnim * windTilt * 0.5);
            float streak = smoothstep(0.008, 0.002, xDist);
            streak *= smoothstep(0.0, 0.02, yAnim) * smoothstep(0.25, 0.1, yAnim);
            rain += streak * rng * 0.2;
        }

        rain *= intensity;

        // Splash effects at horizon
        float splash = 0.0;
        if (uv.y > horizonY - 0.02 && uv.y < horizonY + 0.03) {
            float cellX = floor(uv.x * 40.0);
            float rng = hash21(float2(cellX, floor(animTime * 5.0)));
            if (rng > 0.6) {
                float t = fract(animTime * 4.0 + hash21(float2(cellX, 0.0)));
                float radius = t * 0.012;
                float fade = (1.0 - t) * (1.0 - t);
                float2 center = float2((cellX + 0.5) / 40.0, horizonY);
                float dist = length((uv - center) * float2(1.0, 3.0));
                float ring = smoothstep(radius + 0.003, radius, dist)
                           * smoothstep(radius - 0.003, radius, dist);
                splash += ring * fade * intensity;
            }
        }

        float3 rainColor = float3(0.65, 0.70, 0.78);
        color = mix(color, rainColor, rain * 0.5 + splash * 0.3);

    } else {
        // --- Snow ---
        float snow = 0.0;

        for (int layer = 0; layer < 3; layer++) {
            float layerSeed = float(layer) * 7.0;
            float scale = 0.06 + float(layer) * 0.02;
            float speed = 0.15 + float(layer) * 0.05;
            float drift = sin(animTime * 0.5 + layerSeed) * 0.02;

            float2 cellSize = float2(scale, scale);
            float2 cell = floor((uv + float2(drift, 0.0)) / cellSize + layerSeed);
            float rng = hash21(cell);

            float2 center = (cell + float2(hash21(cell * 1.3), hash21(cell * 2.7))) * cellSize;
            center.y = fract(center.y + animTime * speed + rng);
            center.x += sin(animTime * 0.3 + rng * 20.0) * 0.008 + windSpeed * 0.01;

            float dist = length(uv - center);
            float flake = smoothstep(0.005, 0.002, dist);
            snow += flake * (0.4 + 0.6 * rng) * 0.4;
        }

        snow *= intensity;
        color = mix(color, float3(0.9, 0.92, 0.95), snow * 0.6);
    }

    return half4(half3(color), currentColor.a);
}
