#include "starfield_ps_input.hlsli"
#include "skybox_scene_cb_data.hlsli"

struct starfield_vs_input
{
	uint vertex_id : SV_VertexID;
};

starfield_ps_input main(starfield_vs_input input)
{
	starfield_ps_input output;

	// Cubemap skyboxes: adapted from https://research.ncl.ac.uk/game/mastersdegree/graphicsforgames/cubemapping/Tutorial%2013%20-%20Cube%20Mapping.pdf

	// see present_screen_quad_vs.hlsl to explain texcoord0 and position_h
	const float2 tex_coord = float2((input.vertex_id << 1) & 2, input.vertex_id & 2);
	output.position_h = float4(tex_coord.x * 2 - 1, -tex_coord.y * 2 + 1, 0, 1);

	float4 position_v = mul(output.position_h, projection_inverse);
	position_v.xyz /= position_v.w;	

	output.position_w = mul(position_v, view_inverse).xyz;

	return output;
}