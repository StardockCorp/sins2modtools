Texture2D ColorTex : register(t0);
SamplerState Sampler : register(s0);

#include "color_blindness_utility.hlsli"

cbuffer color_blindness_cb_data : register(b0)
{
    uint color_blindness_mode_value;
    float3 padding;
};

float3 srgb_to_linear(float3 srgb)
{
    return pow(max(srgb, 0.0), 2.2);
}

float3 linear_to_srgb(float3 linear_rgb)
{
    return pow(max(linear_rgb, 0.0), 1.0 / 2.2);
}

float4 main( float4 position : SV_Position, float2 uv : TexCoord0 ) : SV_Target0
{
    float4 color = ColorTex.Sample(Sampler, uv, 0);

    // Apply color blindness transformation in linear space
    color.rgb = srgb_to_linear(color.rgb);
    color.rgb = apply_color_blindness(color.rgb, color_blindness_mode_value);
    color.rgb = linear_to_srgb(color.rgb);

    return color;
}
