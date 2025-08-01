#include "skybox_ps_input.hlsli"
#include "skybox_scene_cb_data.hlsli"

#include "../mesh/mesh_scene_cb_data.hlsli"
#include "../color_utility.hlsli"
#include "../post_process/exposure_state_sb_data.hlsli"
#include "../external/tone_mapping_utility.hlsli"
 
#include "../mesh/ex_features_ps_data.hlsli"
 
TextureCube texture_0 : register(t0);
StructuredBuffer<exposure_state_sb_data> exposure : register(t1);
 
SamplerState linear_wrap_sampler : register(s0);
 
struct skybox_ps_output
{
    float4 scene_color : SV_TARGET0;
};
 
 
float3 PosterizeLightness(float3 color, float levels)
{
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    float stepped = floor(luminance * levels) / levels;
    float3 flatColor = normalize(color + 1e-5) * stepped;
    return saturate(flatColor);
}
 
 
// Manual posterization settings
static const float POSTERIZE_LEVELS = 0.1;
static const float POSTERIZE_AMOUNT = 0.1;

skybox_ps_output main(skybox_ps_input input)
{
    skybox_ps_output output;
 
    if (g_toon_enabled == 1)
    {
        float3 color = srgb_to_linear(texture_0.Sample(linear_wrap_sampler, input.position_w).rgb);
 
        // === Posterize lightness for cel-style gradient
        color = PosterizeLightness(color, 64.0); // fewer bands = flatter look
 
        // === Optional: fake rim gradient (view-aligned darkening)
        float viewAlignment = dot(normalize(input.position_w), float3(0, 0, 1)); // view-facing = 1
        float rimFade = smoothstep(-1.0, 0.2, viewAlignment);
        color *= rimFade; // fade out edges like sky rim
 
        output.scene_color = float4(saturate(color), 1.0);
        return output;
    }
    else if (g_retro_enabled == 1)
    {
        float3 dir = normalize(input.position_w); // no distortion applied
 
        float3 color = srgb_to_linear(texture_0.Sample(linear_wrap_sampler, input.position_w).rgb);
 
        float luminance = dot(color, float3(0.299, 0.587, 0.114));
        float stepped = floor(luminance * POSTERIZE_LEVELS) / POSTERIZE_LEVELS;
        float3 posterized = normalize(color + 1e-5f) * stepped;

		posterized = color * stepped;
 
        color = lerp(color, posterized, POSTERIZE_AMOUNT);
 
        output.scene_color = float4(color, 1.0);
 
		
        return output;
    }
    else
    {
        output.scene_color = srgb_to_linear(texture_0.Sample(linear_wrap_sampler, input.position_w));
    }
    return output;
}