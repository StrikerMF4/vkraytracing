#ifndef RANDOM
#define RANDOM
#include "raycommon.glsl"

uint pcg_hash(inout uint seed) {
	uint word = ((seed>>((seed>>28u)+4u))^seed)*277803737u;
	seed = seed*747796405u+2891336453u;
	return (word>>22u)^word;
}

//// Generate a random float in [0, 1)
float rand(inout uint seed) {
	return float(pcg_hash(seed))/4294967295.0;
}

// Generate a random unsigned int from two unsigned int values, using 16 pairs
// of rounds of the Tiny Encryption Algorithm. See Zafar, Olano, and Curtis,
// "GPU Random Numbers via the Tiny Encryption Algorithm"
uint InitRandomSeed(uint val0, uint val1) {
	uint v0 = val0;
	uint v1 = val1;
	uint s0 = 0;

	for(uint n = 0; n<16; n++) {
		s0 += 0x9e3779b9;
		v0 += ((v1<<4)+0xa341316c)^(v1+s0)^((v1>>5)+0xc8013ea4);
		v1 += ((v0<<4)+0xad90777d)^(v0+s0)^((v0>>5)+0x7e95761e);
	}

	return v0;
}

vec2 RandomGaussianVector(inout uint rngState) {

	const float u1 = max(EPSILON, rand(rngState));
	const float u2 = rand(rngState);  // In [0, 1]
	const float r = sqrt(-2.0 * log(u1));
	const float theta = 2 * PI * u2;  // Random in [0, 2pi]
	return r*vec2(cos(theta), sin(theta));
}

vec2 RandomDiskDirection(inout uint seed) {
	float rand = rand(seed);
	return vec2(sin(rand), cos(rand));
}

vec3 RandomSphereDirection(inout uint seed) {
	float theta = rand(seed) * TWO_PI;
	float phi = acos((2 * rand(seed)) - 1);
	return vec3(
		sin(phi) * cos(theta), 
		sin(phi) * sin(theta), 
		cos(phi)
	);
}

vec3 RandomHemisphereDirection(vec3 normal, inout uint seed) {
	vec3 rdir = RandomSphereDirection(seed);
	return rdir * (dot(rdir, normal) <= 0 ? -1 : 1);
}

vec3 RandomCosineHemisphereDirection(vec3 normal, inout uint seed) {
	return normalize(RandomSphereDirection(seed)+normal);
}


vec3 randomBarycentricPointInTriangle(vec3 A, vec3 B, vec3 C, inout uint seed) {
	float r1 = rand(seed);
	float r2 = rand(seed);

	if(r1 + r2 > 1.0) {
		r1 = 1.0 - r1;
		r2 = 1.0 - r2;
	}

	float a = 1.0 - r1 - r2;
	float b = r1;
	float c = r2;

	return vec3(a, b, c);
}

#endif