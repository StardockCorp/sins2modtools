#include "mesh_samplers.hlsli"
#include "mesh_skybox_input.hlsli"
#include "../color_utility.hlsli"

Texture2D base_color_texture : register(t0);
Texture2D occlusion_roughness_metallic_texture : register(t1);
Texture2D normal_texture : register(t2);

struct ps_output
{
	float4 scene_color : SV_TARGET0;
	float4 emissive_color : SV_TARGET1;
};

ps_output main(mesh_skybox_ps_input input)
{
	ps_output output;
	output.scene_color = srgb_to_linear(base_color_texture.Sample(mesh_anisotropic_wrap_sampler, input.texcoord0));
	output.emissive_color = output.scene_color;
	return output;
}
