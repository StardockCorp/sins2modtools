#include "prim3d_ps_input.hlsli"
#include "prim3d_scene_cb_data.hlsli"
#include "../color_utility.hlsli"

// declared here to simplify definition of prim3d_basic_add_textures_xxx_ps and prim3d_normal_mulitply_xxx_ps
#if defined(USE_BASIC_CONSTANTS)
#include "prim3d_basic_cb_data.hlsli"

cbuffer prim3d_basic_cb_data_register_wrapper : register(b1)
{
	prim3d_basic_cb_data basic_constants_0;	
};

Texture2DMS<float> depth_texture : register(t0);
Texture2D base_texture_0 : register(t1);
Texture2D base_texture_1 : register(t2);
Texture2D refraction_texture : register(t6); // to line up with prim3d_uber_base_ps.hlsli
Texture2D refraction_mask_texture : register(t7); // to line up with prim3d_uber_base_ps.hlsli
#endif

SamplerState wrap_sampler : register(s0);
SamplerState clamp_sampler : register(s1);

struct ps_output
{
	float4 scene_color : SV_TARGET0;
	float4 emissive_color : SV_TARGET1;
	float4 refraction_offset : SV_TARGET2;
};

float get_depth_fade(prim3d_ps_input input, float opacity, float fade_distance)
{
	// depthfade/softparticles:
	// adapted from https://developer.download.nvidia.com/SDK/10/direct3d/Source/SoftParticles/doc/SoftParticles_hi.pdf
	// technically, we should sample this multisample texture over all sample_counts and get the best value but not worth it for soft particles. 
	// the results are already fuzzy, getting a more accurate depth value doesn't make much of a difference.
	const float z_ndc = depth_texture.Load(input.position_h.xy, 0).r;
	const float scene_depth = (camera_far_z_times_near_z / (camera_far_z - z_ndc * camera_far_z_minus_near_z));
	const float pixel_depth = input.position_v.z;

	return opacity * saturate((scene_depth - pixel_depth) / max(fade_distance, .0001f));
}

float get_ramped_alpha(float base_alpha, float base_alpha_scalar, float depth_fade, float max_alpha)
{
	// for the original SG alpha ramp model see the following file:
	// file:///../../../../sins2/docs/srgb_linear_fixes.xlsx
	// its been improved to add curvature control, growth_delay control, and max_alpha scaling. 
	// the base max_alpha and steepness were already in the SG model.

	const float delayed_alpha = pow(base_alpha, basic_constants_0.alpha_ramp_growth_delay) * base_alpha_scalar;
	const float alpha_boost = saturate(delayed_alpha * (basic_constants_0.alpha_ramp_curvature * delayed_alpha + basic_constants_0.alpha_ramp_steepness));		
	const float alpha_limit = basic_constants_0.alpha_ramp_max_alpha_scalar * max_alpha;
	return alpha_boost * alpha_limit * depth_fade;
}

