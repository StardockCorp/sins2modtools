#include "aa_cb_data.hlsli"

cbuffer aa_blend_weight_cb_data : register(b1)
{
	float4 subsample_indices;
};

#define SMAA_HLSL_4_1
#define SMAA_PRESET_ULTRA

#include "../external/smaa/smaa.hlsl"

Texture2D edges_texture : register(t0);
Texture2D area_texture : register(t1);
Texture2D search_texture : register(t2);

float4 main(
	float4 position : SV_Position,
	float2 texcoord : TexCoord0,
	float2 pixcoord : TexCoord1,
	float4 offset[3] : TexCoord2) : SV_TARGET
{
	return SMAABlendingWeightCalculationPS(texcoord, pixcoord, offset, edges_texture, area_texture, search_texture, subsample_indices);
}
