#include "skybox_background_ps_input.hlsli"
#include "../color_utility.hlsli"
#include "../post_process/exposure_state_sb_data.hlsli"
#include "../external/tone_mapping_utility.hlsli"

cbuffer skybox_background_cb_data : register(b1)
{	
	float4 background_color;		
}

StructuredBuffer<exposure_state_sb_data> exposure : register(t1);

struct skybox_ps_output
{
	float4 scene_color : SV_TARGET0;
};

skybox_ps_output main(skybox_background_ps_input input)
{
	skybox_ps_output output;
	
	// background_color submitted from cpu to gpu in linear space. no need to convert to linear
	output.scene_color = background_color;	

	return output;
}
