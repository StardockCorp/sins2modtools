#ifndef __PRIM2D_INPUT_HLSLI__
#define __PRIM2D_INPUT_HLSLI__

struct prim2d_vs_input
{
	float3 position : POSITION;	
	float4 color : COLOR;		
    float color_alpha : TEXCOORD0;
    float2 texcoord : TEXCOORD1;
};

struct prim2d_ps_input
{
	float4 position : SV_POSITION;	
	float4 color : COLOR;
    float2 texcoord : TEXCOORD0;
};

#endif // __PRIM2D_INPUT_HLSLI__