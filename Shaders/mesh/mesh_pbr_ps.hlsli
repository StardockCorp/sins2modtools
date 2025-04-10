#include "mesh_scene_cb_data.hlsli"
#include "mesh_samplers.hlsli"

#ifdef ENABLE_SHADOWS
#include "mesh_shadow_utility.hlsli" // needs mesh_samplers already included
#endif

#include "mesh_ps_input.hlsli" // needs shadows already included (if ENABLE_SHADOWS defined)
#include "mesh_pbr_utility.hlsli"
#include "mesh_light_sb_data.hlsli"
#include "mesh_material_cb_data.hlsli"
#include "../color_utility.hlsli"
#include "../math_utility.hlsli"
#include "../light_cluster_sb_data.hlsli"
#include "../light_index_sb_data.hlsli"

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
	float2 texcoord0 = input.texcoord0;

	#ifdef ENABLE_PLANET_ATMOSPHERE
	texcoord0.x += (time * cloud_rotation_speed);
	float3 atmosphere = 0.f;
	#elif defined(ENABLE_STAR_ATMOSPHERE)
	float3 atmosphere = 0.f;
	#endif
	
	const float4 orm_sample = occlusion_roughness_metallic_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord0);
	const float occlusion = orm_sample.r;
	
	// #explanation_for_modders: see Disney, Unreal s2013, Filament section 4.8.8.3, etc.
	const float perceptual_roughness = clamp(orm_sample.g * roughness_metallic_emissive_factors.r, minimum_perceptual_roughness, 1.f);
	const float alpha_roughness = max(perceptual_roughness * perceptual_roughness, minimum_alpha_roughness);
	
	const float metalness = orm_sample.b * roughness_metallic_emissive_factors.g;
	
	const float4 mask_sample = mask_texture.Sample(mesh_anisotropic_wrap_sampler, input.texcoord0);
	
	float4 base_color = base_color_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord0) * base_color_factor;

	#ifdef ENABLE_PLAYER_COLOR	
	// #explanation_for_modders:	
	// BlendMode_Overlay needs to work in srgb space as per Photoshop, Paint.net, GIMP, etc.
	// see note in https://www.ryanjuckett.com/photoshop-blend-modes-in-hlsl
	const float3 primary_overlay = BlendMode_Overlay(base_color.rgb, player_color_primary_srgb.rgb);	
	const float3 secondary_overlay = BlendMode_Overlay(base_color.rgb, player_color_secondary_srgb.rgb);
	base_color.rgb = lerp(base_color.rgb, primary_overlay.rgb, mask_sample.r);
	base_color.rgb = lerp(base_color.rgb, secondary_overlay.rgb, mask_sample.g);
	base_color.rgb = lerp(base_color.rgb, player_color_primary_emissive_srgb.rgb, mask_sample.r * mask_sample.b);
	base_color.rgb = lerp(base_color.rgb, player_color_secondary_emissive_srgb.rgb, mask_sample.g * mask_sample.b);
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
		
	#ifdef ENABLE_EMISSIVE
	// #explanation_for_modders:
	// emissive calculations must be in linear before applying emissive_factor (base_color is linear already so we are ok).
	// next, we need to modulate the emissive color by the base color to preserve hue. we end up with base_color * base_colors
	// because it just so happens we chose base_color for the emissive color but it could have come from a full color emissive texture.
	// Modders see https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc#:~:text=emissive%20%3A%20The%20emissive,performing%20linear%20interpolation.
	const float3 emissive_color = base_color.rgb;	
	const float3 emissive_hue_strength = lerp(1.f, base_color.rgb, roughness_metallic_emissive_factors.a);
	const float emissive_mask_strength = mask_sample.b * roughness_metallic_emissive_factors.b;
	float3 emissive = emissive_color * emissive_mask_strength * emissive_hue_strength;
	#endif
		
	const float2 normal_t_sample = normal_texture.Sample(mesh_anisotropic_wrap_sampler, texcoord0).xy;
	const float4 normal_t_debug = get_normal_t_debug(normal_t_sample);
	const float3 N = get_perturbed_normal_w_from_normal_map(input.position_w, input.normal_w, input.tangent_w, input.fsign, texcoord0, normal_t_sample);	
		
	// View values
	const float3 V = normalize(camera_position.xyz - input.position_w); // dir to camera
	const float NdV = clamp(dot(N, V), .001f, 1.f);
	
	// #explanation_for_modders:
	// Fresnal Reflectance at 0 degrees (i.e normal lines up with view as opposed to F90 which is the grazing angle where normal is orthogonal to view).
	#if defined(ENABLE_EMISSIVE) && defined(RESTRICT_EMISSIVE_TO_DARK_SIDE) && defined(MASK_CITY_LEVEL)
	float3 F0 = lerp(fresnel_dielectric_reflectivity, base_color.rgb, metalness);
	#else
	const float3 F0 = lerp(fresnel_dielectric_reflectivity, base_color.rgb, metalness);
	#endif

	// #explanation_for_modders:
	// Diffuse BRDF: shared by direct and ambient
	#if defined(ENABLE_EMISSIVE) && defined(RESTRICT_EMISSIVE_TO_DARK_SIDE) && defined(MASK_CITY_LEVEL)
	float3 diffuse_as_brdf = diffuse_brdf(base_color.rgb);
	#else
	const float3 diffuse_as_brdf = diffuse_brdf(base_color.rgb);
	#endif

	// Direct Lighting
	float3 radiance_out_from_direct_light_sources = 0.f;

	// Light Clusters
	const uint froxel_z = uint(max(log2(input.position_v.z) * froxel_z_scale + froxel_z_bias, 0.f));
	const uint3 froxel_coordinate = uint3(uint2(input.position_h.xy / froxel_size_in_pixels), froxel_z);
	const uint froxel_index = froxel_coordinate.x + froxel_counts.x * froxel_coordinate.y + (froxel_counts.x * froxel_counts.y) * froxel_coordinate.z;

	const uint light_index_offset = light_clusters[froxel_index].offset;
	const uint light_index_count = light_clusters[froxel_index].count;

	#ifdef ENABLE_SHADOWS 
	// would have preferred this were in the loop for organizational purposes but can't unroll loop properly if it is.
	const float shadow_sample = get_shadow_scalar(input.shadow_map_uvz);	
	#endif

	for (uint i_light_index = 0; i_light_index < light_index_count; i_light_index++)
	{
		const uint light_index = light_indices[light_index_offset + i_light_index].index;
		if(culled_lights[light_index].index == 0) // check if "culled" state is true or false
		{
			#ifdef ENABLE_SHADOWS
			float shadow_factor = 1.f;
			#endif

			float3 v_to_light = lights[light_index].position - input.position_w;
					
			const uint primary_light_index = 0;
			const uint key_light_index = 1;
			const uint fill_light_index = 2;
			const uint rim_light_index = 3;
			
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

			const float d_to_light = length(v_to_light);

			const float3 L = v_to_light / d_to_light; // dir to light source
			const float3 H = normalize(L + V); // dir half way between L and V

			// Primary dot products
			const float NdL = clamp(dot(N, L), .001f, 1.f);
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

			float3 Li = light_color.rgb * light_color.a * lights[light_index].intensity * light_attenuation;
			
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
				emissive = emissive * emissive_scalar;

				#ifdef MASK_CITY_LEVEL
				const float inverse_emissive_scalar = 1.f - emissive_scalar;
				F0 = Desaturate(F0, inverse_emissive_scalar);
				diffuse_as_brdf = Desaturate(diffuse_as_brdf, inverse_emissive_scalar);
				#endif

				#endif			

				#ifdef ENABLE_PLANET_ATMOSPHERE
				const float atmosphere_fresnel = pow(1.f - NdV, atmosphere_spread);
				atmosphere = atmosphere_color.rgb * atmosphere_color.a * atmosphere_fresnel * NdL;
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

			#ifdef ENABLE_SHADOWS
			radiance_out_from_direct_light_sources += (fd + fs) * Li * NdL * shadow_factor;
			#else
			radiance_out_from_direct_light_sources += (fd + fs) * Li * NdL;
			#endif
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
			const float max_mip_map_level_for_specular = 5.f; // maps to 8x8 of a 256x256 map
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