#include "prim2d_input.hlsli"
#include "../color_utility.hlsli"

Texture2D texture_0 : register(t0);
SamplerState sampler_0 : register(s0);

float4 main(prim2d_ps_input input) : SV_TARGET
{
	float4 final = texture_0.Sample(sampler_0, input.texcoord) * input.color;

	//adjust saturation - leave this commented out block in for easy testing
	//float3 hsl = rgb_to_hsl(final.rgb);
	//hsl.g *= .5f; // photoshop/gimp/paint.net hue/saturation tool acts like a scalar
	//final.rgb = hsl_to_rgb(hsl);

	//adjust output max level
	float minLevel = 30.f / 255.f;
	float maxLevel = 160.f / 255.f;
	final.rgb = LevelsControl(final.rgb, 0.f, 1.f, 1.f, minLevel, maxLevel);

	// apply BlendMode_Color
	float3 blend_color = float3(82.f / 255.f, 204.f / 255.f, 255.f / 255.f) * .20f;
	final.rgb = BlendMode_Color(final.rgb, blend_color);

	return final;
}
