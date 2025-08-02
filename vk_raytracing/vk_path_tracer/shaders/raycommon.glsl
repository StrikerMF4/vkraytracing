#ifndef RAYCOMMON
#define RAYCOMMON

#include "host_device.h"

const uint RAY_CONTINUE = 1;
const uint RAY_HIT_LIGHT = 2;
const uint RAY_MISS = 3;

const uint BSDF_DIFFUSE = 1;
const uint BSDF_REFLECTION = 2;
const uint BSDF_TRANSMISSION = 3;
const uint MIN_DEPTH_ABSORPTION = 3;

const float PI = 3.14159265;
const float TWO_PI = 2*3.14159265;
const float INV_PI = 1/3.14159265;
const float EPSILON = 1e-10;
const float EPSILON2 = 1e-4;
const float INF = 1e10;
const float T_MIN = 0.001;
const float T_MAX = 10000.0;

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
	float theta;
	float pdfF;
	float pdfB;
	uint light_id;
	vec3 tangent; 

	Material material;

	//Exchange
	uint random_seed;
	uint backward_propagation;
};

void resetPayload(inout rayPayload payload, vec3 origin, vec3 direction){
	payload.status = RAY_CONTINUE;
    payload.origin = origin.xyz;
    payload.direction = direction.xyz;

	payload.Le = vec3(0);
    payload.bsdf_sample = vec3(0);
	payload.pdfF = 1.0;
	payload.pdfB = 1.0;
	payload.bsdf_type = 0;
	payload.light_id = 0;
	payload.theta = 0;
	payload.backward_propagation = 0;
}

struct Node {
	vec3 point;
	vec3 alpha;
	float pdfF;
	float pdfB;
	bool isSpecular;
	float G;
	vec3 normal;
	vec3 w_i;
	Material material;
};

struct PDFConnection {
	float lightF;
	float lightB;	
	float eyeF;
	float eyeB;
	float G;
};

struct MISNode { 
	float light;
	float eye;
	bool isSpecular;
};

#endif