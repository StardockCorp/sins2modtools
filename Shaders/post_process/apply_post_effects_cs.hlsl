// Adapted from ToneMapCS.hlsl

// which falls under this license:
//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
// Developed by Minigraph
//
// Author:  James Stanard 

#include "../external/tone_mapping_utility.hlsli"
#include "exposure_state_sb_data.hlsli"
#include "post_process_cb_data.hlsli"


#include "../mesh/ex_features_ps_data.hlsli"

SamplerState LinearClampSampler : register(s0);

Texture2D<float3> scene_texture_in : register(t0);
Texture2D<float3> refraction_texture : register(t1);
Texture2D<float3> bloom_texture : register(t2);
StructuredBuffer<exposure_state_sb_data> exposure_texture : register(t3);

RWTexture2D<float3> scene_texture_out : register(u0);

// Define near and far planes for depth linearization
static const float near_plane = 0.1;
static const float far_plane = 1000.0;

float LinearizeDepth(float depth)
{
    float z = depth * 2.0 - 1.0;
    return 2.0 * near_plane * far_plane / (far_plane + near_plane - z * (far_plane - near_plane));
}

[numthreads(8, 8, 1)]
void main(uint3 DTid : SV_DispatchThreadID)
{
    const float2 scene_uv = (DTid.xy + 0.5f) * scene_texel_size;

#ifdef ENABLE_REFRACTION
    const float2 refraction_offset = refraction_texture.SampleLevel(LinearClampSampler, scene_uv, 0).rg;
    const float2 refraction_uv = scene_uv + refraction_offset;
#else
    const float2 refraction_uv = scene_uv;
#endif


    float3 hdr_color = scene_texture_in.SampleLevel(LinearClampSampler, refraction_uv, 0);
    hdr_color.rgb += bloom_strength * bloom_texture.SampleLevel(LinearClampSampler, refraction_uv, 0);
    hdr_color.rgb *= exposure_texture[0].exposure;

    // Tone mapping and gamma lift
    float3 sdr_color = TM_Stanard(hdr_color);
    sdr_color = pow(saturate(sdr_color), 1.0 / 1.05); // slight midtone lift
	
if (g_liq_crys_enabled == 1 || g_retro_enabled == 1)
{
    // === Scanline Intensity Modulation (brighter minimum)
    float scanline = 0.95 + 0.05 * sin(DTid.y * 3.14159);
    sdr_color *= scanline;

    // === Dot Matrix Mask (RGB triad layout)
    uint2 px = DTid.xy;
    uint cx = px.x % 3;
    float3 dotMask = float3(cx == 0 ? 1.0 : 0.3, cx == 1 ? 1.0 : 0.3, cx == 2 ? 1.0 : 0.3);
    sdr_color *= dotMask;
}	
//#endif
	
#ifdef ENABLE_CHROME_AB

    // === RGB Offset (Chromatic Aberration)
    float2 offset = 1.0 / float2(320.0, 240.0) * 1.5;
    float3 shifted;
    shifted.r = scene_texture_in.SampleLevel(LinearClampSampler, refraction_uv + offset, 0).r;
    shifted.g = sdr_color.g;
    shifted.b = scene_texture_in.SampleLevel(LinearClampSampler, refraction_uv - offset, 0).b;
    sdr_color = lerp(sdr_color, shifted, 0.35);

    // === Edge Detection for Thickness Pass (Smoothed Luma Gradient)
    float3 c00 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2(-1, -1), 0);
    float3 c10 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2( 0, -1), 0);
    float3 c20 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2( 1, -1), 0);
    float3 c01 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2(-1,  0), 0);
    float3 c21 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2( 1,  0), 0);
    float3 c02 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2(-1,  1), 0);
    float3 c12 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2( 0,  1), 0);
    float3 c22 = scene_texture_in.SampleLevel(LinearClampSampler, scene_uv + scene_texel_size * float2( 1,  1), 0);

    float3 weights = float3(0.299, 0.587, 0.114);
    float luma00 = dot(c00, weights);
    float luma10 = dot(c10, weights);
    float luma20 = dot(c20, weights);
    float luma01 = dot(c01, weights);
    float luma21 = dot(c21, weights);
    float luma02 = dot(c02, weights);
    float luma12 = dot(c12, weights);
    float luma22 = dot(c22, weights);

    float gx = luma20 + 2.0 * luma21 + luma22 - luma00 - 2.0 * luma01 - luma02;
    float gy = luma02 + 2.0 * luma12 + luma22 - luma00 - 2.0 * luma10 - luma20;
    float edgeStrength = sqrt(gx * gx + gy * gy);
    float edgeMask = smoothstep(0.08, 0.25, edgeStrength);
    sdr_color = lerp(sdr_color, float3(0, 0, 0), edgeMask * 0.35);

    // === Final Brightness Boost (optional)
    sdr_color *= 1.1;
	
#endif
	
//#ifdef ENABLE_RETRO_RES
if (g_retro_enabled == 1 || g_liq_crys_enabled == 1)
{
    float resolutionscale = 1.f;
    float2 snapAmount = float2(640.0, 480.0) * resolutionscale;
    float2 snappedUV = floor(scene_uv * snapAmount) / snapAmount;

    float3 sampledColor = scene_texture_in.SampleLevel(LinearClampSampler, snappedUV, 0).rgb;

    // === Optional: gamma correct before posterize
    sampledColor = pow(sampledColor, 1.2 / 2.2); // convert to linear-ish

    // === 2x2 Bayer Dither
    int2 bayerCoord = DTid.xy % 2;
    float dither = ((bayerCoord.x ^ bayerCoord.y) != 0) ? 0.02 : -0.02;
    sampledColor += dither;

    // === Posterization
    float posterize_level = 6.0;
    float posterize_amount = 0.8;
    float3 posterized = floor(sampledColor * posterize_level) / posterize_level;
    float3 blended = lerp(sampledColor, posterized, posterize_amount);

    // === Brightness boost (slightly stronger)
    sdr_color = blended * 4.5;

    // === Clamp
	const float3 sdr_color = TM_Stanard(hdr_color);
}
//#endif

if (g_liq_crys_enabled == 1)
{
    float luminance = dot(sdr_color, float3(0.299, 0.587, 0.114));

    // Tint with phosphor green
    float3 greenTint = float3(0.15, 0.95, 0.2); // softer than pure green

    // Blend green with grayscale for desaturation
    float3 desaturatedGreen = lerp(float3(luminance, luminance, luminance), greenTint * luminance, 0.95);

    // Apply scanline modulation
    float scanline = 0.85 + 0.15 * sin(DTid.y * 3.14159);
    desaturatedGreen *= scanline;

    // Optional brightness boost
    sdr_color = saturate(desaturatedGreen * 1.2);
}

    scene_texture_out[DTid.xy] = sdr_color;
}
