#include "mesh_shadow_blocker_ps_input.hlsli"
#include "mesh_shadow_blocker_scene_cb_data.hlsli"

cbuffer mesh_shadow_blocker_instance_cb_data : register(b1)
{
	float4x4 world_view_projection;
}

struct mesh_vs_input
{
	float3 position : POSITION;	

	#if IS_INSTANCED
	float4x4 world_transform : WORLD_TRANSFORM;
	#endif
};

mesh_shadow_blocker_ps_input main(mesh_vs_input input)
{
	mesh_shadow_blocker_ps_input output;

	#if IS_INSTANCED	
	float4x4 this_world_view_projection = mul(input.world_transform, view_projection);
	#else   	
	float4x4 this_world_view_projection = world_view_projection;
	#endif

	// Reminder: Technically, as this is still the vertex shader, this is actually ClipSpace. 
	// It won't become screenspace until the perspective divide (by W) occurs automatically between the vertexshader and pixelshader. Hence the float4 used to store W.
	output.position_h = mul(float4(input.position, 1.0f), this_world_view_projection);

	// #shadow_blocker_depth
	// This is the depth in clipspace. Because this isn't a POSITION, directx won't auto perspective divide (by W) to get the screenspace depth. 
	// Normally we'd have to do it manually in the pixel shader:
	// 1. store z and w like this in the vertex shader: output.depth.xy = output.position_h.zw;
	// 2. work out depth in the pixel shader like this: depth = input.depth.x / input.depth.y;
	// However, we are using an orthographic projection where W is always 1 so no need to store it or do the divide.
	output.depth.x = output.position_h.z;
	return output;
}
