
#version 460
#extension GL_EXT_ray_tracing : require
#extension GL_GOOGLE_include_directive : enable
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require

#include "raycommon.glsl"
#include "wavefront.glsl"

layout(location = 0) rayPayloadInEXT rayPayload payload;

layout(push_constant) uniform _PushConstantRay
{
  PushConstantRay pcRay;
};

void main() {
	//payload.hitValue = pcRay.clearColor.xyz;

	//iluminacion ambiental
	
	payload.bsdf_sample = vec3(0);//vec3(10) * int(pcRay.ambientLigth);
	payload.status = MISS;
}
