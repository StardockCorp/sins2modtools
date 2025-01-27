#include "starfield_ps_input.hlsli"
#include "../color_utility.hlsli"
#include "../post_process/exposure_state_sb_data.hlsli"
#include "../external/tone_mapping_utility.hlsli"
#include "../math_utility.hlsli"

Texture2D texture_0 : register(t0);
StructuredBuffer<exposure_state_sb_data> exposure : register(t1);

SamplerState linear_wrap_sampler : register(s0);

cbuffer starfield_layer_cb_data : register(b1)
{
	float zoom;
	float3 starfield_layer_cb_data_padding;
}

struct skybox_ps_output
{
	float4 scene_color : SV_TARGET0;
};

skybox_ps_output main(starfield_ps_input input)
{
	skybox_ps_output output;

	output.scene_color = srgb_to_linear(texture_0.Sample(linear_wrap_sampler, sample_cube(input.position_w) * zoom));
	
	// craig wants it exactly as painted. need to invert tone mapping.
	output.scene_color.rgb = ITM_Stanard_Fixed(output.scene_color.rgb);
	
	// craig wants it exactly as painted. need to invert exposure.
	output.scene_color.rgb *= exposure[0].exposure_rcp; 

	return output;
}
