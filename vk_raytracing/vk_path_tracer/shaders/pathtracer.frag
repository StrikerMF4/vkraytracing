
#version 450

#extension GL_GOOGLE_include_directive : enable
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require

#include "host_device.h"

layout(location = 0) in vec2 outUV;
layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = eRenderedImage, rgba16f) uniform image2D output_image;
layout(set = 0, binding = eRenderedLightImage, r64ui) uniform uimage2D bidirectional_lights_output_image;

layout(push_constant) uniform _PushConstantPost { PushConstantPost settings; };

void main()
{
	ivec2 pixel = ivec2(outUV * vec2(settings.image_width, settings.image_height));
	vec3 output_color = imageLoad(output_image, pixel).xyz;

	if(settings.bidirectional_correction){
		uint64_t data = imageLoad(bidirectional_lights_output_image, pixel).x;

		uint count = uint(data & 0xFFFF);

		if (count > 0) {
			uvec3 u_color = uvec3((data >> 48) & 0xFFFF, (data >> 32) & 0xFFFF, (data >> 16) & 0xFFFF);

			// Convert to float
			vec3 color = uintBitsToFloat(u_color);

			// Calculate average color from bidirectional output
			color = color / (settings.frame + 1);
			if(isnan(color.r) || isnan(color.g) || isnan(color.b))
				color = vec3(0.0);
			// We use the same total for the average as in the raygen, beacause the light sample can't be added in that step
			output_color = output_color + color;
			imageStore(output_image, pixel, vec4(output_color, 1.f));

			//reset the bidirectional output before tracing the next frame
			imageStore(bidirectional_lights_output_image, pixel, uvec4(0));
		}
	}

	vec2  uv    = outUV;
	float gamma = 1. / 2.2;
	fragColor   = pow(vec4(output_color, 1.f), vec4(gamma));
//	fragColor   = vec4(output_color, 1.f);
}
