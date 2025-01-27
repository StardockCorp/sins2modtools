cbuffer aa_cb_data : register(b0)
{
	float4 SMAA_RT_METRICS;
	//defined as the following in d3d11_game_renderer:
	//float2 screen_texel_size;
	//float2 screen_size;
};