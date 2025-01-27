#include "exposure_state_sb_data.hlsli"

RWStructuredBuffer<exposure_state_sb_data> exposure : register(u0);

[numthreads(1, 1, 1)]
void main(uint GI : SV_GroupIndex)
{
	exposure[0].exposure = 1.f;
	exposure[0].exposure_rcp = 1.f;
}
