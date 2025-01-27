#include "prim3d_shapes_input.hlsli"

#include "../color_utility.hlsli"

cbuffer prim3d_shape_instance_cb_data : register(b0)
{
	float4x4 world_view_projection;
	float4 color;
};

prim3d_shapes_ps_input main(prim3d_shapes_vs_input input)
{
	prim3d_shapes_ps_input output;
	output.position = mul(float4(input.position, 1.0f), world_view_projection);
	output.color = srgb_to_linear(color);
	return output;
}
