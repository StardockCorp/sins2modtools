cbuffer mesh_material_cb_data : register(b2)
{
	float4 base_color_factor;	
	float4 roughness_metallic_emissive_factors;
	float parallax_factor;
	float3 mesh_material_cb_data_padding;
};
