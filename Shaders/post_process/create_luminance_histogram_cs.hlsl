// #luma_buffer
Texture2D<uint> luma_buffer : register(t0);
RWByteAddressBuffer histogram_buffer : register(u0);

groupshared uint g_shared_histogram[256]; 

[numthreads( 16, 16, 1 )] 
void main(uint group_index : SV_GroupIndex, uint3 global_thread_id : SV_DispatchThreadID )
{
	// #luma_histogram

	// Ironclad note: adapted from:	
	// http://www.alextardif.com/HistogramLuminance.html 
	// https://bruop.github.io/exposure/
	// https://github.com/microsoft/DirectX-Graphics-Samples/blob/master/MiniEngine/Core/Shaders/GenerateHistogramCS.hlsl
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
		
    g_shared_histogram[group_index] = 0;

	// wait until every histogram bin is set to 0 before we start adding all the bin counts.
    GroupMemoryBarrierWithGroupSync();

	// every global_thread_id maps to one specific pixel of the luma_buffer
	const uint log_luminance_scaled_0_to_255 = luma_buffer[global_thread_id.xy];
    InterlockedAdd(g_shared_histogram[log_luminance_scaled_0_to_255], 1);

	// wait for all histogram bin accumulations to complete 
    GroupMemoryBarrierWithGroupSync();

	// assign the final counts
	// histogram_buffer has 256 bins. each bin has a uint (4 bytes) sample count.
	// best way to confirm its accuracy is to use pix. in pix don't forget to change xint to unit.
    histogram_buffer.InterlockedAdd(group_index * 4, g_shared_histogram[group_index]);
}