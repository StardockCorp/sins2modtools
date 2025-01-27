cbuffer prim3d_scene_cb_data : register(b0)
{
	float4x4 view;
	float4x4 view_projection;
	float time;
	float3 light_position;
    float camera_far_z;
	float camera_far_z_times_near_z;
	float camera_far_z_minus_near_z;
	float prim3d_scene_constants_padding;
};