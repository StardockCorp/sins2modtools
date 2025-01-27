static const uint shadow_map_column_count = 2; // todo: #shadows: make sure this lines up with the cpu side
static const uint shadow_map_row_count = 2; // todo: #shadows: make sure this lines up with the cpu side
static const float shadow_map_column_count_rcp = 1.f / shadow_map_column_count;
static const float shadow_map_row_count_rcp = 1.f / shadow_map_row_count;
static const uint shadow_map_count = shadow_map_column_count * shadow_map_row_count;
static const float cascade_blend_start_threshold = .9f;

cbuffer shadow_vs_cb_data : register(b4)
{
	float4x4 shadow_map_uv_transforms[shadow_map_count];
	
	// #fix_shadow_normal_biases
	//float shadow_normal_biases[shadow_map_count];
	//float3 shadow_vs_cb_data_padding[3];
};

cbuffer shadow_ps_cb_data : register(b5)
{
	float shadow_map_texel_size;
	float shadow_depth_bias;	
	float shadow_ps_cb_data_padding;	
};

Texture2D shadow_map_texture: register(t11);

float3 get_shadow_map_uvz(float4x4 world_transform, float3 position, float3 normal, int map_index)
{
	// result will encode as follows:
	// xy = tex_coord
	// z = depth
	
	// #fix_shadow_normal_biases
	const float shadow_normal_biases_temp[4] = { 10.f, 10.f, 5.f, 0.f };
	
	const float4 biased_position = float4(position + normal * shadow_normal_biases_temp[map_index], 1.f);
	
	// todo: #shadows: profile if premultiplying this_world * shadow_map_uv_transforms on the cpu is better or not		
	return mul(biased_position, mul(world_transform, shadow_map_uv_transforms[map_index])).xyz;
}

float get_shadow_term(float3 uvz)
{
	float shadow_term = 0.f;

	for (int i = -2; i <= 2; ++i)
	{
		for (int j = -2; j <= 2; ++j)
		{
			const float2 offset_tex_coord = uvz.xy + float2(i * shadow_map_texel_size, j * shadow_map_texel_size);
			const float depth = shadow_map_texture.SampleLevel(mesh_point_clamp_sampler, offset_tex_coord, 0).r;

			// z check is backwards because #reverse-depth-buffer (swapping near_z and far_z). see https://docs.microsoft.com/en-us/windows/win32/api/directxmath/nf-directxmath-xmmatrixperspectivefovlh			
			shadow_term += (uvz.z > (depth - shadow_depth_bias)) ? 1.f : 0.f;			
		}
	}

	shadow_term /= 25.0f;

	return shadow_term;
}

float get_shadow_scalar(float3 shadow_map_uvz[shadow_map_count])
{
	for (uint cascade_index = 0; cascade_index < shadow_map_count; ++cascade_index)
	{
		const uint row = cascade_index / shadow_map_column_count;
		const uint column = cascade_index % shadow_map_column_count;

		const float left = column * shadow_map_column_count_rcp;
		const float right = left + shadow_map_column_count_rcp;
		const float bottom = row * shadow_map_row_count_rcp;
		const float top = bottom + shadow_map_row_count_rcp;

		const float3 uvz = shadow_map_uvz[cascade_index];

		// check if this uv fits in one of the cascade boxes
		if (uvz.x >= left &&
			uvz.x <= right &&
			uvz.y >= bottom &&
			uvz.y <= top)
		{
			// todo: #shadows: add a new debug shader or shader define to control rendering cascades
			//float shadow_scalar = cascade_index; //use this instead when debugging cascades
			float shadow_scalar = get_shadow_term(uvz);
			if (cascade_index != shadow_map_count - 1) // can't blend if there are no more
			{
				// if we are super close to the edge of a cascade, start blending to it so we don't get an abrupt transition.
				const float dist_to_edge = min(right - uvz.x, top - uvz.y);			
				const float next_shadow_scalar = get_shadow_term(shadow_map_uvz[cascade_index + 1]);
				const float t = max(1.f - dist_to_edge - cascade_blend_start_threshold, 0.f) / (1.f - cascade_blend_start_threshold);
				shadow_scalar = lerp(shadow_scalar, next_shadow_scalar, t);
			}
			return shadow_scalar;
		}
	}

	// no cascade found so just return no shadow
	return 1.f;
}