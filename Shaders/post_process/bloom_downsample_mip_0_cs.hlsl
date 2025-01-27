#include "../external/shader_utility.hlsli"

SamplerState BiLinearClamp : register( s0 );
Texture2D<float3> SourceTex : register( t0 );
Texture2D<float3> EmissiveTex: register( t1 );
RWTexture2D<float3> BloomResult : register( u0 );

cbuffer bloom_downsample_mip_0_cb_data : register(b0)
{
    float2 g_inverseOutputSize; // defined as bloom_texel_size in d3d_game_renderer
    float g_bloomThreshold; // defined as bloom_multipurpose_float in d3d_game_renderer
    float bloom_downsample_mip_0_cb_data_padding;
}

typedef float3 box[4];
typedef float lumas[4];

float3 get_karis_average(box b, lumas l)
{       
    float3 color = 0.f;
    float weight_total = 0.f;    
    for(int i = 0; i < 4; ++i)
    {        
        const float weight = 1.f / (1.f + l[i]);
        color += b[i] * weight;
        weight_total += weight;
    }
    
    return color / weight_total;
}

void downsample_miniengine(uint3 DTid : SV_DispatchThreadID)
{
    // This is a slightly modified variation of the MiniEngine downsampler by Stanard.
    // Its not used other than as a testing reference.

    // See the original at // https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/BloomExtractAndDownsampleHdrCS.hlsl

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
    //
    // The CS for extracting bright pixels and downsampling them to an unblurred bloom buffer. 
    
    // We need the scale factor and the size of one pixel so that our four samples are right in the middle
    // of the quadrant they are covering.
    float2 uv = (DTid.xy + 0.5) * g_inverseOutputSize;
    
    //Ironclad: miniengine typically multiplies by .25 here because its first bloom downsample is 1/4. Sins2 is 1/2.
    float2 offset = g_inverseOutputSize * 0.5;

    // Use 4 bilinear samples to guarantee we don't undersample when downsizing by more than 2x
    // Ironclad: only sample from the EmissiveTex.
    float3 color1 = EmissiveTex.SampleLevel( BiLinearClamp, uv + float2(-offset.x, -offset.y), 0 );
    float3 color2 = EmissiveTex.SampleLevel( BiLinearClamp, uv + float2( offset.x, -offset.y), 0 );
    float3 color3 = EmissiveTex.SampleLevel( BiLinearClamp, uv + float2(-offset.x,  offset.y), 0 );
    float3 color4 = EmissiveTex.SampleLevel( BiLinearClamp, uv + float2( offset.x,  offset.y), 0 );

    float luma1 = RGBToLuminance(color1);
    float luma2 = RGBToLuminance(color2);
    float luma3 = RGBToLuminance(color3);
    float luma4 = RGBToLuminance(color4);
    
    // Ironclad: #bloom_threshold_disabled 
	// We are only blooming emissive pixels so if it was marked as emissive it should bloom - don't filter!
    // Filter code left in for easy reference back to the original source.
    /*
    const float kSmallEpsilon = 0.0001;

    float ScaledThreshold = g_bloomThreshold * Exposure[0].exposure_rcp;    // BloomThreshold divided by Exposure
    
    // We perform a brightness filter pass, where lone bright pixels will contribute less.
    color1 *= max(kSmallEpsilon, luma1 - ScaledThreshold) / (luma1 + kSmallEpsilon);
    color2 *= max(kSmallEpsilon, luma2 - ScaledThreshold) / (luma2 + kSmallEpsilon);
    color3 *= max(kSmallEpsilon, luma3 - ScaledThreshold) / (luma3 + kSmallEpsilon);
    color4 *= max(kSmallEpsilon, luma4 - ScaledThreshold) / (luma4 + kSmallEpsilon);
    */

    // The shimmer filter helps remove stray bright pixels from the bloom buffer by inversely weighting
    // them by their luminance.  The overall effect is to shrink bright pixel regions around the border.
    // Lone pixels are likely to dissolve completely.  This effect can be tuned by adjusting the shimmer
    // filter inverse strength.  The bigger it is, the less a pixel's luminance will matter.
    const float kShimmerFilterInverseStrength = 1.0f;
    float weight1 = 1.0f / (luma1 + kShimmerFilterInverseStrength);
    float weight2 = 1.0f / (luma2 + kShimmerFilterInverseStrength);
    float weight3 = 1.0f / (luma3 + kShimmerFilterInverseStrength);
    float weight4 = 1.0f / (luma4 + kShimmerFilterInverseStrength);
    float weightSum = weight1 + weight2 + weight3 + weight4;

    BloomResult[DTid.xy] = (color1 * weight1 + color2 * weight2 + color3 * weight3 + color4 * weight4) / weightSum;   
}

