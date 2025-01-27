#include "mesh_scene_cb_data.hlsli"
#include "mesh_samplers.hlsli"
#include "mesh_ps_input.hlsli"
#include "mesh_pbr_utility.hlsli"
#include "../color_utility.hlsli"

Texture2D base_color_texture : register(t0);
Texture2D mask_texture : register(t3);

struct ps_output
{
	float4 scene_color : SV_TARGET0;
	float4 emissive_color : SV_TARGET1;
};

ps_output main(mesh_ps_input input)
{
	float4 base_color = srgb_to_linear(base_color_texture.Sample(mesh_anisotropic_wrap_sampler, input.texcoord0));
	const float4 mask_sample = mask_texture.Sample(mesh_anisotropic_wrap_sampler, input.texcoord0);

	const float3 primary_color = float3(1.f, 0.f, 0.f);
	const float3 secondary_color = float3(0.f, 1.f, 0.f);
	const float3 trinary_color = float3(0.f, 0.f, 1.f);

	base_color.rgb = lerp(base_color.rgb, BlendMode_Overlay(base_color.rgb, primary_color), mask_sample.r);
	base_color.rgb = lerp(base_color.rgb, BlendMode_Overlay(base_color.rgb, secondary_color), mask_sample.g);
	base_color.rgb = lerp(base_color.rgb, BlendMode_Overlay(base_color.rgb, trinary_color), mask_sample.b);
	
	ps_output output;
	output.scene_color = base_color;	
	output.emissive_color = 0.f;
	
	return output;
}