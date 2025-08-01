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
	
	// Standard outputs
	output.position_h = mul(float4(input_position, 1.0f), this_world_view_projection);
	output.position_v = mul(float4(input_position, 1.0f), this_world_view).xyz;
	output.position_w = mul(float4(input_position, 1.0f), this_world).xyz;
	output.position_l = input_position.xyz;
	output.texcoord0 = input.texcoord0;
	output.texcoord1 = input.texcoord1;
	output.normal_w = normalize(mul(input.normal, (float3x3)this_world));
	output.tangent_w = normalize(mul(input.tangent.xyz, (float3x3)this_world));
	output.fsign = input.tangent.w; // #mikktspace_decoding

	// === Compute bitangent and TBN matrix ===
	float3 bitangent_w = normalize(cross(output.normal_w, output.tangent_w) * output.fsign);
	float3x3 TBN = float3x3(output.tangent_w, bitangent_w, output.normal_w);

	// === View direction in world and tangent space ===
	float3 view_dir_world = normalize(camera_position.xyz - output.position_w);
	output.view_dir_tangent = mul(view_dir_world, transpose(TBN)); // to tangent space

	#ifdef ENABLE_SHADOWS
	[unroll]
	for (uint i = 0; i < shadow_map_count; ++i)
	{		
		output.shadow_map_uvz[i] = get_shadow_map_uvz(this_world, input.position, input.normal, i);
	}
	#endif

	return output;
}
