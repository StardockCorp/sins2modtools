cbuffer post_process_cb_data : register(b0)
{
	float2 scene_texel_size;
	float bloom_strength;
	float time;
};