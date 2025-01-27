#include "prim2d_input.hlsli"

#include "../primitive_viewport_cb_data.hlsli"

prim2d_ps_input main(prim2d_vs_input input)
{
	prim2d_ps_input output;
	output.position = mul(float4(input.position.x, input.position.y, 0.0f, 1.0f), viewport_transform);
	output.position.z = input.position.z; // this has already been calculated in code (to_non_linear_depth)	
	
    const float4 color = float4(input.color.rgb, input.color_alpha);
    output.color = color;
	
	output.texcoord = input.texcoord;
	
	return output;
}
