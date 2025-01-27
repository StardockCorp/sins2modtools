struct prim3d_ps_input
{
	float4 position_h : SV_POSITION;
	float4 position_v : POSITION0;
	float3 position_w : POSITION1;
	
	#if defined(PRIM3D_COMPLEX)	
		float4 color0 : COLOR0;
		float4 color1 : COLOR1;
		float3 texcoord0 : TEXCOORD0;
		float3 texcoord1 : TEXCOORD1;		
	#elif defined(PRIM3D_SIMPLE)
		float4 color0 : COLOR0;
		float2 texcoord0 : TEXCOORD0;
		float3 erosion_factors : TEXCOORD1;
		float3 gradient_and_distortion_and_refraction_factors : TEXCOORD2;
	#endif	
};