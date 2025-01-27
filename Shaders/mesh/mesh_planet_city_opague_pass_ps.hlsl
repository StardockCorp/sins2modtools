#define RESTRICT_EMISSIVE_TO_DARK_SIDE
#define MASK_CITY_LEVEL
#define ENABLE_EMISSIVE
#define ENABLE_OPAGUE_PASS

cbuffer planet_city_cb_data : register(b6)
{
	float max_city_level;
	float3 planet_city_cb_data_padding;
};

#include "mesh_pbr_ps.hlsli"