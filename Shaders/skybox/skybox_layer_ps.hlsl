#include "skybox_ps_input.hlsli"
#include "../color_utility.hlsli"
#include "../post_process/exposure_state_sb_data.hlsli"
#include "../external/tone_mapping_utility.hlsli"

TextureCube texture_0 : register(t0);
StructuredBuffer<exposure_state_sb_data> exposure : register(t1);

SamplerState linear_wrap_sampler : register(s0);

struct skybox_ps_output
{
	float4 scene_color : SV_TARGET0;
};

skybox_ps_output main(skybox_ps_input input)
{
	skybox_ps_output output;

	output.scene_color = srgb_to_linear(texture_0.Sample(linear_wrap_sampler, input.position_w));

	return output;
}
