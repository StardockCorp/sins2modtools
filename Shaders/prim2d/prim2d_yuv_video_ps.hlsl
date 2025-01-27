// adapted from https://chromium.googlesource.com/chromium/src.git/+/7.0.517.43/o3d/samples/shaders/yuv2rgb-glsl.shader

// which falls under the following license:

/*
 * Copyright 2009, Google Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
#include "prim2d_input.hlsli"

Texture2D texture_0 : register( t0 );
SamplerState sampler_0 : register( s0 );

float4 main(prim2d_ps_input input) : SV_TARGET 
{
	// adapted from https://chromium.googlesource.com/chromium/src.git/+/7.0.517.43/o3d/samples/shaders/yuv2rgb-glsl.shader
	float4 yuv = texture_0.Sample(sampler_0, input.texcoord);
  	float4x4 conversion = float4x4(
		1.0,  0.0,    1.402, -0.701,
		1.0, -0.344, -0.714,  0.529,
        1.0,  1.772,  0.0,   -0.886,
        0, 0, 0, 0);
	float4 rgb = mul(conversion, yuv);
	rgb.a = 1;
	return rgb;
}
