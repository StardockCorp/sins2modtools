#include "mesh_shadow_blocker_ps_input.hlsli"

float4 main(mesh_shadow_blocker_ps_input input) : SV_TARGET
{
	// x stores the depth value. 
	// See mesh_shadow_blocker_vs_template #shadow_blocker_depth for an explanation of how its encoded and why we don't divide by W.
	return input.depth.x;
}