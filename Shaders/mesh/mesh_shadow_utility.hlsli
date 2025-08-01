// === SHADOW MAP SETTINGS ===
static const uint shadow_map_column_count = 2;
static const uint shadow_map_row_count = 2;
static const float shadow_map_column_count_rcp = 1.f / shadow_map_column_count;
static const float shadow_map_row_count_rcp = 1.f / shadow_map_row_count;
static const uint shadow_map_count = shadow_map_column_count * shadow_map_row_count;

// === CASCADE BLENDING + FADE ===
static const float cascade_blend_start_threshold = 0.9f; // start blending to next cascade
static const float cascade_fade_start = 3000.0f;
static const float cascade_fade_end = 7500.0f;
static const float cascade_fade_range = cascade_fade_end - cascade_fade_start;

// === PCF CONFIG (based on distance to camera) ===
// [BJJ] always sample 5x5
//static const float pcf_level0_max_distance = 500.f;
//static const float pcf_level1_max_distance = 600.f;
static const int pcf_kernel_level0 = 2; // closest, softest shadows
//static const int pcf_kernel_level1 = 1; // mid range
//static const int pcf_kernel_level2 = 0; // furthest, sharpest

cbuffer shadow_vs_cb_data : register(b4)
{
	float4x4 shadow_map_uv_transforms[shadow_map_count];
};

cbuffer shadow_ps_cb_data : register(b5)
{
	float shadow_map_texel_size;
	float shadow_depth_bias;
	float use_pcf_based_shadows;
	float shadow_ps_cb_data_padding;
}

Texture2D shadow_map_texture : register(t11);

// Basic hash for screen-space noise
float2 hash2(float2 p)
{
	p = frac(p * 0.3183099 + float2(0.71, 0.113));
	return frac(float2(23.1406927, 2.6651442) * dot(p, float2(1.0, 57.0)));
}

float3 get_shadow_map_uvz(float4x4 world_transform, float3 position, float3 normal, int map_index)
{
	float shadow_normal_bias = 10.0f;
	float4 biased_position = float4(position + normal * shadow_normal_bias, 1.0f);
	return mul(biased_position, mul(world_transform, shadow_map_uv_transforms[map_index])).xyz;
}

// === PCF Shadow Sampling ===
float get_shadow_term(float3 uvz, int kernel_size)
{
	float shadow_term = 0.0f;
	const float total_weight = (1 + (kernel_size * 2.0f)) * (1 + (kernel_size * 2.0f));

	static const float2 rotation = normalize(float2(0.7071f, 0.7071f));
	static const float2x2 rotation_matrix = float2x2(rotation.x, -rotation.y, rotation.y, rotation.x);

	for (int i = -kernel_size; i <= kernel_size; ++i)
	{
		for (int j = -kernel_size; j <= kernel_size; ++j)
		{
			const float2 offset = (use_pcf_based_shadows <= 0.0f)
				? float2(i, j) * shadow_map_texel_size
				: mul(float2(i, j), rotation_matrix) * shadow_map_texel_size;

			const float2 sample_uv = uvz.xy + offset;
			const float sample_depth = shadow_map_texture.SampleLevel(mesh_point_clamp_sampler, sample_uv, 0).r;

			const float lit = (uvz.z > (sample_depth - shadow_depth_bias)) ? 1.0f : 0.0f;
			shadow_term += lit;
		}
	}

	return shadow_term / total_weight;
}

// === Cascade Shadow Term Calculation ===
float get_shadow_scalar(float3 shadow_map_uvz[shadow_map_count], float3 world_position, float3 camera_position)
{
	float shadow_scalar = 1.0f;

	float distance_to_camera = 0.0f;
	float shadow_fade = 0.0f;

	if (use_pcf_based_shadows > 0.0f)
	{
		distance_to_camera = length(world_position - camera_position);
		shadow_fade = saturate((cascade_fade_end - distance_to_camera) / cascade_fade_range);

		if (shadow_fade <= 0.0f)
			return shadow_scalar;
	}

	for (uint cascade_index = 0; cascade_index < shadow_map_count; ++cascade_index)
	{
		const uint row = cascade_index / shadow_map_column_count;
		const uint column = cascade_index % shadow_map_column_count;

		const float left = column * shadow_map_column_count_rcp;
		const float right = left + shadow_map_column_count_rcp;
		const float bottom = row * shadow_map_row_count_rcp;
		const float top = bottom + shadow_map_row_count_rcp;

		const float3 uvz = shadow_map_uvz[cascade_index];

		if (uvz.x >= left && uvz.x <= right && uvz.y >= bottom && uvz.y <= top)
		{
			// [BJJ] always use 5x5 pcf soft shadows
			const int kernel_size = pcf_kernel_level0;

//			int kernel_size = 0;
//			if (distance_to_camera < pcf_level0_max_distance)
//				kernel_size = pcf_kernel_level0;
//			else if (distance_to_camera < pcf_level1_max_distance)
//				kernel_size = pcf_kernel_level1;
//			else
//				kernel_size = pcf_kernel_level2;

			shadow_scalar = get_shadow_term(uvz, kernel_size);

			if (cascade_index < (shadow_map_count - 1))
			{
				const float dist_to_edge = min(right - uvz.x, top - uvz.y);
				const float3 next_uvz = shadow_map_uvz[cascade_index + 1];
				const float next_shadow_scalar = get_shadow_term(next_uvz, kernel_size);
				const float t = max(1.0f - dist_to_edge - cascade_blend_start_threshold, 0.0f) / (1.0f - cascade_blend_start_threshold);
				shadow_scalar = lerp(shadow_scalar, next_shadow_scalar, t);
			}

			if (use_pcf_based_shadows > 0.0f)
				break;
			else
				return shadow_scalar;
		}
	}

	return (use_pcf_based_shadows > 0.0f) ? lerp(1.0f, shadow_scalar, shadow_fade) : 1.0f;
}
