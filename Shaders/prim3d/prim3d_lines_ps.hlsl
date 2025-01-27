#include "prim3d_lines_input.hlsli"

float4 main(prim3d_lines_ps_input input) : SV_TARGET 
{
	return input.color;
}
