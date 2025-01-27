struct mesh_shadow_blocker_ps_input
{
	float4 position_h : SV_POSITION;
	float depth : POSITION0; //zw is stored in xy
};
