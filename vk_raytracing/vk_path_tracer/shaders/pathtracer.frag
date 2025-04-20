
#version 450

#extension GL_GOOGLE_include_directive : enable
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require

#include "host_device.h"

layout(location = 0) in vec2 outUV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = eRenderedImage, rgba16f) uniform image2D output_image;
layout(set = 0, binding = eRenderedLightImage, r32f) uniform image2D bidirectional_lights_output_image;

layout(push_constant) uniform _PushConstantPost { PushConstantPost settings; };

void main() {
	ivec2 pixel = ivec2(outUV * vec2(settings.image_width, settings.image_height));
	vec3 output_color = imageLoad(output_image, pixel).xyz;

	if(settings.bidirectional_correction) {
		float bidirectional_output_count = imageLoad(bidirectional_lights_output_image, ivec2(pixel.x + settings.image_width, pixel.y + settings.image_height)).x;

		if (bidirectional_output_count > 0) {
			float bidirectional_output_r = imageLoad(bidirectional_lights_output_image, pixel).x;
			float bidirectional_output_g = imageLoad(bidirectional_lights_output_image, ivec2(pixel.x + settings.image_width, pixel.y)).x;
			float bidirectional_output_b = imageLoad(bidirectional_lights_output_image, ivec2(pixel.x, pixel.y + settings.image_height)).x;

			// Calculate average color from bidirectional output
			vec3 fixed_color = vec3(bidirectional_output_r, bidirectional_output_g, bidirectional_output_b) / (settings.frame + 1);
			if(isnan(fixed_color.r) || isnan(fixed_color.g) || isnan(fixed_color.b))
				fixed_color = vec3(0.0);

			// We use the same total for the average as in the raygen, beacause the light sample can't be added in that step
			output_color = output_color + fixed_color;
			imageStore(output_image, pixel, vec4(output_color, 1.f));

			//reset the bidirectional output before tracing the next frame
			imageStore(bidirectional_lights_output_image, pixel, vec4(0)); //r
			imageStore(bidirectional_lights_output_image, ivec2(pixel.x + settings.image_width, pixel.y), vec4(0)); //g
			imageStore(bidirectional_lights_output_image, ivec2(pixel.x, pixel.y + settings.image_height), vec4(0)); //b
			imageStore(bidirectional_lights_output_image, pixel + ivec2(settings.image_width, settings.image_height), vec4(0)); //count
		}
	}

	vec2  uv    = outUV;
	float gamma = 1. / 2.2;
	fragColor   = pow(vec4(output_color, 1.f), vec4(gamma));
}
