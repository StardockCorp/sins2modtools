// References: 
// "Luminance Scaling from Advanced Graphics Programming Using OpenGL": https://www.sciencedirect.com/topics/computer-science/average-luminance.
// https://www.unrealengine.com/en-US/tech-blog/how-epic-games-is-handling-auto-exposure-in-4-25
// http://www.alextardif.com/HistogramLuminance.html 
// https://bruop.github.io/exposure/
// https://knarkowicz.wordpress.com/2016/01/09/automatic-exposure/
// https://en.wikipedia.org/wiki/Middle_gray: basically its half way between black and white on a lightness scale (because human lightness perception is ~logarithmic).
// https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/AdaptExposureCS.hlsl
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

#include "exposure_state_sb_data.hlsli"

ByteAddressBuffer histogram : register(t0);
RWStructuredBuffer<exposure_state_sb_data> exposure : register(u0);

cbuffer exposure_cb_data : register(b0)
{
	float min_exposure;
	float max_exposure;
	float middle_gray;
	float adaptation_rate;
	uint filter_low;
	uint filter_high;
	float log_luminance_min;
	float log_luminance_max;
	float log_luminance_range;
	float3 exposure_cb_data_padding;
}

groupshared float gs_accumulation[256];
groupshared uint gs_pixel_count = 0;

[numthreads(256, 1, 1)]
void main(uint group_index : SV_GroupIndex)
{
	// #luma_histogram
	// log luminance histogram has 256 bins. each bin has a uint (4 bytes) sample count
		
	float sample_count = 0.f;
	if (group_index >= filter_low && group_index <= filter_high)
	{
		// every 4 bytes has the number of samples for that histogram bin
		sample_count = (float)histogram.Load(group_index * 4);
		InterlockedAdd(gs_pixel_count, sample_count);
	}

	// weight the brighter values higher so dark doesn't dominate
	float weighted_sum = (float)group_index * sample_count;

	[unroll]
	for (uint i = 1; i < 256; i *= 2)
	{
		gs_accumulation[group_index] = weighted_sum;				// Write
		GroupMemoryBarrierWithGroupSync();							// Sync
		weighted_sum += gs_accumulation[(group_index + i) % 256];	// Read
		GroupMemoryBarrierWithGroupSync();							// Sync
	}

	if (group_index == 0)
	{
		if (weighted_sum != 0.f)
		{
			const float log_luminance_scaled_0_to_255_avg = weighted_sum / max(1, gs_pixel_count) - 1.f;
			
			// original encoding of luminance in luma_update_cs.hlsl
			// const float log_luma = saturate((log2(luma) - exposure_log_luminance_min) * exposure_log_luminance_range_rcp); // Rescale to [0.0, 1.0]
			// LumaResult[DTid.xy] = log_luma * 254.0 + 1.0; // Rescale to [1, 255] (0 was already handled as special case due to log(0) being undefined)
			
			// now decode it with an inversion:
			const float log_luminance_avg = log_luminance_scaled_0_to_255_avg / 254.f * log_luminance_range + log_luminance_min;
			const float luminance_avg = exp2(log_luminance_avg);
			
			// determine the necessary scalar to the image’s exposure so that the average luminance level matches the target (middle gray)
			const float exposure_target = middle_gray / luminance_avg;
			exposure[0].exposure = clamp(lerp(exposure[0].exposure, exposure_target, adaptation_rate), min_exposure, max_exposure);
			exposure[0].exposure_rcp = 1.f / exposure[0].exposure;			
		}
	}
}
