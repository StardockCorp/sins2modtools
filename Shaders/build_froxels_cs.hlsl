#include "froxel_sb_data.hlsli"

cbuffer build_froxels_cb_data : register(b0)
{
	float4x4 camera_inverse_projection;
	float camera_near_z;
	float camera_far_z;	
	int2 camera_viewport_size;
	uint3 froxel_counts;
	uint froxel_size_in_pixels;
};

RWStructuredBuffer<froxel_sb_data> froxel_buffer : register(u0);

float4 convert_clip_to_view_space(float4 clip_space_position)
{	
	float4 view_space_position = mul(camera_inverse_projection, clip_space_position);
	view_space_position /= view_space_position.w;	
	return view_space_position;
}

float4 convert_screen_to_view_space(float4 screen_space_position)
{
	float2 normalized_position = screen_space_position.xy / camera_viewport_size; // normalize position to 0..1
	float4 clip_space_position = float4(float2(normalized_position.x, 1.f - normalized_position.y) * 2.0 - 1.0, screen_space_position.z, screen_space_position.w); // convert to clip space -1..1
	return convert_clip_to_view_space(clip_space_position);
}

float3 get_line_plane_intersection(float3 dst, float plane_distance)
{
	// the line is really (dst - src) but src is 0,0,0 because camera is at origin in view space
	const float3 normal = float3(0.0, 0.0, 1.0); // plane is orthogonal to the view direction in view space
	const float t = plane_distance / dot(normal, dst); // would normally be (plane_distance  - dot(normal, src)) / (dot(normal, (dst - src))
	const float3 intersection_position = t * dst; // would normally be src + t * (dst- src)

	return intersection_position;
}

[numthreads(1, 1, 1)]
void main(uint3 group_id : SV_GroupID)
{
	const float4 min_position_in_screen_space = float4(float2(group_id.x, group_id.y) * froxel_size_in_pixels, -1.f, 1.f);
	const float4 max_position_in_screen_space = float4(float2(group_id.x + 1, group_id.y + 1) * froxel_size_in_pixels, -1.f, 1.f);

	const float3 min_position_in_view_space = convert_screen_to_view_space(min_position_in_screen_space).xyz;
	const float3 max_position_in_view_space = convert_screen_to_view_space(max_position_in_screen_space).xyz;

	// Doom exp formula.
	const float z_ratio = abs(camera_far_z / camera_near_z); // pow(f, e) will not work for negative f, use abs(f) or conditionally handle negative values if you expect them
	const float cluster_near_z = camera_near_z * pow(z_ratio, group_id.z / float(froxel_counts.z));
	const float cluster_far_z = camera_near_z * pow(z_ratio, (group_id.z + 1) / float(froxel_counts.z));

	float3 min_position_near = get_line_plane_intersection(min_position_in_view_space, cluster_near_z);
	float3 min_position_far = get_line_plane_intersection(min_position_in_view_space, cluster_far_z);
	float3 max_position_near = get_line_plane_intersection(max_position_in_view_space, cluster_near_z);
	float3 max_position_far = get_line_plane_intersection(max_position_in_view_space, cluster_far_z);

	const uint cluster_index = group_id.x + (group_id.y * froxel_counts.x) + (group_id.z * froxel_counts.x * froxel_counts.y);

	min_position_near.z = cluster_near_z;
	max_position_near.z = cluster_far_z;

	froxel_buffer[cluster_index].min_extent = min(min(min_position_near, min_position_far),min(max_position_near, max_position_far));
	froxel_buffer[cluster_index].max_extent = max(max(min_position_near, min_position_far),max(max_position_near, max_position_far));
	froxel_buffer[cluster_index].center = (froxel_buffer[cluster_index].min_extent + froxel_buffer[cluster_index].max_extent) / 2.f;
	const float3 r = froxel_buffer[cluster_index].max_extent - froxel_buffer[cluster_index].center;
	froxel_buffer[cluster_index].radius = max(max(r.x, r.y), r.z);
}