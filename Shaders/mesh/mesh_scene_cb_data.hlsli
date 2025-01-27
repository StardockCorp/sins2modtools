cbuffer mesh_scene_cb_data : register(b0)
{
	float4x4 view;
	float4x4 view_projection;
	float4 camera_position;
	float time;
	float3 mesh_scene_cb_data_padding;
};
