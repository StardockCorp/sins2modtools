struct prim3d_vs_input
{
	float3 position : POSITION;
 
	#if defined(PRIM3D_COMPLEX)
		float4 color0 : COLOR0;
		float4 color1 : COLOR1;
		float2 color_alphas : TEXCOORD0;
		float3 texcoord0 : TEXCOORD1;
		float3 texcoord1 : TEXCOORD2;
	#elif defined(PRIM3D_SIMPLE)
		float4 color0 : COLOR0;
		float color_0_alpha : TEXCOORD0;
		float2 texcoord0 : TEXCOORD1;
	
		//rgb = erosion_test_base, erosion_noise_offset_u, erosion_noise_offset_v
		float3 erosion_factors : TEXCOORD2;
	
		//rgb = gradient_pan_offset, distortion_scalar, refraction_scalar
		float3 gradient_and_distortion_and_refraction_factors : TEXCOORD3; 
#endif
};