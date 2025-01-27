#include "prim3d_basic_cb_data.hlsli"

cbuffer prim3d_planet_corona_cb_data : register(b1)
{
	prim3d_basic_cb_data basic_constants_0;
	float3 corona_position;
	float corona_radius;
	float corona_curvature_bleed_distance;	
	float2 prim3d_planet_corona_cb_data_padding;
};

Texture2DMS<float> depth_texture : register(t0);
Texture2D base_texture_0 : register(t1);
Texture2D base_texture_1 : register(t2);
Texture2D noise_texture : register(t3);

#define PLANET_CORONA
#define PRIM3D_COMPLEX // this is needed to get access to two texcoords
#include "prim3d_rect_ps.hlsli"