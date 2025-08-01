#include "mesh_scene_cb_data.hlsli"
#include "mesh_samplers.hlsli"
#include "mesh_shadow_utility.hlsli" // needs mesh_samplers already included


#include "mesh_ps_input.hlsli" // needs shadows already included
#include "mesh_pbr_utility.hlsli"
#include "mesh_light_sb_data.hlsli"
#include "mesh_material_cb_data.hlsli"
#include "../color_utility.hlsli"
#include "../math_utility.hlsli"
#include "../light_cluster_sb_data.hlsli"
#include "../light_index_sb_data.hlsli"

#include "mesh_apply_parallax.hlsli"
#include "cel_shaded.hlsli"

#include "ex_features_ps_data.hlsli" 

// Modders, here are some helpful references, but note we make adjustments to suit the art direction and performance needs.
// We've also provided some explanations and derivations for ease of understanding, but you can refer to these sources for more details.
// LearnOpenGL: https://learnopengl.com/PBR/Theory
// KhronosGroup: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0
// Disney/Burley: http://blog.selfshadow.com/publications/s2012-shading-course/burley/s2012_pbs_disney_brdf_notes_v3.pdf
// Unreal/Karis: https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
// Unreal/Karis: http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
// Frostbite/Lagarde/Rousiers: https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
// Filament/Guy/Agopian: https://google.github.io/filament/Filament.html#overview/principles
// Hoffman: https://renderwonk.com/publications/s2010-shading-course/hoffman/s2010_physically_based_shading_hoffman_a_notes.pdf
// Hoffman: http://renderwonk.com/publications/s2010-shading-course/hoffman/s2010_physically_based_shading_hoffman_b_notes.pdf
// Hoffman: https://blog.selfshadow.com/publications/s2013-shading-course/hoffman/s2013_pbs_physics_math_notes.pdf
// Stevens: https://www.jordanstevenstechart.com/physically-based-rendering
// Schlick: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.50.2297&rep=rep1&type=pdf\
// Walter: Microfacet Models for Refraction through Rough Surfaces: https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
// Fdez-Aguera: https://www.jcgt.org/published/0008/01/03/paper.pdf
// Bruno Opsenica: https://bruop.github.io/ibl/

cbuffer froxel_cb_data : register(b3)
{
	uint3 froxel_counts;
	uint froxel_size_in_pixels;
	float froxel_z_scale;
	float froxel_z_bias;
	float2 froxel_constants_padding;
};

cbuffer advanced_planet_rendering_cb_data : register(b4)
{
	float enable_volumetric_scattering;
	float enable_parallax_occlusion;
	float enable_flow_maps;
};

Texture2D base_color_texture : register(t0);
Texture2D occlusion_roughness_metallic_texture : register(t1);
Texture2D normal_texture : register(t2);
Texture2D mask_texture : register(t3);
TextureCube radiance_texture: register(t4);
TextureCube irradiance_texture: register(t5);
Texture2D dfg_texture: register(t6);
StructuredBuffer<mesh_light_sb_data> lights : register(t7);
StructuredBuffer<light_cluster_sb_data> light_clusters : register(t8);
StructuredBuffer<light_index_sb_data> light_indices : register(t9);
StructuredBuffer<light_index_sb_data> culled_lights : register(t10);

// Texture2D shadow_map_texture: register(t11); included via mesh_shadow_utility.hlsi
// Texture2D custom_texture: register(t12); //included via various shaders such as planet and star

struct ps_output
{
	float4 scene_color : SV_TARGET0;
	float4 emissive_color : SV_TARGET1;
};

