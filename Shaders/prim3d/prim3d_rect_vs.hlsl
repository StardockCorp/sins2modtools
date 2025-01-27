#include "prim3d_vs_input.hlsli"
#include "prim3d_ps_input.hlsli"
#include "prim3d_scene_cb_data.hlsli"
#include "../color_utility.hlsli"

prim3d_ps_input main(prim3d_vs_input input)
{
	prim3d_ps_input output;
	output.position_h = mul(float4(input.position, 1.0f), view_projection);
	output.position_v = mul(float4(input.position, 1.0f), view);
	output.position_w = input.position;
	
	#if defined(PRIM3D_COMPLEX)
		const float4 color_0 = float4(input.color0.rgb, input.color_alphas.x);
		const float4 color_1 = float4(input.color1.rgb, input.color_alphas.y);
		output.color0 = srgb_to_linear(color_0);
		output.color1 = srgb_to_linear(color_1);
		output.texcoord0 = input.texcoord0;
		output.texcoord1 = input.texcoord1;
	#elif defined(PRIM3D_SIMPLE)
		const float4 color_0 = float4(input.color0.rgb, input.color_0_alpha);
		output.color0 = srgb_to_linear(color_0);
		output.texcoord0 = input.texcoord0;
		output.erosion_factors = input.erosion_factors;
		output.gradient_and_distortion_and_refraction_factors = input.gradient_and_distortion_and_refraction_factors;
	#endif
	return output;
}
