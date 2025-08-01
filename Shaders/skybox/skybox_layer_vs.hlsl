#include "skybox_ps_input.hlsli"
#include "skybox_scene_cb_data.hlsli"

#include "../math_utility.hlsli"

cbuffer skybox_layer_cb_data : register(b1)
{
	float4x4 rotation;
}

struct skybox_vs_input
{
	uint vertex_id : SV_VertexID;
};

skybox_ps_input main(skybox_vs_input input)
{
	skybox_ps_input output;

	// Cubemap skyboxes: adapted from https://research.ncl.ac.uk/game/mastersdegree/graphicsforgames/cubemapping/Tutorial%2013%20-%20Cube%20Mapping.pdf

	// see present_screen_quad_vs.hlsl to explain texcoord0 and position_h
	const float2 tex_coord = float2((input.vertex_id << 1) & 2, input.vertex_id & 2);
	output.position_h = float4(tex_coord.x * 2 - 1, -tex_coord.y * 2 + 1, 0, 1);

	float4 position_v = mul(output.position_h, projection_inverse);
	position_v.xyz /= position_v.w;

	//output.position_w = mul(get_rotation(rotation), mul(position_v, view_inverse).xyz);
	output.position_w =  mul(position_v, view_inverse).xyz;

	return output;
}
