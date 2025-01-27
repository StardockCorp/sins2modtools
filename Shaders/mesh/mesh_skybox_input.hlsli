struct mesh_skybox_vs_input
{
    float3 position : POSITION;
    float2 texcoord0 : TEXCOORD0;
    float2 texcoord1 : TEXCOORD1;
};

struct mesh_skybox_ps_input
{
	float4 position_h : SV_POSITION;
	float2 texcoord0 : TEXCOORD0;
};
