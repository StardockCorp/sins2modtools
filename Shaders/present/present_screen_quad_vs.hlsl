// Adapted from ScreenQuadPresentVS.hlsl

//
// Copyright (c) Microsoft. All rights reserved.
// This code is licensed under the MIT License (MIT).
// THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
// ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
// IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
// PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
//
// Developed by Minigraph
//
// Author:  James Stanard
//
// A vertex shader for full-screen effects without a vertex buffer.  The
// intent is to output an over-sized triangle that encompasses the entire
// screen.  By doing so, we avoid rasterization inefficiency that could
// result from drawing two triangles with a shared edge.
//
// Use null input layout
// Draw(3)

void main(
	in uint VertID : SV_VertexID,
	out float4 Pos : SV_Position,
	out float2 Tex : TexCoord0
)
{
	// Texture coordinates range [0, 2], but only [0, 1] appears on screen.
	//Tex = float2(uint2(VertID, VertID << 1) & 2);
	//Pos = float4(lerp(float2(-1, 1), float2(1, -1), Tex), 0, 1);

	// Sins2 requires us to change the winding order from the original.
	Tex = float2((VertID << 1) & 2, VertID & 2);
	Pos = float4(Tex.x * 2 - 1, -Tex.y * 2 + 1, 0, 1);

	/*
	Old					
	Vertex ID		U	V	PosX	PosY
					
	0				0	0	-1		1
	1				0	2	-1		-3
	2				2	0	3		1	

	New					
	Vertex ID		U	V	PosX	PosY
					
	0				0	0	-1		1
	1				2	0	3		1
	2				0	2	-1		-3
	*/
}
