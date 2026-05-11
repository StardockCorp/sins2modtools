#define ENABLE_SHADOWS
#define ENABLE_KEY_FILL_RIM_LIGHT_ANGLES
#define ENABLE_EMISSIVE
#define ENABLE_OPAGUE_PASS

// optimization: far LOD - disable expensive features for distant meshes
// #define ENABLE_FLOW_MAP - disabled
// #define ENABLE_PARALLAX_OCCLUSION - disabled
#define ENABLE_TOON_SHADING

// optimization: limit max lights processed and reduce IBL quality for far distance meshes
#define LOD_MAX_LIGHTS_PER_PIXEL 64
#define LOD_REDUCE_IBL_QUALITY

#include "mesh_pbr_ps.hlsli"
