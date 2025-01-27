#ifndef __MATH_UTILITY_H__
#define __MATH_UTILITY_H__

static const float math_pi = 3.141592653589793f;
static const float math_two_pi = 6.283185307179586f;
static const float math_half_pi = 1.570796326794896f;
static const float math_half_pi_rcp = 0.663661977236758f;
static const float float_max = 3.402823466e+38F;
static const float float_min = 1.175494351e-38F;

float3x3 get_rotation(float4x4 m)
{
	return float3x3(
		m._11, m._12, m._13, // right
		m._21, m._22, m._23, // up 
		m._31, m._32, m._33 // forward
	);
}

float3 get_right(float3x3 m)
{
	return float3(m._11, m._12, m._13);
}

float3 get_up(float3x3 m)
{
	return float3(m._21, m._22, m._23);
}

float3 get_forward(float3x3 m)
{
	return float3(m._31, m._32, m._33);
}

float3 get_right(float4x4 m)
{
	return get_right(get_rotation(m));
}

float3 get_up(float4x4 m)
{
	return get_up(get_rotation(m));
}

float3 get_forward(float4x4 m)
{
	return get_forward(get_rotation(m));
}
 
float linear_step(float min, float max, float value)
{
	return saturate((value - min) / (max - min));
}

float3 get_closest_point_on_line(float3 a, float3 b, float3 p)
{
	const float3 ap = p - a;
	const float3 ab = b - a;

	const float ab_2 = dot(ab, ab);
	const float projection = dot(ap, ab);
	const float t = projection / (ab_2 + .001f);

	if (t < 0)
	{
		return a;
	}
	else if (t > 1)
	{
		return b;
	}
	else
	{
		return a + ab * t;
	}
}

float get_distance_to_line(float3 a, float3 b, float3 p)
{
	const float3 closest_point = get_closest_point_on_line(a, b, p);
	return length(p - closest_point);
}

bool get_ray_sphere_intersection(float3 ray_start, float3 ray_dir, float3 sphere_center, float sphere_radius, inout float t)
{
	//https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
	//https://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-sphere-intersection
	float3 oc = ray_start - sphere_center;
	float a = dot(ray_dir, ray_dir);
	float b = 2.f * dot(oc, ray_dir);
	float c = dot(oc, oc) - sphere_radius * sphere_radius;
	float d = b * b - 4.f * a * c;

	// solve quadratic: optimized for this particular usage.
	// ignore single point of contact with the >= 0.f check (as opposed to > 0.f).
	// avoids d == 0 handling and ignores calculation of t1.
	// may need a different get_ray_sphere_intersection using a generic solve_quadratic function if future usage scenarios need it.
	if (d >= 0.0)
	{
		const float two_a = 2.f * a;
		const float sqrt_d = sqrt(d);
		float r0 = (-b - sqrt_d) / (two_a);
		float r1 = (-b + sqrt_d) / (two_a);
		t = min(r0, r1);
		//if ever needed in the future: const float t1 = max(r0, r1);

		return t >= 0.f;
	}
	else
	{
		return false;
	}
}

float3 project(float3 u, float v)
{
	return v * dot(u, v) / length(v);
}

float2 sample_cube(const float3 v)
{
	// derived internally but prefer the structure from:
	// https://www.gamedev.net/forums/topic/687535-implementing-a-cube-map-lookup-function/5337472/
	// note the float2 returned is already normalized

	float3 vAbs = abs(v);
	float ma;
	float2 uv;
	if(vAbs.z >= vAbs.x && vAbs.z >= vAbs.y)
	{
		//faceIndex = v.z < 0.0 ? 5.0 : 4.0;
		ma = 0.5 / vAbs.z;
		uv = float2(v.z < 0.0 ? -v.x : v.x, -v.y);
	}
	else if(vAbs.y >= vAbs.x)
	{
		//faceIndex = v.y < 0.0 ? 3.0 : 2.0;
		ma = 0.5 / vAbs.y;
		uv = float2(v.x, v.y < 0.0 ? -v.z : v.z);
	}
	else
	{
		//faceIndex = v.x < 0.0 ? 1.0 : 0.0;
		ma = 0.5 / vAbs.x;
		uv = float2(v.x < 0.0 ? v.z : -v.z, -v.y);
	}
	return uv * ma + 0.5;
}

