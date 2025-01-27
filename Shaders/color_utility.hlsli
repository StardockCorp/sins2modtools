#ifndef COLOR_UTILITY
#define COLOR_UTILITY

#include "external/color_space_utility.hlsli"
#include "external/photoshop_math_fp.hlsli" // primarily used for photoshop level controls. do not use for blend modes
#include "external/blend_modes.hlsli" // use this for photoshop-esque blend modes
#include "math_utility.hlsli"

float3 srgb_to_linear(float3 srgb_color)
{
	return RemoveSRGBCurve_Fast(srgb_color.rgb);
}

float4 srgb_to_linear(float4 srgb_color)
{
	const float3 linear_3 = RemoveSRGBCurve_Fast(srgb_color.rgb);
	return float4(linear_3, srgb_color.a);
}

float3 linear_to_srgb(float3 linear_color)
{
	return ApplySRGBCurve_Fast(linear_color);
}

float4 linear_to_srgb(float4 linear_color)
{
	const float3 srgb_3 = ApplySRGBCurve_Fast(linear_color.rgb);
	return float4(srgb_3, linear_color.a);
}

// Photoshop Notes:
// HSB: hue/saturation/brightness - used in the color picker.
// HSV: not called this in photoshop but its the exact same as HSB. gimp and paint.net label it as HSV.
// HSL: hue/saturation/(lightness,luminosity) - used in the hue/saturation adjustment layer and the non-separable blend modes.
float3 rgb_to_hsb(float3 rgb)
{
	// adapted from:
	// wiki: https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGBe
	
	const float r = rgb.r;
    const float g = rgb.g;
    const float b = rgb.b;
	 
    const float cMax = max(r, max(g, b));
    const float cMin = min(r, min(g, b));
    const float delta = cMax - cMin;

    float hue;
    if (delta == 0.f)
    {
        hue = 0.f;
    }
    else if (cMax == r)
    {
        hue = 60.f * float_mod((g - b) / delta, 6.f);
    }
    else if (cMax == g)
    {
        hue = 60.f * ((b - r) / delta + 2.f);
    }
    else // cMax == b
    {
        hue = 60.f * ((r - g) / delta + 4.f);
    }

    const float saturation = (cMax == 0.f) ? 0.f : (delta / cMax);
    const float brightness = cMax;

    return float3(hue / 360.f, saturation, brightness);
}

// Photoshop Notes:
// HSB: hue/saturation/brightness - used in the color picker.
// HSV: not used in photoshop but its the exact same as HSB. gimp and paint.net label it as HSV.
// HSL: hue/saturation/(lightness,luminosity) - used in the hue/saturation adjustment layer and the non-separable blend modes.
float3 hsb_to_rgb(float3 hsb)
{
	// adapted from:
	// wiki: https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGBe
	
    const float hue = hsb.x * 360.f;  // convert hue to degrees
    const float saturation = hsb.y;
    const float brightness = hsb.z;

    const float chroma = brightness * saturation;
    const float x = chroma * (1 - abs(float_mod(hue / 60.f, 2.f) - 1.f));
    const float m = brightness - chroma;

    float3 rgb;

    if (hue >= 0 && hue < 60.f)
    {
        rgb = float3(chroma, x, 0.f);
    }
    else if (hue >= 60 && hue < 120.f)
    {
        rgb = float3(x, chroma, 0.f);
    }
    else if (hue >= 120.f && hue < 180.f)
    {
        rgb = float3(0.f, chroma, x);
    }
    else if (hue >= 180.f && hue < 240.f)
    {
        rgb = float3(0.f, x, chroma);
    }
    else if (hue >= 240 && hue < 300.f)
    {
        rgb = float3(x, 0.f, chroma);
    }
    else
    {
        rgb = float3(chroma, 0.f, x);
    }

    rgb = rgb + m;  // add m to match the brightness level

    return rgb;
}

// Photoshop Notes:
// HSB: hue/saturation/brightness - used in the color picker.
// HSV: not used in photoshop but its the exact same as HSB. gimp and paint.net label it as HSV.
// HSL: hue/saturation/(lightness,luminosity) - used in the hue/saturation adjustment layer and the non-separable blend modes.

