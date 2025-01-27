#include "prim2d_input.hlsli"

Texture2D texture_0 : register( t0 );
SamplerState sampler_0 : register( s0 );

float4 main(prim2d_ps_input input) : SV_TARGET 
{
	return texture_0.Sample(sampler_0, input.texcoord) * input.color;
}
