struct mesh_ps_input
{
	float4 position_h : SV_POSITION;
	float3 position_v : POSITION0;
	float3 position_w : POSITION1;
	float3 position_l : POSITION2;
	float3 normal_w : NORMAL;
	float3 tangent_w : TANGENT;	
	float fsign : TEXCOORD0; // #mikktspace_decoding
	float2 texcoord0 : TEXCOORD1;
	float2 texcoord1 : TEXCOORD2;
#ifdef ENABLE_SHADOWS
	float3 shadow_map_uvz[shadow_map_count] : TEXCOORD3;
#endif
};
