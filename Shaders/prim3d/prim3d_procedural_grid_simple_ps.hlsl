#define PRIM3D_SIMPLE

#include "prim3d_ps_input.hlsli"

struct ps_output
{
	float4 scene_color : SV_TARGET0;
	float4 emissive_color : SV_TARGET1;
	float4 refraction_offset : SV_TARGET2;
};

ps_output main(prim3d_ps_input input)
{
	ps_output output;
	output.refraction_offset = float4(0.f, 0.f, 0.f, 0.f);

	// Grid parameters from vertex data
	float grid_spacing = input.texcoord0.x;
	float gravity_well_radius = input.texcoord0.y;
	float line_thickness = input.erosion_factors.x;
	float2 inner_circle_offset = input.erosion_factors.yz;
	float2 center_pos = input.gradient_and_distortion_and_refraction_factors.xy;
	float inner_circle_radius = input.gradient_and_distortion_and_refraction_factors.z;

	// World position of this pixel (camera-relative)
	float3 world_pos = input.position_w;

	// Position relative to gravity well center (stable regardless of camera position)
	float2 pos_from_center = world_pos.xz - center_pos;
	float dist_from_center = length(pos_from_center);

	// Calculate grid pattern relative to gravity well center (not camera)
	float2 grid_frac = abs(frac(pos_from_center / grid_spacing) - 0.5f) * 2.0f;

	// Distance to nearest grid line
	float dist_to_line = min(grid_frac.x, grid_frac.y) * grid_spacing;

	// Anti-aliased line using smoothstep
	float half_thickness = line_thickness * 0.5f;
	float line_alpha = 1.0f - smoothstep(0.0f, half_thickness, dist_to_line);

	// Gradual fade at the outer edge of the gravity well
	float outer_fade_start = gravity_well_radius * 0.5f;
	float outer_fade_end = gravity_well_radius * 0.95f;
	float edge_fade = 1.0f - smoothstep(outer_fade_start, outer_fade_end, dist_from_center);
	edge_fade = edge_fade * edge_fade; // Square for more natural falloff

	// Inner circle (planet area) - scale ring thickness based on planet/well ratio
	float inner_fade = 1.0f;
	float inner_ring_alpha = 0.0f;
	if(inner_circle_radius > 0.0f)
	{
		float2 pos_from_inner = pos_from_center - inner_circle_offset;
		float dist_from_inner = length(pos_from_inner);

		// Scale ring thickness based on inner circle size
		float inner_ring_thickness = max(line_thickness, inner_circle_radius * 0.02f);

		// Hard cutout - grid terminates at inner circle radius
		inner_fade = step(inner_circle_radius, dist_from_inner);

		// Draw a ring at the inner circle boundary
		float ring_dist = abs(dist_from_inner - inner_circle_radius);
		inner_ring_alpha = 1.0f - smoothstep(0.0f, inner_ring_thickness * 0.5f, ring_dist);
	}

	// Combine grid lines with edge fades
	float grid_alpha = line_alpha * edge_fade * inner_fade;

	// Add inner ring (also affected by outer edge fade)
	float final_alpha = max(grid_alpha, inner_ring_alpha * edge_fade) * input.color0.a;

	// Output
	output.scene_color = float4(input.color0.rgb, final_alpha);
	output.emissive_color = float4(0.f, 0.f, 0.f, 0.f);

	// Discard transparent pixels
	clip(final_alpha - 0.001f);

	return output;
}
