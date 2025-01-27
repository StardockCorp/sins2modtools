#include "../math_utility.hlsli"
#include "../color_utility.hlsli"

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

static const float fresnel_dielectric_reflectivity = .04f; // modders see Karis s2013 page 9
static const float minimum_perceptual_roughness = .0001f; // modders see Filament section 4.8.8.3
static const float minimum_alpha_roughness = .045f; // modders see Filament section 4.8.8.3

float3 diffuse_brdf(float3 diffuse_color)
{
	// #explanation_for_modders:
	// diffuse component of Cook_Torrance BRDF.
	// Method: Lambert (as per Unreal)
	return diffuse_color / math_pi;
}

float3 f_specular_brdf(float3 F0, float LdH)
{
	// #explanation_for_modders:
	// F_function for specular component of Cook_Torrance BRDF.	
	// fresnel: Ratio of surface reflection at different surface angles.	

	// Method: Schlick
	// Recall that with Schlick's approximation we replace the normal in cos(theta) = NdV with H. 
	// This H can be dotted with either L or V as its halfway between them.
	// see https://en.wikipedia.org/wiki/Schlick%27s_approximation

	// Note: could replace the power with Unreal's Spherical Gaussian approximation  
	// but it's not intuitive and performance gains for us appear minimal.

	const float F90 = 1.f;
	return F0 + (F90 - F0) * pow(saturate(1.0 - LdH), 5.f);
}

float3 f_specular_brdf_with_roughness(float3 F0, float LdH, float perceptual_roughness)
{
	// #explanation_for_modders:
	// See notes in f_specular_brdf for basics.
	// Unique to this function is including roughness as recommended by Fdez-Aguera.
	// See https://www.jcgt.org/published/0008/01/03/paper.pdf
	// Also see https://bruop.github.io/ibl/ "Roughness Dependent Fresnel" section.
		
	// Due to roughness, F90 = 1 isn't ideal. 
	// Basically, as roughness increases, diffuseness should increase and spec should decrease.
	// If roughness is 0, we basically get F90 = 1 which makes sense for a super smooth surface.	
	const float3 Fr = max(1.f - perceptual_roughness, F0) - F0;
	return F0 + Fr * pow(saturate(1.0 - LdH), 5.f);
}

float g_specular_smith(float NdX, float k)
{
	// #explanation_for_modders:
	// as an optimization note that k can't be lower than 1/8 (.125). 
	// therefore, we don't need to worry about dividing by zero (or a really small number) even if NdX is 0.
	return NdX / (NdX * (1.f - k) + k);
}

float g_specular_brdf(float NdL, float NdV, float perceptual_roughness)
{
	// #explanation_for_modders:
	// G_function for specular component of of Cook_Torrance BRDF.
	// geometric_self_shadowing: Describes the self-shadowing property of the microfacets. 
	// When a surface is relatively rough, the surface's microfacets can overshadow other microfacets reducing the light the surface reflects.

	// Method: 
	// 1. Smith model of the form: G = G(v)G(l) where G(x) is Schlick's approximation of Walter's GGX D_function.
	// 2. Reminder if we change this: it needs to be an alternate GGX approximation to match the GGX D_function.

	//	Derivation of k:
	//	Change Schlick's value for k to alpha_roughness / 2 as per Unreal.
	//	Replace alpha_roughness with Disney term (roughness + 1) / 2. 
	//		r = perceptual_roughness	
	//		a = alpha_roughness
	//		a = r^2
	//		k = a / 2
	//		k = r^2 / 2
	//		map r to (r+1)/2
	//		k = ((r+1)/2)^2/2
	//		k = (r+1)^2/8
	
	// note: same result as Unreal s2013
		
	// verification that we can optimize g_specular_smith() by not needing to handle division by 0:
	// pr ranges from 1 to 2 assuming worst case 0 perceptual_roughness (we actually clamp it above 0 for other reasons but assume the worst case).
	// therefore k >= 1/8 (.125). this k value guarantees no division by 0 in g_specular_smith(). see g_specular_smith()
	const float pr = (perceptual_roughness + 1);
	const float k = (pr * pr) / 8.f;
	const float smith_L = g_specular_smith(NdL, k);
	const float smith_V = g_specular_smith(NdV, k);
	return smith_L * smith_V;	
}

float d_specular_brdf(float NdH, float alpha_roughness)
{
	 // #explanation_for_modders:
	// D_function for specular component of Cook_Torrance BRDF.
	// normal_distribution: Approximates the amount the surface's microfacets are aligned to the halfway vector, influenced by the roughness of the surface; 
	// this is the primary function approximating the microfacets.

	// Method: GGX (Trowbridge-Reitz) (as per Unreal s2013)

	const float a2 = alpha_roughness * alpha_roughness;
	const float f = (NdH * NdH) * (a2 - 1.f) + 1.f;
	return a2 / (math_pi * f * f);
}

float get_light_attenuation(float d_to_light, float light_radius)
{
	// #explanation_for_modders:
	// adapted from Unreal and Frostbite. See references above.	
	
	// intuitive form:
	// const float dist = max(d_to_light, 0.f);
	// const float t = pow(dist / light_radius, 4);
	// return pow(saturate(1.f - t), 2) / (pow(dist, 2.f) + 1);
	
	//optimized form:
	const float dist = max(d_to_light, 0.f);
	const float t1 = dist / light_radius;
	const float t4 = t1 * t1 * t1 * t1;
	const float s = saturate(1.f - t4);
	return (s * s) / ((dist * dist) + 1.f);	
	
	// todo: due to the game's scale, consider adjusting the curve to reduce the need for large volumes to achieve the desired effect. 
	// The low and extended tail means much of the light in the volume is barely visible, yet still occupies many froxels, 
	// increasing dynamic lighting costs. will need to script a data conversion from current values to new values.
}

