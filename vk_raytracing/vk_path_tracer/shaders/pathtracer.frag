
#version 450

#extension GL_GOOGLE_include_directive : enable
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require

#include "host_device.h"

layout(location = 0) in vec2 outUV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = eRenderedImage, rgba32f) uniform image2D output_image;
layout(set = 0, binding = eRenderedLightImage, rgba32f) uniform image2D bidirectional_lights_output_image;

layout(push_constant) uniform _PushConstantPost { PushConstantPost settings; };

void main()
{
	ivec2 pixel = ivec2(outUV * vec2(settings.image_width, settings.image_height));
	vec3 output_color = imageLoad(output_image, pixel).xyz;

	if(settings.bidirectional_correction){
		vec4 bidirectional_output = imageLoad(bidirectional_lights_output_image, pixel);

		// Calculate average color from bidirectional output
		vec3 fixed_color = bidirectional_output.xyz / bidirectional_output.w;

		// We use the same total for the average as in the raygen, beacause the light sample can't be added in that step
		output_color = output_color + fixed_color * (1 / settings.frame);

		imageStore(output_image, pixel, vec4(output_color, 1.f));

		//reset the bidirectional output before tracing the next frame
		imageStore(bidirectional_lights_output_image, pixel, vec4(0.0f));
	}

	vec2  uv    = outUV;
	float gamma = 1. / 2.2;
	fragColor   = pow(vec4(output_color, 1.f), vec4(gamma));
}
