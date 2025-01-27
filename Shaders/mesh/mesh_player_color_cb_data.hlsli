cbuffer mesh_player_color_cb_data : register(b7)
{
	float4 player_color_primary_srgb;
	float4 player_color_secondary_srgb;
	float4 player_color_primary_emissive_srgb;
	float4 player_color_secondary_emissive_srgb;
};