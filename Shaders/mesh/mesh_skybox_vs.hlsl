#include "mesh_skybox_input.hlsli"
#include "mesh_scene_cb_data.hlsli"
#include "mesh_instance_cb_data.hlsli"

mesh_skybox_ps_input main(mesh_skybox_vs_input input)
{
	mesh_skybox_ps_input output;
	output.position_h = mul(float4(input.position, 1.0f), world_view_projection);
	output.position_h.z = output.position_h.w; // force z to be 1 in depth test
	output.texcoord0 = input.texcoord0;
	return output;
}
