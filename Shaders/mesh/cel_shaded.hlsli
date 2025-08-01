float3 PosterizeLightness(float3 color, float levels)
{
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    float stepped = floor(luminance * levels) / levels;
    float3 flatColor = normalize(color + 1e-5) * stepped;
    return saturate(flatColor);
}


float3 CelShading(
    float3 baseColor,
    float3 normal,
    float3 lightDir,
    float3 viewDir,
    float occlusion,
    float viewDepth
)
{
    normal = normalize(normal);
    lightDir = normalize(lightDir);
    viewDir = normalize(viewDir);

    // === Constants
    const float3 luminanceWeights = float3(0.299, 0.587, 0.114);
    const float greyLowStart      = 0.04;
    const float greyLowEnd        = 0.12;
    const float greyHighStart     = 0.18;
    const float greyHighEnd       = 0.3;
    const float gammaDefaultPow   = 1.8;
    const float gammaSoftPow      = 1.2;
    const float posterizeLevel    = 8.0;
    const float posterizeBlend    = 0.6;
    const float rimPow            = 2.0;
    const float rimStart          = 0.9;
    const float rimEnd            = 0.97;
    const float rimStrength       = 1.0;
    const float edgeThresholdMin  = 0.04;
    const float edgeThresholdMax  = 0.30;
    const float edgeOutlinePow    = 0.3;

    float brightness = dot(baseColor, luminanceWeights);
    float greyMask = smoothstep(greyLowStart, greyLowEnd, brightness) * (1.0 - smoothstep(greyHighStart, greyHighEnd, brightness));
    float3 gammaDefault = pow(saturate(baseColor), gammaDefaultPow);
    float3 gammaSoft = pow(saturate(baseColor), gammaSoftPow);
    baseColor = lerp(gammaDefault, gammaSoft, greyMask);

    float3 hardPoster = PosterizeLightness(baseColor, posterizeLevel);
    baseColor = lerp(baseColor, hardPoster, posterizeBlend);

    float NdotL = saturate(dot(normal, lightDir));

    float3 step0 = baseColor * 0.02;
    float3 step1 = baseColor * 0.15;
    float3 step2 = baseColor * 0.3;
    float3 step3 = baseColor * 0.5;
    float3 step4 = baseColor * 0.65;
    float3 step5 = baseColor * 0.8;
    float3 step6 = baseColor * 0.95;
    float3 step7 = baseColor * 1.0;

    float3 result = step0;
    result = lerp(result, step1, smoothstep(0.125, 0.127, NdotL));
    result = lerp(result, step2, smoothstep(0.25,  0.252, NdotL));
    result = lerp(result, step3, smoothstep(0.375, 0.377, NdotL));
    result = lerp(result, step4, smoothstep(0.5,   0.502, NdotL));
    result = lerp(result, step5, smoothstep(0.625, 0.627, NdotL));
    result = lerp(result, step6, smoothstep(0.75,  0.752, NdotL));
    result = lerp(result, step7, smoothstep(0.875, 0.877, NdotL));

    // === Stylized Black Rim Light
    float rim = 1.0 - saturate(dot(normal, viewDir));
    rim = smoothstep(rimStart, rimEnd, pow(rim, rimPow));
    float3 rimColor = float3(0.0, 0.0, 0.0);
    result = lerp(result, rimColor, rim * rimStrength);

    // === Outer Silhouette Edge Detection (Thick + Stable)
    float3 n = normalize(normal);
    float3 gradX = ddx(n);
    float3 gradY = ddy(n);
    float edgeStrength = length(gradX) + length(gradY);

    float edgeThreshold = smoothstep(edgeThresholdMin, edgeThresholdMax, edgeStrength);
    float edgeOutline = saturate(pow(edgeThreshold, edgeOutlinePow));
    result = lerp(result, float3(0.0, 0.0, 0.0), edgeOutline);

    return saturate(result);
}

