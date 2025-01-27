#include "aa_cb_data.hlsli"

#define SMAA_HLSL_4_1
#define SMAA_PRESET_ULTRA

#include "../external/smaa/smaa.hlsl"

Texture2DMS<float4, 2> color_ms_texture : register(t0);

struct ps_output
{
	float4 color_texture_0 : SV_TARGET0;
	float4 color_texture_1 : SV_TARGET1;
};

ps_output main(
	float4 position : SV_Position,
	float2 texcoord : TexCoord0)
{
	ps_output output;
	SMAASeparatePS(position, texcoord, output.color_texture_0, output.color_texture_1, color_ms_texture);
	return output;
}