void downsample_4_tap(uint3 DTid : SV_DispatchThreadID)
{
    float2 uv = (DTid.xy + .5f) * g_inverseOutputSize;
    float2 src_pixel_size = g_inverseOutputSize * .5f;

    const int sample_count = 4;

    const float2 offsets[sample_count] = 
    {
        float2(-1.f, -1.f), 
        float2(-1.f, +1.f), 
        float2(+1.f, +1.f),
        float2(+1.f, -1.f),
    };       
    
    float3 c[sample_count];
    float l[sample_count];    
    for(int i = 0; i < sample_count; i++)
    {
        c[i] = EmissiveTex.SampleLevel(BiLinearClamp, uv + offsets[i] * src_pixel_size, 0);        
        l[i] = RGBToLuminance(c[i]);        
    }    

    // 4 tap sample layout   
    // 0...1
    // .....
    // 2...3
    
    box box_c       = {c[2], c[0], c[1], c[3]};    
    lumas lumas_c   = {l[2], l[0], l[1], l[3]};

    // eliminate fireflies
    float3 center_color = get_karis_average(box_c, lumas_c);
    
    BloomResult[DTid.xy] = center_color;
}

void downsample_13_tap(uint3 DTid : SV_DispatchThreadID)
{    
    // Sins2 bloom uses a custom variation of the Call of Duty (Jimenez) downsampling method.
    // http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare    
    // Karis's Unreal method wasn't temporarily stable enough for Sins2 weapon fire.
    
    float2 uv = (DTid.xy + .5f) * g_inverseOutputSize;
    float2 src_pixel_size = g_inverseOutputSize * .5f;

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
    float l[sample_count];   
    for(int i = 0; i < sample_count; ++i)
    {
        c[i] = EmissiveTex.SampleLevel(BiLinearClamp, uv + offsets[i] * src_pixel_size, 0);
        l[i] = RGBToLuminance(c[i]);        
    }   

    // 13 tap sample layout   
    // 0...1...2
    // ..3...4..
    // 5...6...7
    // ..8...9..
    // 10..l1..12

    box box_c =     {c[8], c[3], c[4], c[9]};
    box box_ll =    {c[10], c[5], c[6], c[11]};
    box box_ul =    {c[5], c[0], c[1], c[6]};
    box box_ur =    {c[6], c[1], c[2], c[7]};
    box box_lr =    {c[11], c[6], c[7], c[12]};     

    lumas lumas_c =     {l[8], l[3], l[4], l[9]};
    lumas lumas_ll =    {l[10], l[5], l[6], l[11]};
    lumas lumas_ul =    {l[5], l[0], l[1], l[6]};
    lumas lumas_ur =    {l[6], l[1], l[2], l[7]};
    lumas lumas_lr =    {l[11], l[6], l[7], l[12]};

    // eliminate fireflies
    float3 center_color = get_karis_average(box_c, lumas_c);
    float3 corner_colors = get_karis_average(box_ll, lumas_ll);
    corner_colors += get_karis_average(box_ul, lumas_ul);
    corner_colors += get_karis_average(box_ur, lumas_ur);
    corner_colors += get_karis_average(box_lr, lumas_lr);

    BloomResult[DTid.xy] = center_color * .5f + corner_colors * .125f;       
}

[numthreads( 8, 8, 1 )]
void main( uint3 DTid : SV_DispatchThreadID )
{
    //downsample_miniengine(DTid); // for comparison testing
    //downsample_4_tap(DTid); // for comparison testing
    downsample_13_tap(DTid);
}