ps_output main(mesh_ps_input input)
{
	//general constants
	static const uint primary_light_index = 0;
	static const uint key_light_index = 1;
	static const uint fill_light_index = 2;
	static const uint rim_light_index = 3;

	//parallax dials
	static const int base_steps = 32;
	static const int max_steps = 64;

	static const float view_z_glancing_threshold = 0.03f;

	static const float gray_center = 0.5f;
	static const float gray_soft_range = 0.2f;
	static const float gray_flat_threshold = 0.635f;

	//flow map dials
	static const float flow_map_speed = 0.08f;
	static const float flow_map_amplitude = 0.2f;

	//planet atmosphere dials
	static const float density_falloff      = 1.5f;
	static const float scatter_strength     = 1.2f;
	static const float scatter_anisotropy   = 0.6f;
	static const float glow_intensity       = 0.5f;

	static const float sunset_exponent      = 6.0f;  // Higher = tighter horizon band
	static const float sunset_blend         = 0.80f; // 0 = full day color, 1 = full sunset
	static const float sunset_intensity     = 2.5f;  // Sunset brightness multiplier

	static const float3 sky_color_day       = float3(0.3f, 0.6f, 1.0f);
	static const float3 sky_color_sunset    = float3(1.0f, 0.1f, 0.03f);

// === INITIALIZATION ===
float2 base_uv = input.texcoord0;
float2 texcoord_parallax = base_uv;

float4 base_color = float4(0.0f, 0.0f, 0.0f, 1.0f);
float4 final_orm_sample = float4(0.0f, 0.0f, 0.0f, 1.0f);
float2 final_normal_t_sample = float2(0.5f, 0.5f);
float3 atmosphere = float3(0.0f, 0.0f, 0.0f);

#ifdef ENABLE_PLANET_ATMOSPHERE
base_uv.x += time * cloud_rotation_speed;
#endif

// === FLOW MAP ===
float3 flowed_color = 0.0f;
float2 flowed_normal_t = float2(0.5f, 0.5f);
float4 flowed_orm = float4(0, 0, 0, 1);
float flowed_alpha = 1.0f;
float flowed_emissive = 0.0f;
bool flow_active = false;

#ifdef ENABLE_FLOW_MAP
{
    // Sample base mask (initial)
    float4 mask_sample_base = mask_texture.Sample(mesh_anisotropic_wrap_sampler, base_uv);
    float2 flow_raw_center = mask_sample_base.rg * 2.0f - 1.0f;

    bool has_flow = any(mask_sample_base.rg > 0.01f) && any(mask_sample_base.rg < 0.99f);
    if (has_flow)
    {
        flow_active = true;

        // === Directional subpixel smoothing (preserve small-scale motion)
		float2 dir = normalize(flow_raw_center);
		float2 texel = float2(1.0f / 1024.0f, 1.0f / 1024.0f);
		float2 offset = dir * texel;

		float2 flow_raw_a = mask_texture.Sample(mesh_anisotropic_wrap_sampler, base_uv + offset).rg * 2.0f - 1.0f;
		float2 flow_raw_b = mask_texture.Sample(mesh_anisotropic_wrap_sampler, base_uv - offset).rg * 2.0f - 1.0f;

		// Center-weighted blur (preserves directionality)
		float2 flow_vector_raw = (flow_raw_a * 0.25f + flow_raw_center * 0.5f + flow_raw_b * 0.25f);

		// Gain curve: preserve low-end motion
		float flow_mag = saturate(length(flow_vector_raw));
		flow_mag = pow(flow_mag, 0.85f); // < 1.0 = boosts low-mag response

		float2 flow_vector = normalize(flow_vector_raw) * flow_mag * flow_map_amplitude;

        // === Add tiny temporal jitter to flow offset ===
        float jitter = frac(sin(dot(base_uv, float2(12.9898, 78.233))) * 43758.5453 + time) * 1e-4f;
        flow_vector += jitter;

        // === Dual-phase blend ===
        float t = time * flow_map_speed;
        float phase0 = frac(t);
        float phase1 = frac(t + 0.5f);

        float tri = abs(phase0 - 0.5f) * 2.0f;
        float w0 = 1.0f - tri;
        float w1 = tri;
        float total = w0 + w1 + 1e-5f;

        float2 uv0 = base_uv + flow_vector * phase0;
        float2 uv1 = base_uv + flow_vector * phase1;

        float2 uv0_disp = uv0;
        float2 uv1_disp = uv1;

#ifdef ENABLE_PARALLAX_OCCLUSION
		float3 view_dir = normalize(input.view_dir_tangent);
		float view_z = abs(view_dir.z) + 1e-5f;

		uv0_disp = ApplyParallax(uv0, view_dir, view_z, occlusion_roughness_metallic_texture, mask_texture,
									mesh_anisotropic_wrap_sampler, parallax_factor, gray_center, gray_soft_range,
									gray_flat_threshold, base_steps, max_steps);
		uv1_disp = ApplyParallax(uv1, view_dir, view_z, occlusion_roughness_metallic_texture, mask_texture,
									mesh_anisotropic_wrap_sampler, parallax_factor, gray_center, gray_soft_range,
									gray_flat_threshold, base_steps, max_steps);
#endif

        texcoord_parallax = (uv0_disp * w0 + uv1_disp * w1) / total;

        flowed_color = (
            base_color_texture.Sample(mesh_anisotropic_wrap_sampler, uv0_disp).rgb * w0 +
            base_color_texture.Sample(mesh_anisotropic_wrap_sampler, uv1_disp).rgb * w1
        ) / total;

        flowed_normal_t = (
            normal_texture.Sample(mesh_anisotropic_wrap_sampler, uv0_disp).xy * w0 +
            normal_texture.Sample(mesh_anisotropic_wrap_sampler, uv1_disp).xy * w1
        ) / total;

        flowed_orm = (
            occlusion_roughness_metallic_texture.Sample(mesh_anisotropic_wrap_sampler, uv0_disp) * w0 +
            occlusion_roughness_metallic_texture.Sample(mesh_anisotropic_wrap_sampler, uv1_disp) * w1
        ) / total;

        flowed_alpha = (
            base_color_texture.Sample(mesh_anisotropic_wrap_sampler, uv0_disp).a * w0 +
            base_color_texture.Sample(mesh_anisotropic_wrap_sampler, uv1_disp).a * w1
        ) / total;

        flowed_emissive = (
            mask_texture.Sample(mesh_anisotropic_wrap_sampler, uv0_disp).b * w0 +
            mask_texture.Sample(mesh_anisotropic_wrap_sampler, uv1_disp).b * w1
        ) / total;
    }
}
#endif

// === FINAL SAMPLES ===
if (flow_active)
{
    base_color.rgb = flowed_color;
    final_normal_t_sample = flowed_normal_t;
    final_orm_sample = flowed_orm;
    base_color.a = flowed_alpha;
}
else
{
#ifdef ENABLE_PARALLAX_OCCLUSION
	float3 view_dir = normalize(input.view_dir_tangent);
	float view_z = abs(view_dir.z) + 1e-5f;

	texcoord_parallax = ApplyParallax(
		base_uv, view_dir, view_z,
		occlusion_roughness_metallic_texture, mask_texture,
		mesh_anisotropic_wrap_sampler, parallax_factor,
		gray_center, gray_soft_range, gray_flat_threshold,
		base_steps, max_steps);
#else
	texcoord_parallax = base_uv;
#endif

    base_color.rgb = base_color_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord_parallax).rgb;
    final_normal_t_sample = normal_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord_parallax).xy;
    final_orm_sample = occlusion_roughness_metallic_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord_parallax);
    base_color.a = base_color_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord_parallax).a;
}

