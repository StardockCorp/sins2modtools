#define ENABLE_SHADOWS
#define RESTRICT_EMISSIVE_TO_DARK_SIDE
#define ENABLE_FLOW_MAP
#define ENABLE_PLANET_ATMOSPHERE
#define ENABLE_EMISSIVE
#define ENABLE_OPAGUE_ONLY
#define ENABLE_TOON_SHADING	

cbuffer atmosphere_cb_data : register(b6)
{	
	float4 atmosphere_color;
	float atmosphere_spread;
	float cloud_rotation_speed;
	float cloud_animation_speed;
	float cloud_noise_0_zoom;
	float cloud_noise_0_intensity;
	float cloud_noise_1_zoom;
	float cloud_noise_1_intensity;
	float planet_radius;
};

Texture2D noise_texture: register(t12);

#include "mesh_pbr_ps.hlsli"