ps_output main(prim3d_ps_input input)
{
	ps_output output;

	output.refraction_offset = 0.f;
	
	const float depth_fade = get_depth_fade(input, basic_constants_0.depth_fade_opacity, basic_constants_0.depth_fade_distance);

	#if defined(HAS_EROSION_1X) || defined(HAS_EROSION_2X)
	const float depth_fade_erosion = get_depth_fade(input, erosion_constants_0.erosion_depth_fade_opacity, erosion_constants_0.erosion_depth_fade_distance);
	#endif

#if defined(STAR_CORONA)
	{
		// texcoords are 0..1 - no need for division by z
		const float4 corona = srgb_to_linear(base_texture_0.Sample(wrap_sampler, input.texcoord0.xy));

		// corona animation
		const float cloud_animation_time = animation_speed * time;
		const float2 texcoord0 = noise_0_zoom * input.texcoord0.xy;
		const float noise0 = noise_0_intensity * noise_texture.Sample(wrap_sampler, texcoord0).r;

		const float2 texcoord1 = noise_1_zoom * input.texcoord0.xy - float2(noise0 - cloud_animation_time, 0.f);
		const float noise1 = saturate(noise_1_intensity * noise_texture.Sample(wrap_sampler, texcoord1).r);

		const float3 base_color = (corona.rgb * input.color0.rgb);

		// custom star corona color mutation (animate with noise)
		output.scene_color.rgb = base_color * noise1 + base_color;
				
		const float ramped_alpha = get_ramped_alpha(corona.a, 1.f, depth_fade, input.color0.a);

		// star corona custom alpha mutation (animate with noise)
		output.scene_color.a = ramped_alpha * noise1 + ramped_alpha;
	}
#elif defined(PLANET_CORONA)
	{
		const float3 dir_to_light = normalize(light_position - corona_position);
		const float3 normal = normalize(input.position_w - corona_position);
		const float3 view_dir = normalize(-input.position_w);

		// === PARAMETERS ===
		const float corona_edge_softness       = 3.0f;
		const float corona_tint_focus          = 3.0f;
		const float corona_inner_fade_start    = 0.8f;
		const float corona_inner_fade_end      = 1.0f;
		const float corona_alpha_multiplier    = 1.5f;
		const float noise_contribution         = 0.75f;
		const float scattering_anisotropy      = 0.6f;  // forward scatter
		const float scattering_strength        = 2.f;
		const float3 warm_tint_color           = float3(1.0f, 0.6f, 0.3f);
		const float max_corona_visible_distance = 500000.0f;

		// === Light-side mask
		const float lower = -corona_curvature_bleed_distance;
		const float upper = 0.0f;
		const float d = dot(normal, dir_to_light);
		const float light_side_t = saturate((d - lower) / (upper - lower));

		// === Texture blend
		const float4 s0 = srgb_to_linear(base_texture_0.Sample(wrap_sampler, input.texcoord0.xy));
		const float4 s1 = srgb_to_linear(noise_texture.Sample(wrap_sampler, input.texcoord0.xy));
		const float4 combined = saturate(s0 + s1 * noise_contribution);
		const float3 base_color = combined.rgb * input.color0.rgb;

		// === Warm tint
		const float warm_factor = saturate(dot(normal, dir_to_light));
		float3 tinted_color = lerp(base_color, warm_tint_color, pow(warm_factor, corona_tint_focus));

		// === Henyey-Greenstein phase function (forward scatter)
		const float cos_theta = dot(view_dir, dir_to_light);
		const float g = scattering_anisotropy;
		const float phase = (1.0f - g * g) / pow(max(1.0f + g * g - 2.0f * g * cos_theta, 0.05f), 1.5f);
		tinted_color *= 1.0f + phase * scattering_strength;

		// === Volumetric fade from view alignment (thicker at glancing)
		float view_thickness = pow(1.0f - saturate(dot(normal, view_dir)), corona_edge_softness);

		// === Radial fade
		const float dist = length(input.position_w - corona_position);
		const float inner_fade = smoothstep(corona_inner_fade_start, corona_inner_fade_end, dist);

		// === Fade to space
		const float camera_dist = length(input.position_w);
		const float space_fade = saturate(1.0f - (camera_dist / max_corona_visible_distance));

		// === Combined fade
		const float fade = view_thickness * inner_fade * space_fade;

		// === Final output
		output.scene_color.rgb = tinted_color * light_side_t * fade;

		const float ramped_alpha = get_ramped_alpha(combined.a, corona_alpha_multiplier, depth_fade, input.color0.a);
		output.scene_color.a = ramped_alpha * light_side_t * fade;
	}
#else
	{
#if defined(PRIM3D_COMPLEX)
		// PRIM3D_COMPLEX means the vertex data has two colors, and two texcoords.
		// examples: beam_effects, exhaust_trails (note that coronas are complex as well but they are handled above)
		{
			// texcoord division by z so we can support projective transforms, not just affine (e.g. trapezoid vs rect)
			 float4 s0 = srgb_to_linear(base_texture_0.Sample(wrap_sampler, input.texcoord0.xy / input.texcoord0.z));
			 float4 s1 = srgb_to_linear(base_texture_1.Sample(wrap_sampler, input.texcoord1.xy / input.texcoord1.z));
		
			#if defined(MULTIPLY_COLOR)
				const float3 s0_with_color = s0.rgb * input.color0.rgb;
				const float3 s1_with_color = s1.rgb * input.color1.rgb;			
			#elif defined(ADD_COLOR)
				const float3 s0_with_color = s0.rgb + input.color0.rgb;
				const float3 s1_with_color = s1.rgb + input.color1.rgb;			
			#elif defined(OVERLAY_COLOR)							
				const float3 s0_with_color = BlendMode_Overlay(s0.rgb, input.color0.rgb);
				const float3 s1_with_color = BlendMode_Overlay(s1.rgb, input.color1.rgb);
			#endif

			#if defined(MULTIPLY_BASE_TEXTURES)
			{				
				output.scene_color.rgb = s0_with_color * s1_with_color;

				// we are multiplying so the ramp input terms can be multiplied before ramping.				
				output.scene_color.a = get_ramped_alpha(s0.a * s1.a, 1.f, depth_fade, input.color0.a * input.color1.a);
			}
			#elif defined(ADD_BASE_TEXTURES)
			{
				output.scene_color.rgb = s0_with_color + s1_with_color;
				
				// we are adding so the ramp input terms can't be added before ramping.
				const float ramped_alpha_0 = get_ramped_alpha(s0.a, 1.f, depth_fade, input.color0.a);
				const float ramped_alpha_1 = get_ramped_alpha(s1.a, 1.f, depth_fade, input.color1.a);
				output.scene_color.a = ramped_alpha_0 + ramped_alpha_1;
			}
			#endif
			
			//uncomment to debug exhaust trails (e.g. variable width)
			//output.scene_color.r = max(.01f, output.scene_color.r);
			//output.scene_color.a = 1.f;
			//output.emissive_color = 1.f;
			//return output;
		}
#elif defined(PRIM3D_SIMPLE)
		// PRIM3D_SIMPLE means the vertex data has one color, and one texcoord.
		// examples: particle_effect_billboards, gravity_well_clouds, planet_elevator_cars
		{									
			//float3 erosion_factors : TEXCOORD1; 
			//rgb = erosion_test_base, erosion_noise_offset_u, erosion_noise_offset_v        			
			const float erosion_test_base = input.erosion_factors.r;
			const float2 erosion_noise_offset = float2(input.erosion_factors.g, input.erosion_factors.b);

			//float3 gradient_and_distortion_and_refraction_factors : TEXCOORD2; 
			//rgb = gradient_pan_offset, distortion_scalar, refraction_scalar
			const float gradient_pan_offset = input.gradient_and_distortion_and_refraction_factors.r;
			const float distortion_scalar = input.gradient_and_distortion_and_refraction_factors.g;
			const float refraction_scalar = input.gradient_and_distortion_and_refraction_factors.b;
			
			//distortion
			#if defined(HAS_DISTORTION_1X)
			const float2 distortion_result = get_noise_combine_1x_result_with_bias(distortion_texture, wrap_sampler, input.texcoord0, distortion_constants_0, distortion_scalar, time);
			#elif defined(HAS_DISTORTION_2X)
			const float2 distortion_result = get_noise_combine_2x_result_with_bias(distortion_texture, wrap_sampler, input.texcoord0, distortion_constants_0, distortion_scalar, time);
			#else
			const float2 distortion_result = 0.f;
			#endif

			//erosion noise
			#if defined(HAS_EROSION_1X)
			// todo: convert to get_noise_combine_1x_result. complicated to due to maintaining backwards compat with existing effects.
			const float erosion_noise_result = get_noise_result(wrap_sampler, erosion_texture, input.texcoord0, distortion_result, erosion_constants_0.noise_constants_0, erosion_noise_offset, time).x;
			#elif defined(HAS_EROSION_2X)
			// todo: convert to get_noise_combine_2x_result. complicated to due to maintaining backwards compat with existing effects.
			const float erosion_noise_result = 
				get_noise_result(erosion_texture, wrap_sampler, input.texcoord0, distortion_result, erosion_constants_0.noise_constants_0, erosion_noise_offset, time).x *
				get_noise_result(erosion_texture, wrap_sampler, input.texcoord0, distortion_result, erosion_constants_0.noise_constants_1, erosion_noise_offset, time).x;
			#else
			const float erosion_noise_result = 1.f;
			#endif

			//erosion
			#if defined(HAS_EROSION_1X) || defined(HAS_EROSION_2X)
			const float erosion_t = depth_fade_erosion * erosion_noise_result;
			const float erosion_min = erosion_test_base + erosion_constants_0.erosion_test;
			const float erosion_max = erosion_min + erosion_constants_0.erosion_softness;
			const float erosion_result = saturate(smoothstep(erosion_min, erosion_max, erosion_t));
			#else
			const float erosion_result = 1.f;
			#endif

			//base
			const float2 base_texcoord = input.texcoord0 + distortion_result;
			const float4 b0 = srgb_to_linear(base_texture_0.Sample(wrap_sampler, base_texcoord));
			const float4 b1 = srgb_to_linear(base_texture_1.Sample(wrap_sampler, base_texcoord));	
			#if defined(MULTIPLY_BASE_TEXTURES)
			const float4 base_result = (b0 * b1);
			#elif defined(ADD_BASE_TEXTURES)
			const float4 base_result = (b0 + b1);
			#endif

			//gradient
			#if defined(HAS_GRADIENT)
			const float eroded_based_result = saturate(base_result.r * erosion_result);
			const float gradient_u = saturate(gradient_constants_0.gradient_pan_start + gradient_pan_offset - 1.f + eroded_based_result);
			const float gradient_v = eroded_based_result;
			const float2 gradient_texcoord = float2(gradient_u, gradient_v);
			const float3 gradient_result = srgb_to_linear(gradient_texture.Sample(clamp_sampler, gradient_texcoord)).rgb;
			#else
			const float3 gradient_result = 1.f;
			#endif

			#if defined(MULTIPLY_COLOR)
				#if defined(HAS_GRADIENT)
					output.scene_color.rgb = gradient_result * input.color0.rgb;
				#else
					output.scene_color.rgb = base_result.rgb * input.color0.rgb;
				#endif
			#elif defined(ADD_COLOR)
				#if defined(HAS_GRADIENT)
					output.scene_color.rgb = gradient_result + input.color0.rgb;
				#else
					output.scene_color.rgb = base_result.rgb + input.color0.rgb;
				#endif
			#elif defined(OVERLAY_COLOR)
				#if defined(HAS_GRADIENT)
					output.scene_color.rgb = BlendMode_Overlay(gradient_result, input.color0.rgb);
				#else
					output.scene_color.rgb = BlendMode_Overlay(base_result.rgb, input.color0.rgb);
				#endif
			#endif

			//alpha
			#if defined(HAS_GRADIENT)
			const float base_alpha = base_result.r;
			#else
			const float base_alpha = base_result.a;
			#endif
			
			output.scene_color.a = get_ramped_alpha(base_alpha, erosion_result * erosion_noise_result, depth_fade, input.color0.a);

			#if defined(USE_REFRACTION)
			{			
				// we can't bias this (0..1 -> -1..1) because we are storing the result in a DXGI_FORMAT_R11G11B10_FLOAT buffer
				// which can't store negative numbers.
				const float2 refraction_offset =
					get_noise_combine_2x_result_without_bias(refraction_texture, wrap_sampler, input.texcoord0, refraction_constants_0, refraction_scalar, time);					

				const float refraction_mask = refraction_mask_texture.Sample(wrap_sampler, input.texcoord0.xy).r;				
				output.refraction_offset = float4(refraction_offset, 0.f, 1.f) * refraction_mask.r;
			}
			#else
				output.refraction_offset = 0.f;
			#endif
		}
#endif
	}
#endif	

	output.emissive_color = output.scene_color * basic_constants_0.emissive_factor;

	return output;
}
