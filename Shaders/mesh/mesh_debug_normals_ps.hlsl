#include "mesh_ps_input.hlsli"
#include "mesh_samplers.hlsli"
#include "mesh_pbr_utility.hlsli"
#include "../color_utility.hlsli"

struct ps_output
{
	float4 scene_color : SV_TARGET0;	
};

Texture2D normal_texture : register(t2);

ps_output main(mesh_ps_input input)
{
	// #sins2_normals_and_tangents
	const float2 normal_t_sample = normal_texture.Sample(mesh_anisotropic_clamp_sampler, input.texcoord0).xy;	
	
	ps_output output;
	output.scene_color = get_normal_t_debug(normal_t_sample);
	return output;
}