float3 rgb_to_hsl(float3 rgb)
{
	// adapted from:
	// wiki: https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGBe
	// stackoverflow: https://stackoverflow.com/questions/2353211/hsl-to-rgb-color-conversion/9493060#9493060
	// rapidtables: https://www.rapidtables.com/convert/color/rgb-to-hsl.html

	float3 hsl = 0.f;

	const float r = rgb.r;
	const float g = rgb.g;
	const float b = rgb.b;

	const float min_rgb = min(r, min(g, b));
	const float max_rgb = max(r, max(g, b));
	
	// lightness/luminosity
	hsl.z = (min_rgb + max_rgb) / 2.f; 

	if (min_rgb == max_rgb) 
	{		
		// result is achromatic
		hsl.x = 0.f; // hue
		hsl.y = 0.f; // saturation
	} 
	else 
	{
		//delta
		const float d = max_rgb - min_rgb;

		// saturation
		// note there are several commonly referenced functions for saturation (see above for links):
		// wiki: standard
		// stackoverflow: same as wiki with some algebra. less intuitive and less optimial
		// rapidtables: same as wiki with some algebra. more optimal		
		// note that if hls.z (luminosity) is 1 or 0 we divide by zero. this can only happen if min and max are both 0 or both 1 but that means min == max and is handled above
		hsl.y = d / (1.f - abs(2.f * hsl.z - 1.f));

		// hue
		// note there are several commonly referenced functions for hue (see above for links):
		// wiki: operates in 0..360 space (hue represents a value on a circle). also assumes the result can go negative and is handled by the client.
		// rapidtables: again, operates in 0..360 space but attempts to handle negative values with the mod operator however the behavior of mod on negative numbers can vary.
		// stackoverflow: operates in 0..6 space and directly handles negative numbers in a stable fashion. ideal for our case.
		// for a more detailed explanation see: https://stackoverflow.com/a/39124032/15768825
		
		if(max_rgb == r)
		{
			hsl.x = (g - b) / d + (g < b ? 6.f : 0.f); //stack overflow method
		}
		else if(max_rgb == g)
		{
			hsl.x = (b - r) / d + 2.f;
		}
		else if(max_rgb == b)
		{
			hsl.x = (r - g) / d + 4.f;
		}

		// result from above will be between 0..6 (where the typical algorithm will multiply by 60 degrees to get a hue between 0..360)
		// we are working in 0..1 space so need to divide by 6
		hsl.x /= 6.f;
	}

	return hsl;
}

// Photoshop Notes:
// HSB: hue/saturation/brightness - used in the color picker.
// HSV: not used in photoshop but its the exact same as HSB. gimp and paint.net label it as HSV.
// HSL: hue/saturation/(lightness,luminosity) - used in the hue/saturation adjustment layer and the non-separable blend modes.
float hue_to_rgb(float p, float q, float t)
{
	// adapted from https://stackoverflow.com/a/9493060/15768825
	if (t < 0.f)
	{
		t += 1.f;
	}
	else if (t > 1.f)
	{
		t -= 1.f;
	}
		
	//if(t < 1/6) optimized
	if((t * 6.f) < 1.f)
	{
		return p + (q - p) * 6.f * t;
	}
	//else if(t < 1/2) optimized
	if((t * 2.f) < 1.f)
	{
		return q;
	}
	//else if(t < 2/3) optimized 
	if((t * 3.f) < 2.f)
	{
		return p + (q - p) * (2.f/3.f - t) * 6.f;
	}
	return p;
}

float3 hsl_to_rgb(float3 hsl)
{
	// adapted from https://stackoverflow.com/a/9493060/15768825
	float3 rgb;

	const float h = hsl.x;
	const float s = hsl.y;
	const float l = hsl.z;

	if(s == 0.f)
	{
		rgb = l; // achromatic so just set everything to the lightness/luminosity
	}
	else
	{
		const float q = (l < .5f) ? (l * (1.f + s)) : (l + s - l * s);
		const float p = 2.f * l - q;		
		
		rgb.r = hue_to_rgb(p, q, h + 1.f/3.f);
		rgb.g = hue_to_rgb(p, q, h);
		rgb.b = hue_to_rgb(p, q, h - 1.f/3.f);
	}
	return rgb;
}

float3 adjust_contrast_saturation_brightness(float3 color, float brt, float sat, float con)
{
	// increase or decrease theese values to adjust r, g and b color channels seperately
	const float AvgLumR = 0.5;
	const float AvgLumG = 0.5;
	const float AvgLumB = 0.5;

	const float3 LumCoeff = float3(0.2125, 0.7154, 0.0721);

	float3 AvgLumin = float3(AvgLumR, AvgLumG, AvgLumB);
	float3 brtColor = color * brt;
	float intensityf = dot(brtColor, LumCoeff);
	float3 intensity = float3(intensityf, intensityf, intensityf);
	float3 satColor = lerp(intensity, brtColor, sat);
	float3 conColor = lerp(AvgLumin, satColor, con);
	return conColor;
}

#endif