float3 CelShadingJagged(
    float3 baseColor,
    float3 normal,
    float3 lightDir,
    float3 viewDir,
    float occlusion,
    float viewDepth
)
{
    normal = normalize(normal);
    lightDir = normalize(lightDir);
    viewDir = normalize(viewDir);

    // === Constants
    const float3 luminanceWeights = float3(0.299, 0.587, 0.114);
    const float greyLowStart     = 0.04;
    const float greyLowEnd       = 0.12;
    const float greyHighStart    = 0.18;
    const float greyHighEnd      = 0.3;
    const float gammaDefaultPow  = 2.0;
    const float gammaSoftPow     = 1.15;
    const float posterizeLevel   = 8.0;
    const float posterizeBlend   = 0.6;
    const float aoStrength       = 1.0;
    const float3 aoTint          = float3(0.1, 0.1, 0.2);
    const float edgeStepMin      = 0.09;
    const float edgeStepMax      = 0.40;
    const float edgeStrengthMul  = 1.5;
    const float viewZNear        = 10.0;
    const float viewZFar         = 100.0;
    const float edgeScaleMin     = 1.0;
    const float edgeScaleMax     = 2.0;

    // === Adaptive gamma correction for dark greys
    float brightness = dot(baseColor, luminanceWeights);

    // Mask for lifting dark greys, not pure black or midtones
    float greyMask = smoothstep(greyLowStart, greyLowEnd, brightness) * (1.0 - smoothstep(greyHighStart, greyHighEnd, brightness));

    // Standard gamma for everything
    float3 gammaDefault = pow(saturate(baseColor), gammaDefaultPow);

    // Custom gamma for dark greys (weaker correction = lighter result)
    float3 gammaSoft = pow(saturate(baseColor), gammaSoftPow);

    // Blend between them
    baseColor = lerp(gammaDefault, gammaSoft, greyMask);

    // === Posterize base color lightness
    float3 hardPoster = PosterizeLightness(baseColor, posterizeLevel);
    baseColor = lerp(baseColor, hardPoster, posterizeBlend);

    float NdotL = saturate(dot(normal, lightDir));

    // === Lighting Band Steps
    float3 step0 = baseColor * 0.02;
    float3 step1 = baseColor * 0.15;
    float3 step2 = baseColor * 0.3;
    float3 step3 = baseColor * 0.5;
    float3 step4 = baseColor * 0.65;
    float3 step5 = baseColor * 0.8;
    float3 step6 = baseColor * 0.95;
    float3 step7 = baseColor * 1.0;

    float3 result = step0;
    result = lerp(result, step1, smoothstep(0.125, 0.127, NdotL));
    result = lerp(result, step2, smoothstep(0.25,  0.252, NdotL));
    result = lerp(result, step3, smoothstep(0.375, 0.377, NdotL));
    result = lerp(result, step4, smoothstep(0.5,   0.502, NdotL));
    result = lerp(result, step5, smoothstep(0.625, 0.627, NdotL));
    result = lerp(result, step6, smoothstep(0.75,  0.752, NdotL));
    result = lerp(result, step7, smoothstep(0.875, 0.877, NdotL));

    // === AO-Based Fake Depth (Stylized)
    float aoDepth = 1.0 - occlusion;
    result = lerp(result, result * aoTint, aoDepth * aoStrength);

    // === Screen-Space Normal-Based Edge Detection
    float3 n = normalize(normal);
    float3 gradX = ddx(n);
    float3 gradY = ddy(n);
    float edge = length(gradX) + length(gradY);
    float edgeSmooth = edge / (fwidth(n.x) + fwidth(n.y) + fwidth(n.z));
    float viewZ = abs(viewDepth);
    float edgeScale = lerp(edgeScaleMin, edgeScaleMax, saturate((viewZ - viewZNear) / viewZFar));
    float edgeStrength = saturate(edge * edgeStrengthMul * edgeScale);
    float edgeMask = smoothstep(edgeStepMin, edgeStepMax, edgeStrength);
    result = lerp(result, float3(0.0, 0.0, 0.0), edgeMask);

    return saturate(result);
}
