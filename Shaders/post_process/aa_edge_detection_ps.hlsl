#include "aa_cb_data.hlsli"

#define SMAA_HLSL_4_1
#define SMAA_PRESET_ULTRA

#include "../external/smaa/smaa.hlsl"

Texture2D color_texture : register(t0);

float2 main(
	float4 position : SV_Position,
	float2 texcoord : TexCoord0,
	float4 offset[3] : TexCoord1) : SV_TARGET
{
	// note: smaa.hlsl only operates on the red and green channels of the edge data
	return SMAALumaEdgeDetectionPS(texcoord, offset, color_texture);	
}
