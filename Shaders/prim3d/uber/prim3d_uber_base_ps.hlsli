#define UBER
#define PRIM3D_SIMPLE
#define ADD_BASE_TEXTURES
#define USE_REFRACTION

#include "..\prim3d_basic_cb_data.hlsli"

// todo #uber: unify planet/star noise with this
struct prim3d_noise_cb_data
{
	float u_pan_speed;
	float v_pan_speed;
	float u_scale;
	float v_scale;
	float global_scale;
	float3 noise_constants_padding;
};

struct prim3d_gradient_cb_data
{
	float gradient_pan_start;
	float3 gradient_constants_padding;
};

struct prim3d_erosion_cb_data
{
	prim3d_noise_cb_data noise_constants_0;
	prim3d_noise_cb_data noise_constants_1;
	float erosion_test;
	float erosion_softness;
	float erosion_depth_fade_opacity;
	float erosion_depth_fade_distance;
};

struct prim3d_noise_combine_cb_data
{
	prim3d_noise_cb_data noise_constants_0;
	prim3d_noise_cb_data noise_constants_1;
	float combine_weight_0;
	float combine_weight_1;
	float u_strength;
	float v_strength;
};

cbuffer prim3d_uber_cb_data : register(b1)
{
	prim3d_basic_cb_data basic_constants_0;
	prim3d_gradient_cb_data gradient_constants_0;
	prim3d_erosion_cb_data erosion_constants_0;
	prim3d_noise_combine_cb_data distortion_constants_0;
	prim3d_noise_combine_cb_data refraction_constants_0;
};

Texture2DMS<float> depth_texture : register(t0);
Texture2D base_texture_0 : register(t1);
Texture2D base_texture_1 : register(t2);
Texture2D gradient_texture : register(t3);
Texture2D distortion_texture : register(t4);
Texture2D erosion_texture : register(t5);
Texture2D refraction_texture : register(t6);
Texture2D refraction_mask_texture : register(t7);
Texture2D noise_texture : register(t8);

float2 get_noise_result(
	Texture2D texture_to_sample,
	SamplerState texture_sampler,
	float2 start_texcoord,
	float2 texcoord_offset,
	prim3d_noise_cb_data nc,
	float2 noise_offset,
	float time)
{
	//pan
	float2 texcoord = start_texcoord + time * float2(nc.u_pan_speed, nc.v_pan_speed);

	//scale
	texcoord *= float2(nc.u_scale, nc.v_scale) * nc.global_scale;

	//random
	texcoord += noise_offset;

	//external offset
	texcoord += texcoord_offset;

	//sample
	const float2 noise_result = texture_to_sample.Sample(texture_sampler, texcoord).rg;
	return noise_result;
}

float2 get_noise_combine_1x_result_with_bias(Texture2D texture_to_sample, SamplerState texture_sampler, float2 start_texcoord, prim3d_noise_combine_cb_data nc, float noise_scalar, float time)
{
	const float2 noise_sample = get_noise_result(texture_to_sample, texture_sampler, start_texcoord, 0.f, nc.noise_constants_0, 0.f, time);
	const float2 noise_scaled = noise_sample * float2(nc.u_strength, nc.v_strength);
	const float2 noise_biased = noise_scaled * 2.f - 1.f; // bias to get 0..1 -> -1..1
	const float2 noise_result = noise_biased * noise_scalar;
	return noise_result;
}

float2 get_noise_combine_2x_result_base(Texture2D texture_to_sample, SamplerState texture_sampler, float2 start_texcoord, prim3d_noise_combine_cb_data nc, float time)
{
	const float2 noise_sample_0 = get_noise_result(texture_to_sample, texture_sampler, start_texcoord, 0.f, nc.noise_constants_0, 0.f, time);
	const float2 noise_sample_1 = get_noise_result(texture_to_sample, texture_sampler, start_texcoord, 0.f, nc.noise_constants_1, 0.f, time);

	const float2 noise_combined_and_scaled =
		(noise_sample_0 * nc.combine_weight_0) *
		(noise_sample_1 * nc.combine_weight_1) *
		float2(nc.u_strength, nc.v_strength);

	return noise_combined_and_scaled;
}

float2 get_noise_combine_2x_result_with_bias(Texture2D texture_to_sample, SamplerState texture_sampler, float2 start_texcoord, prim3d_noise_combine_cb_data nc, float combined_noise_scalar, float time)
{
	const float2 noise_combined_and_scaled = get_noise_combine_2x_result_base(texture_to_sample, texture_sampler, start_texcoord, nc, time);
	const float2 noise_biased = noise_combined_and_scaled * 2.f - 1.f; // bias to get 0..1 -> -1..1
	const float2 noise_result = noise_biased * combined_noise_scalar;
	return noise_result;
}

float2 get_noise_combine_2x_result_without_bias(Texture2D texture_to_sample, SamplerState texture_sampler, float2 start_texcoord, prim3d_noise_combine_cb_data nc, float combined_noise_scalar, float time)
{
	const float2 noise_combined_and_scaled = get_noise_combine_2x_result_base(texture_to_sample, texture_sampler, start_texcoord, nc, time);
	const float2 noise_result = noise_combined_and_scaled * combined_noise_scalar;
	return noise_result;
}

#include "..\prim3d_rect_ps.hlsli"

