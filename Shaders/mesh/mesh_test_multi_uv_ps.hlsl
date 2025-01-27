#include "mesh_scene_cb_data.hlsli"
#include "mesh_samplers.hlsli"
#include "mesh_ps_input.hlsli"
#include "../color_utility.hlsli"

Texture2D base_color_texture : register(t0);

struct ps_output
{
	float4 scene_color : SV_TARGET0;
	float4 emissive_color : SV_TARGET1;
};

ps_output main(mesh_ps_input input)
{
	float4 base_color = srgb_to_linear(base_color_texture.Sample(mesh_anisotropic_wrap_sampler, input.texcoord0));
	
	ps_output output;
	output.scene_color = float4(base_color.rgb, base_color.a) / 2.f;
	output.emissive_color = 0.f;

	return output;
}