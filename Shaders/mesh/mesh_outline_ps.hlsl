#include "mesh_ps_input.hlsli"
#include "mesh_scene_cb_data.hlsli" // required by sharing of root_signature (even though not used by this shader)
#include "mesh_outline_instance_cb_data.hlsli"
#include "../post_process/exposure_state_sb_data.hlsli"

struct mesh_outline_ps_output
{
    float outline_id : SV_TARGET0;
    float4 outline_color : SV_TARGET1;
};

StructuredBuffer<exposure_state_sb_data> exposure : register(t0);

mesh_outline_ps_output main(mesh_ps_input input)
{
    mesh_outline_ps_output output;
    output.outline_id = outline_id;
    
    //outline buffer is not subject to hrd or srgb ramp so needs no conversion
    output.outline_color = outline_color; 
    
    // disable exposure on outlines. more of a UI element which never mutates player colors
	output.outline_color.rgb *= exposure[0].exposure_rcp;
   
    return output;
}
