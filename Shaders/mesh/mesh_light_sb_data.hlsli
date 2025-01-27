#define MESH_LIGHT_TYPE_POINT_FINITE 0
#define MESH_LIGHT_TYPE_POINT_INFINITE 1
#define MESH_LIGHT_TYPE_CONE 2
#define MESH_LIGHT_TYPE_LINE 3

struct mesh_light_sb_data
{	
	float4 color;
	float intensity;
	float surface_radius;
	float angle;
	float attenuation_radius;
	float3 position;	
	uint type;
	float3 direction;
	float length;
};