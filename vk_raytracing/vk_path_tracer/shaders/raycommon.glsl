
const uint CONTINUE = 1;
const uint HIT_LIGHT = 2;
const uint MISS = 3;

const float PI = 3.14159265;

struct rayPayload
{
	//Ray
	uint status;
	vec3 origin;
	vec3 direction;

	//Data
	vec3 Le;
	vec3 bsdf_sample;
	vec3 surface_normal;

	//Exchange
	uint random_seed;
};

void resetPayload(inout rayPayload payload, vec3 origin, vec3 direction){
	payload.status = CONTINUE;
    payload.origin = origin.xyz;
    payload.direction = direction.xyz;

	payload.Le = vec3(0);
    payload.bsdf_sample = vec3(0);
	payload.surface_normal = vec3(0);
}
