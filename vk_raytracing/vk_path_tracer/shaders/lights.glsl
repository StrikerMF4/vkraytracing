#ifndef LIGHT
#define LIGHT

#include "raycommon.glsl"
#include "random.glsl"

vec3 sampleAreaLightDirection(vec3 normal, out float pdf, inout uint seed) {
    vec3 dir = RandomCosineHemisphereDirection(normal, seed);
    float cosTheta = dot(dir, normal);

    pdf = max(0.0, cosTheta) * INV_PI; 
    return dir;
}

float AreaLightPDFDirection(vec3 direction, vec3 normal) {
    float cosTheta = dot(direction, normal);
    return cosTheta > 0.0f ? cosTheta * INV_PI : 0.0f;
}

#endif