#include "skybox_rays_cb_data.hlsli"
#include "skybox_rays_ps_input.hlsli"
#include "../color_utility.hlsli"
#include "../post_process/exposure_state_sb_data.hlsli"
#include "../external/tone_mapping_utility.hlsli"
#include "../color_utility.hlsli"

Texture2D texture_0 : register(t0);
StructuredBuffer<exposure_state_sb_data> exposure : register(t1);

struct skybox_ps_output
{
    float4 scene_color : SV_TARGET0;
};

SamplerState linear_border_sampler : register(s0);

float4 create_starbox_rays(float4 source_color, float2 uv)
{
    const float2 center = float2(.5f, .4f);
    const int sample_count = 128;
    const float sample_frequency = 1.2f;   
    const float fall_off = 1.06f;
    const float min_luminance = 0.f;
    
    const float2 sample_step_size = (uv - center) / (sample_count * sample_frequency);
        
    float3 sample_sum = 0.f;
    
    for (float i = 1; i < sample_count; i++)
    {
        const float3 sampled_pixel = texture_0.Sample(linear_border_sampler, uv - sample_step_size * i).rgb;
        const float luminance = RGBToLuminance(sampled_pixel);
        if(luminance > min_luminance)
        {            
            sample_sum += sampled_pixel / (fall_off * i);
        }
    }
    
    const float scalar = .3f;
    sample_sum *= scalar;
        
    return float4(source_color.rgb + sample_sum, 1.f);
}

skybox_ps_output main(skybox_rays_ps_input input)
{
    skybox_ps_output output;
    
    const float4 sampled_color = texture_0.Sample(linear_border_sampler, input.texcoord);    
    output.scene_color = create_starbox_rays(sampled_color, input.texcoord);
    
    output.scene_color.rgb *= exposure[0].exposure_rcp;

    float3 hsl = rgb_to_hsl(output.scene_color.rgb);
    hsl.z *= brightness_scaler;
    output.scene_color.rgb = hsl_to_rgb(hsl);

    return output;
}