// === MASK SAMPLE AT PARALLAX ===
float4 mask_sample = mask_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord_parallax);
float emissive_mask = flow_active ? flowed_emissive : mask_sample.b;

// === EMISSIVE RECESS DEPTH ===
float orm_alpha = final_orm_sample.a;
float combined_depth = min(orm_alpha, 1.0f - emissive_mask);
float displaced_depth = 1.0f - pow(combined_depth, 0.5f);

// === NORMAL CALC ===
const float3 N = get_perturbed_normal_w_from_normal_map(
    input.position_w, input.normal_w, input.tangent_w, input.fsign,
    texcoord_parallax, final_normal_t_sample);

	if (g_retro_enabled == 1 || g_liq_crys_enabled == 1)
	{
		// === Approximate motion from screen-space derivatives
		float motionStrength = saturate(length(fwidth(input.texcoord0)) * 75.0);

		// === Chunky, slow-moving jagged UV distortion
		float2 jaggedInput = input.texcoord0 * 25.0 + floor(time * 6.5); // low frequency, stepped time
		float2 jaggedNoise = frac(sin(jaggedInput) * 43758.5453);  // stable sharp pattern
		jaggedNoise = (jaggedNoise - 1.5) * 2.0;

		float2 uvOffset = jaggedNoise * 0.015 * motionStrength; // bigger offset for boldness

		float2 distortedUV = input.texcoord0 + uvOffset;

		// === Ink Bleed
		float2 bleedOffset = float2(0.0045, 0.0045); // stronger bleed to match distortion
		float4 colorMain = base_color_texture.Sample(mesh_anisotropic_wrap_sampler, distortedUV);
		float4 colorBleed = base_color_texture.Sample(mesh_anisotropic_wrap_sampler, distortedUV + bleedOffset);

		float bleedAmount = 0.23;
		base_color = lerp(colorMain, colorBleed, bleedAmount) * base_color_factor;
	}
    

const float3 V = normalize(camera_position.xyz - input.position_w);
const float NdV = clamp(dot(N, V), 0.001f, 1.0f);

// === FINAL MATERIAL FACTORS ===
float occlusion = final_orm_sample.r;
float perceptual_roughness = clamp(final_orm_sample.g * roughness_metallic_emissive_factors.r, minimum_perceptual_roughness, 2.2f);
float alpha_roughness = max(perceptual_roughness * perceptual_roughness, minimum_alpha_roughness);
float metalness = final_orm_sample.b * roughness_metallic_emissive_factors.g;

