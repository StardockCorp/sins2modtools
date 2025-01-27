#include "color_utility.hlsli"

Texture2D ColorTex : register(t0);
SamplerState Sampler : register(s0);

float4 main( float4 position : SV_Position, float2 uv : TexCoord0 ) : SV_Target0
{
    return srgb_to_linear(ColorTex.Sample(Sampler, uv, 0));    
}
