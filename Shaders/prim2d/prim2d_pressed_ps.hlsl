#include "prim2d_input.hlsli"
#include "../color_utility.hlsli"

Texture2D texture_0 : register(t0);
SamplerState sampler_0 : register(s0);

float4 main(prim2d_ps_input input) : SV_TARGET
{
	float4 final = texture_0.Sample(sampler_0, input.texcoord) * input.color;
	
	//Decrease Lightness
	float3 hsl = rgb_to_hsl(final.rgb);
	hsl.b *= .75f;
	final.rgb = hsl_to_rgb(hsl);
	
	return final;
}
