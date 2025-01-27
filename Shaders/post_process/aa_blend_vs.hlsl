#include "aa_cb_data.hlsli"

#define SMAA_HLSL_4_1
#define SMAA_PRESET_ULTRA

#include "../external/smaa/smaa.hlsl"

void main(
	in uint VertID : SV_VertexID,
	out float4 position : SV_Position,
	out float2 texcoord : TexCoord0,
    out float4 offset : TexCoord1)
{
	//see present_screen_quad_vs.hlsl to explain where texcoord and position come from
	texcoord = float2((VertID << 1) & 2, VertID & 2);
	position = float4(texcoord.x * 2 - 1, -texcoord.y * 2 + 1, 0, 1);	
	SMAANeighborhoodBlendingVS(texcoord, offset);
}
