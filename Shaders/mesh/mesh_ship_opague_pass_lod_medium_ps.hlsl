#define ENABLE_SHADOWS
#define ENABLE_KEY_FILL_RIM_LIGHT_ANGLES
#define ENABLE_EMISSIVE
#define ENABLE_PLAYER_COLOR
#define ENABLE_OPAGUE_PASS

// optimization: medium LOD - disable flow maps for medium distance meshes
// #define ENABLE_FLOW_MAP
#define ENABLE_TOON_SHADING
#define ENABLE_PARALLAX_OCCLUSION

// optimization: limit max lights processed for medium distance meshes
#define LOD_MAX_LIGHTS_PER_PIXEL 128

#include "mesh_player_color_cb_data.hlsli"
#include "mesh_pbr_ps.hlsli"
