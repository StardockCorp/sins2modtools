// Inspired by : https://github.com/microsoft/DirectXTK/blob/master/Src/Shaders/PostProcess.fx

// which falls under this license:

// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.
//
// http://go.microsoft.com/fwlink/?LinkId=248929

struct ps_input
{
	float4 position : SV_Position;
	float2 texcoord0 : TEXCOORD0;
};

cbuffer outline_cb_data : register(b0)
{
	float2 scene_texel_size;
	float outline_thickness;
	float outline_edge_threshold;
};

Texture2D outline_ids_texture : register(t0);
Texture2D outline_colors_texture : register(t1);
SamplerState sampler0 : register(s0);

float4 main(ps_input input) : SV_Target0
{
	float fill_value = outline_ids_texture.Sample(sampler0, input.texcoord0).r;

	float2 offset_scalars = {scene_texel_size.x * outline_thickness, scene_texel_size.y * outline_thickness};

	float2 offsets[8] = {
		float2(-1, -1),
		float2(-1, 0),
		float2(-1, 1),
		float2(0, -1),
		float2(0, 1),
		float2(1, -1),
		float2(1, 0),
		float2(1, 1)
	};

	//easier to iterate on this by using a loop.
	//if profiling shows its costly, easy enough to unroll and hand code each step.
	float avg_value = 0;
	for (int i = 0; i < 8; i++)
	{
		avg_value += outline_ids_texture.Sample(sampler0, input.texcoord0 + offsets[i] * offset_scalars).r;
	}
	avg_value /= 8;

	float4 outline_color = float4(0.f, 0.f, 0.f, 0.f);

	if (avg_value != 0)
	{
		outline_color = outline_colors_texture.Sample(sampler0, input.texcoord0);

		//only render an edge (outline) if the the current pixel is sufficiently distinct from the avg.
		//todo - should be able to remove the branching here with math...
		if ((fill_value - avg_value) < outline_edge_threshold)
		{
			outline_color.a = 0.f;
		}
	}

	return outline_color;
}