#ifdef ENABLE_PLAYER_COLOR
base_color.rgb = lerp(base_color.rgb, BlendMode_Overlay(base_color.rgb, player_color_primary_srgb.rgb), mask_sample.r);
base_color.rgb = lerp(base_color.rgb, BlendMode_Overlay(base_color.rgb, player_color_secondary_srgb.rgb), mask_sample.g);
base_color.rgb = lerp(base_color.rgb, player_color_primary_emissive_srgb.rgb, mask_sample.r * emissive_mask);
base_color.rgb = lerp(base_color.rgb, player_color_secondary_emissive_srgb.rgb, mask_sample.g * emissive_mask);
#endif

#ifdef ENABLE_EMISSIVE
// #explanation_for_modders:
// emissive calculations must be in linear before applying emissive_factor (base_color is linear already so we are ok).
// next, we need to modulate the emissive color by the base color to preserve hue. we end up with base_color * base_colors
// because it just so happens we chose base_color for the emissive color but it could have come from a full color emissive texture.
// Modders see https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc#:~:text=emissive%20%3A%20The%20emissive,performing%20linear%20interpolation.
float3 emissive_color = base_color.rgb;
emissive_color = pow(emissive_color, 1.8f);

float emissive_strength = emissive_mask * roughness_metallic_emissive_factors.b;
float3 emissive_hue_strength = lerp(1.0f, emissive_color, roughness_metallic_emissive_factors.a);
float3 emissive = emissive_color * emissive_strength * emissive_hue_strength;
#endif
	// #explanation_for_modders:
	// base_color must be in linear before applying base_color_factor
	// https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc#:~:text=The%20base%20color%20texture,before%20performing%20linear%20interpolation.
	base_color = srgb_to_linear(base_color) * base_color_factor;
	
	// opague and transparent pass handling
	{
		// use of clip() preserves early-z optimizations better than discard and enables us to cut down on cpu side sorting.
		// reminder that clip() skips the pixel if its less than 0 
		
		const float opague_tolerance = .01f;
#if defined(ENABLE_OPAGUE_ONLY)
		{		
			// do nothing. listed here for completeness
		}
#elif defined(ENABLE_OPAGUE_PASS)
		{		
			clip(base_color.a - (1.f - opague_tolerance));
		}
#elif defined(ENABLE_TRANSPARENT_PASS)
		{
			clip(1.f - (base_color.a + opague_tolerance));
		}
#elif defined(ENABLE_BUILDING_OPAGUE_PASS)	
		{
			// don't render pixels that are transparent. we need to write the opague ones so z-buffer is correct.
			const float percent_height = saturate((input.position_l.y - min_height) / (max_height - min_height));		
		
			clip(build_percentage - percent_height);
		}
#elif defined(ENABLE_BUILDING_TRANSPARENT_PASS)
		{
			// don't render the built (opague) portion. we already rendered it in the opague pass.
			const float percent_height = saturate((input.position_l.y - min_height) / (max_height - min_height));
			if (percent_height <= build_percentage)
			{
				// this will be an early exit. don't use an else block for the base_color.a assignment below. 
				// straight line code helps with gpu's ability to predict and optimize flow of execution.
				clip(-1.f);		
			}

			const float building_alpha = .1f; //#todo data drive this value
			base_color.a = building_alpha;				
		}
#endif
	}

	// #explanation_for_modders:
	// Fresnal Reflectance at 0 degrees (i.e normal lines up with view as opposed to F90 which is the grazing angle where normal is orthogonal to view).
	float3 F0 = lerp(fresnel_dielectric_reflectivity, base_color.rgb, metalness);

	// #explanation_for_modders:
	// Diffuse BRDF: shared by direct and ambient
	float3 diffuse_as_brdf = diffuse_brdf(base_color.rgb);

	// Direct Lighting
	float3 radiance_out_from_direct_light_sources = 0.f;

	// Light Clusters
	const uint froxel_z = uint(max(log2(input.position_v.z) * froxel_z_scale + froxel_z_bias, 0.f));
	const uint3 froxel_coordinate = uint3(uint2(input.position_h.xy / froxel_size_in_pixels), froxel_z);
	const uint froxel_index = froxel_coordinate.x + froxel_counts.x * froxel_coordinate.y + (froxel_counts.x * froxel_counts.y) * froxel_coordinate.z;

	const uint light_index_offset = light_clusters[froxel_index].offset;
	const uint light_index_count = light_clusters[froxel_index].count;

	#ifdef ENABLE_SHADOWS
	// sample raw shadow
	// would have preferred this were in the loop for organizational purposes but can't unroll loop properly if it is.
	const float shadow_sample = get_shadow_scalar(input.shadow_map_uvz, input.position_w.xyz, camera_position.xyz);
	#endif

	for (uint i_light_index = 0; i_light_index < light_index_count; i_light_index++)
	{
		// #light_encoding
		// ignore primary light. key, fill, and rim will take its place.
#ifdef ENABLE_KEY_FILL_RIM_LIGHT_ANGLES			
		if (i_light_index == primary_light_index)
		{
			continue;
		}
#else
		// otherwise use the primary light and ignore the key, fill, and rim
		if(i_light_index == key_light_index || i_light_index == fill_light_index || i_light_index == rim_light_index)
		{
			continue;
		}
#endif

		const uint light_index = light_indices[light_index_offset + i_light_index].index;
		if(culled_lights[light_index].index == 0) // check if "culled" state is true or false
		{
			float shadow_factor = 1.f;

			const float3 v_to_light = lights[light_index].position - input.position_w;
			const float d_to_light = length(v_to_light);

			const float3 L = v_to_light / d_to_light; // dir to light source
			const float3 H = normalize(L + V); // dir half way between L and V

			// Primary dot products
			const float NdL = clamp(dot(N, L), .001f, 1.f);//poor man's normalize
			const float NdH = saturate(dot(N, H));
			const float LdH = saturate(dot(L, H));	

			float light_attenuation = 1.f;
			
			if (lights[light_index].type == MESH_LIGHT_TYPE_POINT_FINITE)
			{
				light_attenuation = get_light_attenuation(d_to_light - lights[light_index].surface_radius, lights[light_index].attenuation_radius);
			}
			else if (lights[light_index].type == MESH_LIGHT_TYPE_CONE)
			{
				const float dot_cone_axis = dot(-L, lights[light_index].direction);
				if (dot_cone_axis >= cos(lights[light_index].angle)) //todo: optimize by passing this cos value in
				{
					light_attenuation = get_light_attenuation(d_to_light - lights[light_index].surface_radius, lights[light_index].attenuation_radius);
				}
				else
				{
					light_attenuation = 0.f;
				}
			}
			else if (lights[light_index].type == MESH_LIGHT_TYPE_LINE)
			{
				const float3 a = lights[light_index].position;
				const float3 b = lights[light_index].position + lights[light_index].direction * lights[light_index].length;

				const float d_to_line = get_distance_to_line(a, b, input.position_w);

				light_attenuation = get_light_attenuation(d_to_line - lights[light_index].surface_radius, lights[light_index].attenuation_radius);
			}
			
			float4 light_color = lights[light_index].color;
			
			// remove this and data drive
#ifdef ENABLE_KEY_FILL_RIM_LIGHT_ANGLES
			if (i_light_index == key_light_index)
			{
				// do nothing. fill and rim light brightness are relative to key light
			}
			else if (i_light_index == fill_light_index)
			{
				float3 hsb = rgb_to_hsb(light_color.rgb);
				hsb.b /= 3.f; // todo data drive me
				light_color.rgb = hsb_to_rgb(hsb);           
			}
			else if (i_light_index == rim_light_index)
			{
				float3 hsb = rgb_to_hsb(light_color.rgb);
				hsb.b *= 1.f;//.75f; // todo data drive me
				light_color.rgb = hsb_to_rgb(hsb);
			}
#endif
			// future optimization: pass this down in linear form
			light_color = srgb_to_linear(light_color);

			const float3 Li = light_color.rgb * light_color.a * lights[light_index].intensity * light_attenuation;
			
#ifdef ENABLE_KEY_FILL_RIM_LIGHT_ANGLES			
			if (i_light_index == key_light_index)
#else 
			if (i_light_index == primary_light_index)
#endif			
			{
#ifdef ENABLE_SHADOWS			
				shadow_factor = shadow_sample;
#endif

#if defined(ENABLE_EMISSIVE) && defined(RESTRICT_EMISSIVE_TO_DARK_SIDE)
				const float emissive_scalar = 1.f - saturate(NdL * 10.f); //todo: data drive this scalar
				float2 emissive = emissive * emissive_scalar;

#ifdef MASK_CITY_LEVEL
				const float inverse_emissive_scalar = 1.f - emissive_scalar;
				F0 = Desaturate(F0, inverse_emissive_scalar);
				diffuse_as_brdf = Desaturate(diffuse_as_brdf, inverse_emissive_scalar);
#endif

#endif			

#ifdef ENABLE_PLANET_ATMOSPHERE
				if (enable_volumetric_scattering > 0)
				{
					// === View, Light, and Normal
					const float3 V = normalize(input.position_w - camera_position.xyz);
					const float3 N = normalize(input.normal_w);
					const float3 L = normalize(v_to_light - input.position_w);

					// === Shell height
					const float height = saturate(input.texcoord1.y);
					const float density = exp(-height * density_falloff);

					// === Angular terms
					const float NdV = saturate(dot(N, V));
					const float NdL = saturate(dot(N, L));
					const float fresnel_term = pow(1.0f - NdV, 3.0f);
					const float light_term   = pow(NdL, 1.5f);
					const float cos_theta    = dot(V, L);

					// === Henyey-Greenstein phase function
					const float g = scatter_anisotropy;
					const float phase = (1.0f - g * g) / pow(max(1.0f + g * g - 2.0f * g * cos_theta, 0.05f), 1.5f);

					// === Sunset tint with tighter control
					const float sunset_factor = pow(saturate(1.0f - NdL), sunset_exponent);
					const float3 sunset_tint = lerp(sky_color_day, sky_color_sunset, saturate(sunset_factor * sunset_blend));
					const float3 tint = sunset_tint * lerp(1.0f, sunset_intensity, sunset_factor);

					// === Final scattering
					const float scatter_intensity = density * fresnel_term * light_term * phase * scatter_strength;
					const float3 scattered = tint * scatter_intensity;

					// === Additive glow output
					const float3 additive_glow = scattered * glow_intensity;
					atmosphere = additive_glow * atmosphere_color.a;
				}
				else
				{
					// === Tunable parameters ===
					const float rim_strength         = 5.0f;    // brightness multiplier
					const float rim_sharpness        = 6.0f;    // fresnel rim falloff
					const float volume_scatter_strength   = 1.5f;
					const float volume_scatter_anisotropy = 0.65f; // 0 = isotropic, 1 = strong forward scatter

					// === View direction (camera → fragment)
					const float3 V = normalize(input.position_w - camera_position.xyz);

					// === Fresnel rim factor
					const float fresnel_term = pow(saturate(1.0f - NdV), rim_sharpness);
					const float light_term   = saturate(NdL);

					// === View alignment with light direction
					const float view_light_dot = dot(V, L); // [-1..1], 1 = forward scatter

					// === Stronger, more distinct color ramp
					const float3 yellow = float3(1.0f, 0.95f, 0.2f);  // vivid yellow
					const float3 orange = float3(1.0f, 0.4f, 0.0f);   // deep orange
					const float3 red    = float3(0.9f, 0.1f, 0.05f);  // punchy red

					// === Tighter transitions for clearer color bands
					const float t1 = smoothstep(0.35f, 0.55f, view_light_dot); // yellow → orange
					const float t2 = smoothstep(0.60f, 0.80f, view_light_dot); // orange → red

					// === Multi-stage blend
					const float3 mid_color    = lerp(yellow, orange, t1);
					const float3 sunset_color = lerp(mid_color, red, t2);

					// === Final blend with base color
					const float3 base_color  = atmosphere_color.rgb;
					const float3 sunset_blend = lerp(base_color, sunset_color, t2); // red dominant at horizon

					// === Volume scattering (Henyey-Greenstein phase approximation)
					float g = volume_scatter_anisotropy;
					float phase = (1.0f - g * g) / pow(1.0f + g * g - 2.0f * g * view_light_dot, 1.5f);
					float scatter_boost = saturate(volume_scatter_strength * phase);

					// === Final result
					const float3 final_color = sunset_blend * (1.0f + scatter_boost);

					// === Output
					atmosphere = final_color * atmosphere_color.a * rim_strength * fresnel_term * light_term;
				}
#endif
			}

			// #explanation_for_modders:
			// Fresnel + Geometric Self Shadowing + Normal Distribution required for specular component of Cook-Torrance BRDF
			const float3 F = f_specular_brdf(F0, LdH); //encodes ks
			const float G = g_specular_brdf(NdL, NdV, perceptual_roughness);
			const float D = d_specular_brdf(NdH, alpha_roughness);

			// #explanation_for_modders:
			// fr = fd + fs = kd * diffuse + ks * specular
			const float3 kd = lerp(1.f - F, 0.f, metalness); // metals reflect or absorb - no diffuse!
			const float3 fd = kd * diffuse_as_brdf;
			
			// #explanation_for_modders:
			// const float3 ks = null; ks is essentially F (defined as the ratio of surface reflection) hence the 1.f - F in calculating kd.
			// Modders see https://learnopengl.com/PBR/Theory for a concise explanation.

			// todo: compare speed quality against V_SmithGGXCorrelated variations.
			const float3 fs = (F * G * D) / max(4.f * NdV * NdL, .0001f); // modders see Cook-Torrance BRDF.

			// #explanation_for_modders: 
			// Rendering Equation:
			// Lo = Ld + Ls (diffuse component + specular component)
			// Ld = fd * Li * NdL * shadow_factor
			// Ls = fs * Li * NdL * shadow_factor
			// Lo = fr * Li * NdL * shadow_factor (if source of the directional light that caused the shadow)
			// Lo = Radiance out (final color)
			// fr = fd + fs (diffuse component + specular component)
			// Li = Radiance in (from light sources)		

			radiance_out_from_direct_light_sources += (fd + fs) * Li * NdL * shadow_factor;
		}
	}

	// Ambient / Image Based Lighting (IBL)
	float3 radiance_out_from_environment = 0.f;
	{
		// #explanation_for_modders:
		// Rendering Equation: same as above (in direct lighting) except Li (radiance in) is from the environment.
		// Lo = Ld + Ls (diffuse component + specular component)

		// Same calculations as above (in direct lighting) except F is calculated using NdV instead of LdH and we need to account for roughness.		
		const float3 F = f_specular_brdf_with_roughness(F0, NdV, perceptual_roughness); //aka ks

		//Diffuse IBL:
		float3 Ld;
		{
			// #explanation_for_modders:
			// Goal: Ld = fd * Li * NdL.
			// Li * NdL is split between diffuse and specular in IBL so we can't use Lo = (fd + fs) * Li * NdL as in direct lighting.
			// fd = kd * diffuse component
			// Li_Ndl = diffuse_irradiance precalculated in texture
			const float3 kd = lerp(1.f - F, 0.f, metalness); // metals reflect or absorb - no diffuse!
			const float3 fd = kd * diffuse_as_brdf;
			const float3 Li_NdL = srgb_to_linear(irradiance_texture.Sample(mesh_anisotropic_wrap_sampler, N).rgb);
			Ld = fd * Li_NdL;
		}

		//Specular IBL:
		float3 Ls;
		{
			// #explanation_for_modders:
			// Goal: Ls = fs * Li * NdL.
			// Li * NdL is split between diffuse and specular in IBL so we can't use Lo = (fd + fs) * Li * NdL as in direct lighting.
			// fs = ks * specular component
			// Ls = ks * (F0 * DFG1 + F90 * DFG2) * LD. We assume F90 is 1.
			// Ls = (F * DFG1 + F90 * DFG2) * LD. Like above, the ks fresnel component is already encoded in F.
			// DFG1 = precalculated in channel r.
			// DFG2 = precalculated in channel g.
			// LD = sampled from environment where roughness maps to mip_level.

			// Expects a 256x256 cubemap wth mipmaps. Peon should have created the mipmaps in the build process.
			const float max_mip_map_level_for_specular = 3.f; // [BJJ] maps to 32x32 of a 256x256 map. Changed from 8x8.
			const float3 specular_reflection_dir = normalize(reflect(-V, N)); // dir of reflection off surface to the viewer
			const float mip_map_level_for_specular_irradiance = perceptual_roughness * max_mip_map_level_for_specular;
			const float3 specular_irradiance = srgb_to_linear(radiance_texture.SampleLevel(mesh_anisotropic_wrap_sampler, specular_reflection_dir, mip_map_level_for_specular_irradiance).rgb);

			const float3 dfg = dfg_texture.SampleLevel(mesh_linear_clamp_sampler, float2(NdV, perceptual_roughness), 0).rgb;

			const float DFG1 = dfg.r;
			const float DFG2 = dfg.g;
			const float3 F90 = 1.f; // same simplification made in Schilick specular BRDF
			const float3 LD = specular_irradiance;
			Ls = (F * DFG1 + F90 * DFG2) * LD;
		}

		// Lo = Ld + Ls
		radiance_out_from_environment = Ld + Ls;
	}

	float3 total_radiance_out = radiance_out_from_direct_light_sources + radiance_out_from_environment;

	total_radiance_out *= occlusion;

