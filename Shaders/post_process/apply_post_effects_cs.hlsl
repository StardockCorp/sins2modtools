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
//

#include "../external/tone_mapping_utility.hlsli"
#include "exposure_state_sb_data.hlsli"
#include "post_process_cb_data.hlsli"

SamplerState LinearClampSampler : register(s0);

Texture2D<float3> scene_texture_in : register(t0);
Texture2D<float3> refraction_texture : register(t1);
Texture2D<float3> bloom_texture : register(t2);
StructuredBuffer<exposure_state_sb_data> exposure_texture : register(t3);

RWTexture2D<float3> scene_texture_out : register(u0);

[numthreads( 8, 8, 1 )]
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
	
	const float3 sdr_color = TM_Stanard(hdr_color);
	scene_texture_out[DTid.xy] = sdr_color;
}
