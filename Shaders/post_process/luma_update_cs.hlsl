#include "../external/shader_utility.hlsli"

// adapted from https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/ExtractLumaCS.hlsl
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

SamplerState BiLinearClamp : register( s0 );
Texture2D<float3> ColorTex : register( t0 );
RWTexture2D<uint> LumaResult : register( u0 );

// see d3d11_game_renderer
cbuffer luma_cb_data
{
    float2 luma_texel_size;
    float exposure_log_luminance_min;
    float exposure_log_luminance_range_rcp;
}

[numthreads( 8, 8, 1 )]
void main( uint3 global_thread_id : SV_DispatchThreadID )
{
    float2 uv = (global_thread_id.xy + .5f) * luma_texel_size;
    float2 src_pixel_size = luma_texel_size * .5f;

    const int sample_count = 4;

    // 4 tap sample
    const float2 offsets[sample_count] = 
    {
        float2(-1.f, -1.f), 
        float2(-1.f, +1.f), 
        float2(+1.f, +1.f),
        float2(+1.f, -1.f),
    };       
        
    float luma = 0.f;
    for(int i = 0; i < sample_count; i++)
    {
        const float3 color = ColorTex.SampleLevel(BiLinearClamp, uv + offsets[i] * src_pixel_size, 0);
        luma += RGBToLuminance(color);
    }   
    luma /= sample_count;
    
	// log2(0) is undefined so needs special handling
    if (luma == 0.0)
    {
        LumaResult[global_thread_id.xy] = 0;
    }
    else
    {
        const float log_luma = saturate((log2(luma) - exposure_log_luminance_min) * exposure_log_luminance_range_rcp); // Rescale to [0.0, 1.0]
        LumaResult[global_thread_id.xy] = log_luma * 254.0 + 1.0; // Rescale to [1, 255] (0 was already handled as special case due to log(0) being undefined)
    }
}