#ifdef ENABLE_EMISSIVE
	total_radiance_out += emissive;
#endif

#if defined(ENABLE_PLANET_ATMOSPHERE) || defined(ENABLE_STAR_ATMOSPHERE)
	{
		// todo: data drive all these values
		#if defined(ENABLE_STAR_ATMOSPHERE)		
		const float cloud_animation_speed = .15f;
		const float cloud_noise_0_zoom = 4.f;
		const float cloud_noise_0_intensity = 1.f;
		const float cloud_noise_1_zoom = 8.f;
		const float cloud_noise_1_intensity = 2.f;
		const float atmosphere_spread = 8.f;
		const float4 atmosphere_color = float4(.93f, .91f, .5f, .5f);

#endif

#if defined(ENABLE_PLANET_ATMOSPHERE)
		const float percent_of_height = saturate(abs(input.position_l.y) / planet_radius);
		total_radiance_out *= saturate(lerp(1.f, 0.f, (percent_of_height - .75f) / .2f)); //cuts out the polar caps to hide seams
#endif

		// planet cloud animation or (star 'cloud' animation i.e. the bubbling above the surface)
		const float2 noise_texcoord0 = cloud_noise_0_zoom * input.texcoord0;
		const float noise0 = cloud_noise_0_intensity * noise_texture.Sample(mesh_anisotropic_wrap_sampler, noise_texcoord0).r;

		const float cloud_animation_time = cloud_animation_speed * time;
		
#if defined(ENABLE_PLANET_ATMOSPHERE)
		const float x_offset = noise0 - cloud_animation_time;
		const float y_offset = 0.f;
#elif defined(ENABLE_STAR_ATMOSPHERE)
		const float x_offset = noise0 - cloud_animation_time;
		const float y_offset = noise0 - x_offset;
#endif

		const float2 noise_texcoord1 = cloud_noise_1_zoom * input.texcoord0 - float2(x_offset, y_offset);
		const float noise1 = saturate(cloud_noise_1_intensity * noise_texture.Sample(mesh_anisotropic_wrap_sampler, noise_texcoord1).r);

		total_radiance_out *= noise1;
				
#if defined(ENABLE_STAR_ATMOSPHERE)
		// star atmosphere		
		const float atmosphere_fresnel = pow(1.f - NdV, atmosphere_spread);
		atmosphere = atmosphere_color.rgb * atmosphere_color.a * atmosphere_fresnel; // no NdL component because the star is the light source
#endif

		// atmosphere contribution needs to be done after the cloud animation or only clouded areas will scatter light
		total_radiance_out += atmosphere;
	}
