cbuffer skybox_scene_cb_data : register(b0)
{
	float4x4 view;
	float4x4 view_inverse;
	float4x4 projection_inverse;
	float time;
	float3 skybox_scene_cb_data_padding;
};