cbuffer skybox_scene_cb_data : register(b0)
{
	float4x4 skybox_view;
	float4x4 view_inverse;
	float4x4 projection_inverse;
	float current_time;
	float3 current_camera_position;
};