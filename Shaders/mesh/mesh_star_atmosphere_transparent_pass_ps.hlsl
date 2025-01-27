#define ENABLE_STAR_ATMOSPHERE
#define ENABLE_EMISSIVE
#define ENABLE_TRANSPARENT_PASS

Texture2D noise_texture: register(t12);

#include "mesh_pbr_ps.hlsli"