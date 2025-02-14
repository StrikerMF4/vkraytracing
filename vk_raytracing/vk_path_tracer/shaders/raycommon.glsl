#ifndef RAYCOMMON
#define RAYCOMMON

#include "host_device.h"

const uint RAY_CONTINUE = 1;
const uint RAY_HIT_LIGHT = 2;
const uint RAY_MISS = 3;
const uint RAY_ABSORBED = 4;

const uint BSDF_DIFFUSE = 1;
const uint BSDF_REFLECTION = 2;
const uint BSDF_TRANSMISSION = 3;

const float PI = 3.14159265;
const float TWO_PI = 2*3.14159265;
const float INV_PI = 1/3.14159265;
const float EPSILON = 1e-10;

struct rayPayload
{
	//Ray
	uint status;
	vec3 origin;
	vec3 direction;

	//Data
	vec3 Le;
	vec3 bsdf_sample;
	uint bsdf_type;
	vec3 surface_normal;
	vec3 surface_micronormal;
	float theta;
	float pdf;

	WaveFrontMaterial material;

	//Exchange
	uint random_seed;
	bool backward_propagation;
};

void resetPayload(inout rayPayload payload, vec3 origin, vec3 direction){
	payload.status = RAY_CONTINUE;
    payload.origin = origin.xyz;
    payload.direction = direction.xyz;

	payload.Le = vec3(0);
    payload.bsdf_sample = vec3(0);
	payload.pdf = 1.0;
	payload.bsdf_type = 0;
	payload.surface_normal = vec3(0);
	payload.surface_micronormal = vec3(0);
	payload.theta = 0;
	payload.backward_propagation = false;

}

#endif