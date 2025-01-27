#include "prim3d_lines_input.hlsli"

#include "../primitive_viewport_cb_data.hlsli"
#include "../color_utility.hlsli"

prim3d_lines_ps_input main(prim3d_lines_vs_input input)
{
	prim3d_lines_ps_input output;
	output.position = mul(float4(input.position, 1.0f), viewport_transform);
	
    const float4 color = float4(input.color.rgb, input.color_alpha);
	output.color = srgb_to_linear(color);
	return output;
}