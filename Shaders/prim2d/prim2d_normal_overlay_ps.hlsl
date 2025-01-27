#include "prim2d_input.hlsli"

#include "../color_utility.hlsli"

Texture2D texture_0 : register( t0 );
SamplerState sampler_0 : register( s0 );

float4 main(prim2d_ps_input input) : SV_TARGET 
{
	float4 texture_color = texture_0.Sample(sampler_0, input.texcoord);
	float3 overlay_rgb = BlendMode_Overlay(texture_color.rgb, input.color.rgb);
	return float4(overlay_rgb, texture_color.a * input.color.a);
}
