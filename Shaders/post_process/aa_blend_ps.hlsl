#include "aa_cb_data.hlsli"

#define SMAA_HLSL_4_1
#define SMAA_PRESET_ULTRA

#include "../external/smaa/smaa.hlsl"

Texture2D color_texture : register(t0);
Texture2D blend_weights_texture : register(t1);

float4 main(
	float4 position : SV_Position,
	float2 texcoord : TexCoord0,    
	float4 offset : TexCoord1) : SV_TARGET
{
	return SMAANeighborhoodBlendingPS(texcoord, offset, color_texture, blend_weights_texture);
}
