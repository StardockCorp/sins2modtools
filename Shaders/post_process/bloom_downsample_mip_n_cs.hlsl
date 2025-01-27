// Ironclad: this is adapted from the original MiniEngine version by Standard. 
// See the original at https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/DownsampleBloomAllCS.hlsl

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
//
// The CS for downsampling 16x16 blocks of pixels down to 8x8, 4x4, 2x2, and 1x1 blocks.

#include "../external/post_effects_rs.hlsli"

Texture2D<float3> BloomBuf : register( t0 );
RWTexture2D<float3> Result1 : register( u0 );
RWTexture2D<float3> Result2 : register( u1 );
RWTexture2D<float3> Result3 : register( u2 );
RWTexture2D<float3> Result4 : register( u3 );
SamplerState BiLinearClamp : register( s0 );

cbuffer bloom_downsample_mip_n_cb_data : register(b0)
{
    float2 g_inverseDimensions; // defined as bloom_texel_size in d3d11_game_renderer
    float2 bloom_downsample_mip_n_cb_data_padding; // defined as bloom_multipurpose_float and padding in d3d11_game_renderer
}

groupshared float3 g_Tile[64];    // 8x8 input pixels

//Ironclad
float3 downsample_13_tap(float2 uv)
{
    // 13 tap sample layout   
    // 0...1...2
    // ..3...4..
    // 5...6...7
    // ..8...9..
    // 10..l1..12

    const int sample_count = 13;
    const float2 offsets[sample_count] = 
    {
        //row 0
        float2(-2.f, +2.f), 
        float2(+0.f, +2.f), 
        float2(+2.f, +2.f),

        // row 1
        float2(-1.f, +1.f), 
        float2(+1.f, +1.f),
        
        // row 2
        float2(-2.f, +0.f), 
        float2(+0.f, +0.f), 
        float2(+2.f, +0.f),

        // row 3
        float2(-1.f, -1.f), 
        float2(+1.f, -1.f), 

        //row 4               
        float2(-2.f, -2.f), 
        float2(+0.f, -2.f), 
        float2(+2.f, -2.f),
    };

    float3 c[sample_count];
    for(int i = 0; i < sample_count; ++i)
    {
        c[i] = BloomBuf.SampleLevel(BiLinearClamp, uv + offsets[i] * g_inverseDimensions, 0.0f);
    }

    float2 weights = .25f * float2(.5f, .125f);

    float3 avg_color =  
        (c[8] + c[3] + c[4] + c[9]) * weights.x +
        (c[10] + c[5] + c[6] + c[11]) * weights.y +
        (c[5] + c[0] + c[1] + c[6]) * weights.y +
        (c[6] + c[1] + c[2] + c[7]) * weights.y +
        (c[11] + c[6] + c[7] + c[12]) * weights.y;

    return avg_color;
}

[RootSignature(PostEffects_RootSig)]
[numthreads( 8, 8, 1 )]
void main( uint GI : SV_GroupIndex, uint3 DTid : SV_DispatchThreadID )
{
    // You can tell if both x and y are divisible by a power of two with this value
    uint parity = DTid.x | DTid.y;

    // Downsample and store the 8x8 block
    float2 centerUV = (float2(DTid.xy) * 2.0f + 1.0f) * g_inverseDimensions;
    
    //Ironclad
    //float3 avgPixel = BloomBuf.SampleLevel(BiLinearClamp, centerUV, 0.0f);
    float3 avgPixel = downsample_13_tap(centerUV);
    
    g_Tile[GI] = avgPixel;
    Result1[DTid.xy] = avgPixel;

    GroupMemoryBarrierWithGroupSync();

    // Ironclad: we could 13_tap the next 3 downsamples but the difference is negligible.
    // Not worth all the array boundary checks.

    // Downsample and store the 4x4 block
    if ((parity & 1) == 0)
    {
        avgPixel = 0.25f * (avgPixel + g_Tile[GI+1] + g_Tile[GI+8] + g_Tile[GI+9]);
        g_Tile[GI] = avgPixel;
        Result2[DTid.xy >> 1] = avgPixel;
    }

    GroupMemoryBarrierWithGroupSync();

    // Downsample and store the 2x2 block
    if ((parity & 3) == 0)
    {
        avgPixel = 0.25f * (avgPixel + g_Tile[GI+2] + g_Tile[GI+16] + g_Tile[GI+18]);
        g_Tile[GI] = avgPixel;
        Result3[DTid.xy >> 2] = avgPixel;
    }

    GroupMemoryBarrierWithGroupSync();

    // Downsample and store the 1x1 block
    if ((parity & 7) == 0)
    {
        avgPixel = 0.25f * (avgPixel + g_Tile[GI+4] + g_Tile[GI+32] + g_Tile[GI+36]);
        Result4[DTid.xy >> 3] = avgPixel;
    }
}