float float_mod(float x, float y)
{
	// this form is the same as GLSL which is more useful than HLSL's fmod
	return x - y * floor(x / y);
}

float3 float_mod(float3 x, float3 y)
{
	// this form is the same as GLSL which is more useful than HLSL's fmod
	return x - y * floor(x / y);
}

float snoise(float3 uv, float res)
{
	// adapted from https://www.shadertoy.com/view/lsf3RH by trisomie21. 
	// not currently used, should be removed after cross-testing.
	// didn't meet our needs. ended up data driving a proper noise texture.
	const float3 s = float3(1e0, 1e2, 1e3);

	uv *= res;

	float3 uv0 = floor(float_mod(uv, res)) * s;
	float3 uv1 = floor(float_mod(uv + float3(1.f, 1.f, 1.f), res)) * s;

	float3 f = frac(uv); f = f * f * (3.0 - 2.0 * f);

	float4 v = float4(uv0.x + uv0.y + uv0.z, uv1.x + uv0.y + uv0.z,
		uv0.x + uv1.y + uv0.z, uv1.x + uv1.y + uv0.z);

	float4 r = frac(sin(v * 1e-1) * 1e3);
	float r0 = lerp(lerp(r.x, r.y, f.x), lerp(r.z, r.w, f.x), f.y);

	r = frac(sin((v + uv1.z - uv0.z) * 1e-1) * 1e3);
	float r1 = lerp(lerp(r.x, r.y, f.x), lerp(r.z, r.w, f.x), f.y);

	return lerp(r0, r1, f.z) * 2. - 1.;
}

bool is_near_using_distance(float x, float y, float tol)
{
	return abs(x - y) < tol;
}

bool is_near_using_percent(float x, float y, float percent_tolerance)
{
    if (y == 0.0f)
    {
        return x == 0.0f;
    }
    
    float percent_diff = abs(x - y) / abs(y);
    return percent_diff <= abs(percent_tolerance);
}

float2 get_screen_space_position_in_pixels(float3 world_position, float4x4 camera_view_projection, float2 screen_resolution)
{
	// transform the object's position to clip space
    const float4 clip_space_position = mul(float4(world_position, 1.0), camera_view_projection);

	// convert to -1..1 range and then clamp to keep values inside that
    float3 ndc_position = clip_space_position.xyz / clip_space_position.w;
	//ndc_position.xy = clamp(ndc_position.xy, float2(-1.0, -1.0), float2(1.0, 1.0));

	//convert to 0..1 space which is essentially a percentage of the total pixels in width and height respectively
	float2 screen_space_position;
    screen_space_position.x = (ndc_position.x + 1.f) * .5f * screen_resolution.x;
    screen_space_position.y = (1.f - ndc_position.y) * .5f * screen_resolution.y;

	return screen_space_position;
}

float get_screen_space_radius_in_pixels(float3 world_position, float radius, float4x4 camera_view_projection, float2 screen_resolution)
{
    // calculate the position of a point on the surface of the sphere
    const float3 offset_position = world_position + float3(radius, 0.f, 0.f);

	const float2 sphere_center_position = get_screen_space_position_in_pixels(world_position, camera_view_projection, screen_resolution);
	const float2 sphere_edge_position = get_screen_space_position_in_pixels(offset_position, camera_view_projection, screen_resolution);

    const float screen_space_radius_in_pixels = length(sphere_center_position.xy - sphere_edge_position.xy);
    
	return screen_space_radius_in_pixels;
}

#endif
