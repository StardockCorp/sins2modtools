#ifndef __PRIM2D_LINES_INPUT_HLSLI__
#define __PRIM2D_LINES_INPUT_HLSLI__

struct prim2d_lines_vs_input
{
	float3 position : POSITION;
	float4 color : COLOR;	
	float color_alpha : TEXCOORD0;
};

struct prim2d_lines_ps_input
{
	float4 position : SV_POSITION;
	float4 color : COLOR;
};

#endif // __PRIM2D_LINES_INPUT_HLSLI__