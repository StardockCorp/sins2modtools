// simple bilinear downsample shader for half-resolution god rays
Texture2D source_texture : register(t0);
SamplerState linear_sampler : register(s0);

struct ps_input
{
    float4 position_h : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

struct ps_output
{
    float4 color : SV_TARGET0;
};

ps_output main(ps_input input)
{
    ps_output output;
    output.color = source_texture.Sample(linear_sampler, input.texcoord);
    return output;
}
