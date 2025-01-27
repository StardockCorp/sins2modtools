#ifndef __PRIM3D_SHAPES_INPUT_HLSLI__
#define __PRIM3D_SHAPES_INPUT_HLSLI__

struct prim3d_shapes_vs_input
{
	float3 position : POSITION;
};

struct prim3d_shapes_ps_input
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
};

#endif // __PRIM3D_SHAPES_INPUT_HLSLI__
