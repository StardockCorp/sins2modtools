float2 ApplyParallax(
    float2 uv,
    float3 view_dir_tangent,
    float view_z,
    Texture2D orm_tex,
    Texture2D mask_tex,
    SamplerState wrap_sampler,
    float parallax_factor,
    float gray_center,
    float gray_soft_range,
    float gray_flat_threshold,
    int base_steps,
    int max_steps
)
{
    float raw_alpha = orm_tex.SampleLevel(wrap_sampler, uv, 0).a;
    float emissive = mask_tex.SampleLevel(wrap_sampler, uv, 0).b;

    // Only raw_alpha defines depth — emissive is ignored
    float combined_alpha = raw_alpha;

    float gray_weight = saturate(abs(combined_alpha - gray_center) / gray_soft_range);
    float fade = saturate((gray_weight - gray_flat_threshold) / (1.0 - gray_flat_threshold));
    if (fade <= 0.0f) return uv;

    uint tex_w, tex_h;
    orm_tex.GetDimensions(tex_w, tex_h);
    float2 texel_size = 0.2f / float2(tex_w, tex_h);

    float2 curr_uv = uv;
    float2 prev_uv = uv;
    float curr_depth = 0.0f;
    float prev_depth = 0.0f;

    float adjusted_alpha = pow(raw_alpha, 0.5f);
    float curr_height = 1.0f - adjusted_alpha + 0.04f;
    float prev_height = curr_height;

    float seam_fade = smoothstep(0.0f, 0.02f, min(uv.y, 1.0f - uv.y));
    float perpendicular_fade = smoothstep(0.015f, 0.15f, view_z);
    float glancing_boost = 1.0f + pow(1.0f - view_z, 3.0f) * 1.25f;

    float height_scale = 0.03f * perpendicular_fade * glancing_boost * seam_fade * fade * parallax_factor;

    int num_steps = max(base_steps, lerp(base_steps, max_steps, pow(1.0f - view_z, 2.0f)));
    float2 delta_uv = -view_dir_tangent.xy / (view_z + 1e-5f) * (height_scale / num_steps);
    float step_size = 1.0f / num_steps;

    [loop]
    for (int i = 0; i < num_steps; ++i)
    {
        curr_uv += delta_uv;
        curr_uv.y = clamp(curr_uv.y, texel_size.y, 1.0f - texel_size.y);

        float a = orm_tex.SampleLevel(wrap_sampler, curr_uv, 0).a;
        float weight = saturate(abs(a - gray_center) / gray_soft_range);
        if (weight < 0.3f) break;

        curr_height = 1.0f - pow(a, 0.5f);
        float dynamic_bias = lerp(0.0005f, 0.002f, saturate(view_z * 5.0f));
        if (curr_height + dynamic_bias < curr_depth) break;

        prev_uv = curr_uv;
        prev_depth = curr_depth;
        prev_height = curr_height;
        curr_depth += step_size;
    }

    for (int j = 0; j < 4; ++j)
    {
        float2 mid_uv = 0.5f * (prev_uv + curr_uv);
        mid_uv.y = clamp(mid_uv.y, texel_size.y, 1.0f - texel_size.y);

        float a_mid = orm_tex.SampleLevel(wrap_sampler, mid_uv, 0).a;
        float h_mid = 1.0f - pow(a_mid, 0.5f);
        float d_mid = 0.5f * (prev_depth + curr_depth);

        if (h_mid < d_mid)
        {
            curr_uv = mid_uv;
            curr_depth = d_mid;
            curr_height = h_mid;
        }
        else
        {
            prev_uv = mid_uv;
            prev_depth = d_mid;
            prev_height = h_mid;
        }
    }

    float blend_weight = (prev_height - prev_depth) / ((prev_height - prev_depth) + (curr_depth - curr_height) + 1e-5f);
    return lerp(prev_uv, curr_uv, saturate(blend_weight));
}
