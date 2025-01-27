// grep on set_ps_samplers to see where these are set
SamplerState mesh_anisotropic_wrap_sampler : register(s0);
SamplerState mesh_anisotropic_clamp_sampler : register(s1);
SamplerState mesh_point_clamp_sampler : register(s2);
SamplerState mesh_linear_clamp_sampler : register(s3);