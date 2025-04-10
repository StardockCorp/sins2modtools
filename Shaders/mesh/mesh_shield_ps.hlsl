#include "mesh_scene_cb_data.hlsli"
#include "mesh_samplers.hlsli"
#include "mesh_ps_input.hlsli"
#include "mesh_material_cb_data.hlsli"

#include "../color_utility.hlsli"
#include "../math_utility.hlsli"

static const float max_shield_impact_count = 50; // make sure this lines up with shield_effect_render_state::max_impact_count

struct shield_impact
{
    float4 uv_rect; // left/top/right/bottom
    float4x4 world_transform_inverse;   
    float4 color;
    float radius;	
    float time_elapsed;
    float emissive_factor;
    float shield_effect_impact_render_state_padding;
};

cbuffer shield_mesh_instance_cb_data : register(b3)
{
    shield_impact shield_impacts[max_shield_impact_count];
    uint shield_impact_count;
    float3 shield_mesh_instance_cb_data_padding;
}

Texture2D base_color_texture : register(t0);
Texture2D occlusion_roughness_metallic_texture : register(t1);
Texture2D normal_texture : register(t2);
Texture2D mask_texture : register(t3);
Texture2D impact_texture: register(t4);

float fresnel_simple_for_shield(float NdV)
{	    
    return saturate(pow(1.f - NdV, 5.f));
}

float contrast_simple_for_shield(float in_value, float contrast_value)
{
    return contrast_value * (in_value - .5f) + .5f;
}

struct ps_output
{
    float4 scene_color : SV_TARGET0;
    float4 emissive_color : SV_TARGET1;
};

ps_output main(mesh_ps_input input)
{
    float4 final_color = 0.f;
    float emissive_factor = 1.f;

    for(uint i = 0; i < shield_impact_count; i++)
    {
        const float radius = shield_impacts[i].radius;
        const float impact_width = radius * 2.f;

        const float4 pos_in_object_space = mul(float4(input.position_w, 1), shield_impacts[i].world_transform_inverse);
        const float dist = length(pos_in_object_space.xyz);                        
        if(dist < radius)
        {
            float2 uv = pos_in_object_space.xy;

            // remove stretching artifacts from extreme angles
            // https://gamedev.net/forums/topic/666883-projected-decals-stretching/5218384/
            const float3x3 impact_rotation_inverse = get_rotation(shield_impacts[i].world_transform_inverse);
            
            const float3 normal_in_object_space = mul(input.normal_w, impact_rotation_inverse);
            uv.xy -= 1.5f * pos_in_object_space.z * normal_in_object_space.xy;
                            
            // uv_rect is stored as left/top/right/bottom
            const float left = shield_impacts[i].uv_rect.x;
            const float top = shield_impacts[i].uv_rect.y;
            const float right = shield_impacts[i].uv_rect.z;
            const float bottom = shield_impacts[i].uv_rect.w;

            const float w = right - left;
            const float h = bottom - top; // top left is origin with v increasing from top to bottom
            const float u_offset = left;
            const float v_offset = top;

            const float u = ((uv.x + radius) / impact_width * w) + u_offset;
            const float v = ((uv.y + radius) / impact_width * h) + v_offset;

            if(u >= left && u <= right && v >= top && v <= bottom)
            {            
                float2 impact_texcoord = float2(u, v);
                const float4 impact_color = srgb_to_linear(impact_texture.Sample(mesh_anisotropic_clamp_sampler, impact_texcoord));

                const float4 new_color = impact_color * shield_impacts[i].color; // color was passed in linear, no need to convert from srgb
                if (new_color.a > final_color.a)
                {
                    final_color = new_color;
                    emissive_factor = shield_impacts[i].emissive_factor;

                    // fade off points opposite the impact point to minimize the mirroring effect
                    const float3 impact_normal_w = get_forward(transpose(impact_rotation_inverse));
                    const float dt = dot(input.normal_w, impact_normal_w);
                    if(dt < 0.f)
                    {   
                        final_color *= saturate(lerp(1.f, 0.f, -8.f * dt));
                    }
                }
            }
        }
    }
    
    ps_output output;
    output.scene_color = final_color;
    output.emissive_color = final_color * emissive_factor;
    return output;
}
