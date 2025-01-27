#include "mesh/mesh_light_sb_data.hlsli"
#include "math_utility.hlsli"
#include "froxel_sb_data.hlsli"
#include "light_cluster_sb_data.hlsli"
#include "light_index_sb_data.hlsli"

cbuffer build_lighting_cb_data : register(b0)
{
	float4x4 camera_view;
	float4x4 camera_view_projection;
	uint light_count;
	float min_light_width;
	float2 screen_resolution;
};

// input buffers
StructuredBuffer<froxel_sb_data> froxels : register(t0);
StructuredBuffer<mesh_light_sb_data> lights : register(t1);

// output buffers
RWStructuredBuffer<light_cluster_sb_data> light_clusters : register(u0);
RWStructuredBuffer<light_index_sb_data> light_indices : register(u1);
RWStructuredBuffer<light_index_sb_data> culled_lights : register(u2);

// we are doing 6 slices of 16x9x4. Dispatch is (1,1,6), so total is the requisite froxel count of 16x9x24. 
#define x_thread_count 16
#define y_thread_count 9
#define z_thread_count 4

// this must line up with d3d11_mesh_renderer::light_count_per_froxel
#define max_lights_per_cluster 256

static const uint thread_count = x_thread_count * y_thread_count * z_thread_count;

bool does_light_point_intersect_cluster(uint light_index, uint cluster_index)
{
	const float light_radius = lights[light_index].attenuation_radius;	
	const float width_in_pixels = 2.f * get_screen_space_radius_in_pixels(lights[light_index].position, light_radius, camera_view_projection, screen_resolution);

	if(width_in_pixels < min_light_width)
	{
		return false;
	}
	else
	{
		const float3 position_in_view_space = mul(float4(lights[light_index].position, 1.f), camera_view).xyz;		
		const froxel_sb_data f = froxels[cluster_index];
		float dist_squared = 0.0;

		for (int i = 0; i < 3; ++i)
		{
			const float p = position_in_view_space[i];

			if (p < f.min_extent[i])
			{
				dist_squared += (f.min_extent[i] - p) * (f.min_extent[i] - p);
			}

			if (p > f.max_extent[i])
			{
				dist_squared += (p - f.max_extent[i]) * (p - f.max_extent[i]);
			}
		}	
		return dist_squared <= (light_radius * light_radius);
	}
}

bool does_light_cone_intersect_cluster(uint light_index, uint cluster_index)
{
	const float cone_radius = lights[light_index].attenuation_radius;	
	const float width_in_pixels = 2.f * get_screen_space_radius_in_pixels(lights[light_index].position, cone_radius, camera_view_projection, screen_resolution);

	if(width_in_pixels < min_light_width)
	{
		return false;
	}
	else
	{
		// adapted from: 
		// https://www.cbloom.com/3d/techdocs/culling.txt ->
		// https://bartwronski.com/2017/04/13/cull-that-cone/ ->
		// https://simoncoenen.com/blog/programming/graphics/SpotlightCulling

		const froxel_sb_data f = froxels[cluster_index];

		const float cluster_radius = f.radius;		
		const float3 cone_direction = mul(float4(lights[light_index].direction, 1.f), camera_view).xyz;
		const float3 cone_position = mul(float4(lights[light_index].position, 1.f), camera_view).xyz;
		const float3 cluster_position = f.center;
		const float3 v_to_cluster = cluster_position - cone_position;
		const float projection_length = dot(v_to_cluster, cone_direction);

		// check if cluster is too far in front of cone
		if (projection_length > (cluster_radius + cone_radius))
		{
			return false;
		}
		// check if cluster is too far behind the cone
		else if (projection_length < -cluster_radius)
		{
			return false;
		}
		// cluster must lie between the min/max extents of cone, so we check if it lies within the cone's angle.
		else
		{
			const float dist_to_cluster_2 = dot(v_to_cluster, v_to_cluster);
			const float project_length_2 = projection_length * projection_length;
			const float dist_to_axis = sqrt(dist_to_cluster_2 - project_length_2);
			const float cone_angle = lights[light_index].angle;

			// note this closest point on the cone's surface is only valid if the cluster lies within the near/far extents of the cone
			const float dist_closest_point = cos(cone_angle) * dist_to_axis - sin(cone_angle) * projection_length;

			return dist_closest_point <= cluster_radius;
		}
	}
}

bool does_light_line_intersect_cluster(uint light_index, uint cluster_index)
{	
	// really large overestimation but fast and good enough
	const float line_radius = lights[light_index].length / 2.f;	
	const float3 line_center = lights[light_index].position + lights[light_index].direction * line_radius;
	const float width_in_pixels = 2.f * get_screen_space_radius_in_pixels(line_center, line_radius, camera_view_projection, screen_resolution);

	if(width_in_pixels < min_light_width)
	{
		return false;
	}
	else
	{
		const float3 light_begin = mul(float4(lights[light_index].position, 1.f), camera_view).xyz;
		const float3 light_direction = mul(float4(lights[light_index].direction, 1.f), camera_view).xyz;
		const float3 light_end = light_begin + light_direction * lights[light_index].length;

		const float d_to_line = get_distance_to_line(light_begin, light_end, froxels[cluster_index].center);
		return d_to_line <= lights[light_index].attenuation_radius;
	}
}

bool does_light_intersect_cluster(uint light_index, uint cluster_index)
{
	bool intersect = false;

	if (lights[light_index].type == MESH_LIGHT_TYPE_POINT_FINITE)
	{
		intersect = does_light_point_intersect_cluster(light_index, cluster_index);
	}
	else if (lights[light_index].type == MESH_LIGHT_TYPE_POINT_INFINITE)
	{
		intersect = true;
	}
	else if (lights[light_index].type == MESH_LIGHT_TYPE_CONE)
	{
		intersect = does_light_cone_intersect_cluster(light_index, cluster_index);
	}
	else if (lights[light_index].type == MESH_LIGHT_TYPE_LINE)
	{
		intersect = does_light_line_intersect_cluster(light_index, cluster_index);
	}

	return intersect;
}

[numthreads(x_thread_count, y_thread_count, z_thread_count)]
void main(uint3 group_id : SV_GroupID, uint group_index : SV_GroupIndex)
{
	const uint cluster_index = group_index + thread_count * group_id.z;
	const uint light_clusters_offset = cluster_index * max_lights_per_cluster;

	uint visible_light_count = 0;

	for (uint light_index = 0; light_index < light_count; ++light_index)
	{
		if (visible_light_count >= max_lights_per_cluster)
		{
			culled_lights[light_index].index = 1; // set "culled" state to true
		}
		else if (does_light_intersect_cluster(light_index, cluster_index))
		{
			light_indices[light_clusters_offset + visible_light_count].index = light_index;
			visible_light_count++;						
		}
	}

	light_clusters[cluster_index].offset = light_clusters_offset;
	light_clusters[cluster_index].count = visible_light_count;
}