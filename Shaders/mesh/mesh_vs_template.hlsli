#include "mesh_samplers.hlsli"

#ifdef ENABLE_SHADOWS
#include "mesh_shadow_utility.hlsli"
#endif

#include "mesh_ps_input.hlsli"
#include "mesh_scene_cb_data.hlsli"
#include "mesh_instance_cb_data.hlsli"

struct mesh_vs_input
{
	float3 position : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 texcoord0 : TEXCOORD0;
	float2 texcoord1 : TEXCOORD1;

	#if IS_INSTANCED
	float4x4 world_transform : WORLD_TRANSFORM;
	#endif
};

mesh_ps_input main(mesh_vs_input input)
{
	mesh_ps_input output;

	#if IS_INSTANCED
	float4x4 this_world = input.world_transform;
	float4x4 this_world_view_projection = mul(input.world_transform, view_projection);
	float4x4 this_world_view = mul(input.world_transform, view);
	#else   
	float4x4 this_world = world;
	float4x4 this_world_view_projection = world_view_projection;
	float4x4 this_world_view = world_view;
	#endif
	
	#ifdef ENABLE_OUTLINE_DISTANCE_SCALING
	const float3 input_position = input.position * outline_distance_scalar;
	#else 
	const float3 input_position = input.position;
	#endif

	output.position_h = mul(float4(input_position, 1.0f), this_world_view_projection);
	output.position_v = mul(float4(input_position, 1.0f), this_world_view).xyz;
	output.position_w = mul(float4(input_position, 1.0f), this_world).xyz;
	output.position_l = input_position.xyz;
	output.texcoord0 = input.texcoord0;
	output.texcoord1 = input.texcoord1;
	output.normal_w = mul(input.normal, (float3x3)this_world);
	output.tangent_w = mul(input.tangent.xyz, (float3x3)this_world);
	output.fsign = input.tangent.w; // #mikktspace_decoding

#ifdef ENABLE_SHADOWS
	[unroll]
	for (uint i = 0; i < shadow_map_count; ++i)
	{		
		output.shadow_map_uvz[i] = get_shadow_map_uvz(this_world, input.position, input.normal, i);
	}
#endif

	return output;
}
