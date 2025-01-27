cbuffer mesh_outline_instance_cb_data : register(b3)
{
    float4 outline_color;
    float outline_id;    
    float outline_distance_scalar;
    float2 mesh_outline_instance_constants_padding;
};