#endif

	// todo: #shadows: add a new shader or shader define to control rendering cascades
	// do not remove this until the new system is in. required for debugging.
	// to use this, also set the shadow_scalar to the cascade index in get_shadow_scalar() of mesh_shadow_utility.hlsli
	/*#ifdef ENABLE_SHADOWS	
	if(shadow_sample == 0)
	{
		total_radiance_out = float3(1,0,0);
	}
	else if(shadow_sample == 1)
	{
		total_radiance_out = float3(0,1,0);
	}
	else if(shadow_sample == 2)
	{
		total_radiance_out = float3(0,0,1);
	}
	else if(shadow_sample == 3)
	{
		total_radiance_out = float3(1,1,1);
	}
	else
	{
		total_radiance_out = 1.f;
	}
	#endif*/
	
	#ifdef ENABLE_TOON_SHADING
	if (g_toon_enabled == 1 || g_retro_enabled == 1 || g_liq_crys_enabled == 1)
	{
		float3 baseColor = base_color.rgb;

		// --- Smoothed normal (world space) ---
		float3 detailedNormal = normalize(N);                     // from normal map
		float3 flattenedNormal = normalize(input.normal_w);       // geometric normal
		float flattenFactor = 0.1;                                // tweak for style
		float3 finalNormal = normalize(lerp(flattenedNormal, detailedNormal, flattenFactor));

		// --- Light direction (normalized) ---
		float3 lightDir = normalize(get_shadow_scalar(input.shadow_map_uvz, input.position_w.xyz, camera_position.xyz)); // if directional

		if (g_retro_enabled == 1 || g_toon_enabled == 1)
		{
			lightDir = float3(0.5,0.5,0.5); // kill shadows
		}

		// --- View direction ---
		float3 viewDir = normalize(camera_position.xyz - input.position_w);

		if (g_retro_enabled == 1 || g_liq_crys_enabled == 1)
		{
			// --- Final cel-shaded lighting result ---
			total_radiance_out = CelShadingJagged(baseColor, finalNormal, lightDir, viewDir, occlusion, input.position_v.z);
		}
		else
		{
			// --- Final cel-shaded lighting result ---
			total_radiance_out = CelShading(baseColor, finalNormal, lightDir, viewDir, occlusion, input.position_v.z);
		}
	}

	#endif


	ps_output output;
	output.scene_color = float4(total_radiance_out, base_color.a);

#ifdef ENABLE_EMISSIVE
	output.emissive_color = float4(emissive.rgb, base_color.a);
#else
	output.emissive_color = float4(0.f, 0.f, 0.f, base_color.a);
#endif
	
#ifdef MASK_CITY_LEVEL
	const float t = max_city_level;
	output.scene_color = lerp(0.f, output.scene_color, t);
#ifdef ENABLE_EMISSIVE
	output.emissive_color = lerp(0.f, output.emissive_color, t);
#endif
#endif	


	return output;
}