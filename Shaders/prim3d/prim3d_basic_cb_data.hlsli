// this doesn't have a register because it needs to be shared in prim3d_uber_cb_data and prim3d_rect_ps
struct prim3d_basic_cb_data 
{
	float emissive_factor;
	float depth_fade_opacity;
	float depth_fade_distance;
	float alpha_ramp_curvature;
	float alpha_ramp_steepness;
	float alpha_ramp_growth_delay;
	float alpha_ramp_max_alpha_scalar;
	float prim3d_basic_cb_data_padding;
};