float3 get_perturbed_normal_w(float3 position_w, float3 normal_w, float3 tangent_w, float fsign, float2 uv, float3 normal_t)
{
	// #explanation_for_modders:
	// #sins2_normals_and_tangents
	// Orginally, we used Christian Schuler's method as described at http://www.thetenthplanet.de/archives/1180. 
	// While it saves on data transfer volume, the results can leave a fair bit of faceting under certain circumstances.
	// Instead, tangents are pre-generated in MeshBuilder using Mikkelsen's method as decribed at http://www.mikktspace.com/.
	// Mikkelsen has far superior quality.
	
	// Easily reproduced and compared using https://github.com/KhronosGroup/glTF-Sample-Viewer which has implementations
	// of both Schuler' and Mikkelsen's methods. 
	// See material_info.glsl getNormalInfo() for the derivative based Schuler variant and mikktspace.js generateTangents().
	// Note that the khronos version of mikktspace is not 100% accurate but still better than the derivate based method:
	// 1. the tangent sign multiply is done in the vertex shader but is more accurate in the pixel shader. 
	// see primitive.vert vec3 bitangentW = cross(normalW, tangentW) * a_tangent.w. see http://www.mikktspace.com/.
	// 2. the pixel shader operates on the normalized TBN vectors from the vertex shader but they are supposed to be in their 
	// unnormalized interpolated form. see http://www.mikktspace.com/
	// 3. the normal calculation can be improved: khronos uses info.n = normalize(mat3(t, b, ng) * info.ntex);
	// vs mikktspace (vNout = normalize( vNt.x * vT + vNt.y * vB + vNt.z * vN ); see http://www.mikktspace.com/. 
	
	// Christian Schuler Method (left in for comparison testing or for use by modders)
	/*const float3 P = position_w;
	const float3 N = normalize(normal_w);
	
	// get edge vectors of the pixel triangle
	const float3 dp1 = ddx(P);
	const float3 dp2 = ddy(P);
	const float2 duv1 = ddx(uv);
	const float2 duv2 = ddy(uv);

	// solve the linear system
	const float3 dp2perp = cross(dp2, N);
	const float3 dp1perp = cross(N, dp1);	
	float3 T = dp2perp * duv1.x + dp1perp * duv2.x;
	float3 B = dp2perp * duv1.y + dp1perp * duv2.y;	
	
	// construct a scale-invariant frame
	const float invmax = rsqrt(max(dot(T, T), dot(B, B)));	
	T *= invmax;
	B *= invmax;
	
	// Tangent/BiTangent/Normal as Right/Up/Forward.
	return float3x3(T,B,N);*/
	
	// #sins2_normals_and_tangents
	// Tangent/BiTangent/Normal as Right/Up/Forward.
	
	// #mikktspace_decoding
	// do not normalize! mikktspace requires normal_w and tangent_w to be in their interpolated form - not normalized.
	const float3 bitangent_w = fsign * cross(normal_w, tangent_w);	
	return normalize(normal_t.x * tangent_w + normal_t.y * bitangent_w + normal_t.z * normal_w);
}

float3 get_normal_t_uncompressed(float2 normal_t_sample)
{
	// #explanation_for_modders:
	// #sins2_normals_and_tangents
	// The normal is stored in tangent space but needs to be decompressed from a 2 channel BC5_SNORM texture.
	// The original png(unorm) would have encoded 0..1 with color values of 128..255. -1..0 would be 0..127.
	// So the default texture which has normal straight up would be (0,0,1) mapped to (r=128, g=128, b=255).
	// BC5_SNORM compresses this such that only x and y are stored across all bits for fidelity.
	// snorm->unorm: .5x + .5
	// unorm->snorm: 2x - 1
	// Due to how snorm sampling works, r and g will already be back in signed form when sampled so we don't need to manually compute (2x - 1).
	// Example: If the texture shows 152 as the color, the sample here will produce (152/255)*2-1 = 49/255 = .192f.
	// We recover z via pythagoras (implemented with a dot product) which also means we don't need to normalize.
	float3 normal_t;
	normal_t.x = normal_t_sample.x; // right/tangent
	normal_t.y = normal_t_sample.y; // up/bitangent
	normal_t.z = sqrt(max(0.f, 1.f - dot(normal_t.xy, normal_t.xy)));	// forward/normal
	
	return normal_t;
}

float4 get_normal_t_debug(float2 normal_t_sample)
{
	// #sins2_normals_and_tangents
	const float3 normal_t = get_normal_t_uncompressed(normal_t_sample);
		
	//construct normal_t so it matches the source png normal map
	const float3 normal_unorm = normal_t * .5f + .5f; // srgb->unorm
	const float3 normal_unorm_linear = srgb_to_linear(normal_unorm); // otherwise washed out
	return float4(normal_unorm_linear, 1.f);
}

float3 get_perturbed_normal_w_from_normal_map(float3 position_w, float3 normal_w, float3 tangent_w, float fsign, float2 uv, float2 normal_t_sample)
{
	// #sins2_normals_and_tangents
	const float3 normal_t = get_normal_t_uncompressed(normal_t_sample);	
	return get_perturbed_normal_w(position_w, normal_w, tangent_w, fsign, uv, normal_t);	
}