
#include "host_device.h"
#include "random.glsl"

const float PI = 3.14159265;

vec3 computeDiffuse(WaveFrontMaterial mat, vec3 lightDir, vec3 normal)
{
  // Lambertian
  float dotNL = max(dot(normal, lightDir), 0.0);
  vec3  c     = mat.color * dotNL;
  return c;
}

vec3 computeSpecular(WaveFrontMaterial mat, vec3 viewDir, vec3 lightDir, vec3 normal)
{
  // Compute specular only if not in shadow
  const float kPi        = 3.14159265;
  const float kShininess = 4.0;

  // Specular
  const float kEnergyConservation = (2.0 + kShininess) / (2.0 * kPi);
  vec3        V                   = normalize(-viewDir);
  vec3        R                   = reflect(-lightDir, normal);
  float       specular            = kEnergyConservation * pow(max(dot(V, R), 0.0), kShininess);

  return vec3(4.0 * specular);
}



// path tracer

// Polynomial approximation by Christophe Schlick
float Schlick(const float cosine, const float refractionIndex)
{
	float r0 = (1 - refractionIndex) / (1 + refractionIndex);
	r0 *= r0;
	return r0 + (1 - r0) * pow(1 - cosine, 5);
}

vec3 from_tangent_to_local(vec3 normal, vec3 vector)
{
	float sgn = normal.z > 0.0F ? 1.0F : -1.0F;
	float a   = -1.0F / (sgn + normal.z);
	float b   = normal.x * normal.y * a;

	vec3 tangent   = vec3(1.0f + sgn * normal.x * normal.x * a, sgn * b, -sgn * normal.x);
	vec3 bitangent = vec3(b, sgn + normal.y * normal.y * a, -normal.y);

    return vector.x * tangent + vector.y * bitangent + vector.z * normal;
}

vec3 ggx_micronormal(vec3 normal, float alpha, inout uint seed)
{
	float e1 = rand(seed);
	float e2 = rand(seed);
	float theta = atan(alpha * sqrt(e1) / sqrt(1.0 - e1));
	float phi = 2 * PI * e2;

	float x = sin(theta) * cos(phi);
    float y = sin(theta) * sin(phi);
    float z = cos(theta);
	vec3 micro_normal = vec3(x, y, z);

	return from_tangent_to_local(normal, micro_normal);
}

vec3 micro_reflect(vec3 i_ray, vec3 micro_normal)
{
	return 2 * abs(dot(i_ray, micro_normal)) * micro_normal - i_ray;
}


vec3 micro_transmit(vec3 i_ray, vec3 micro_normal, vec3 normal, float n)
{
	float c =  dot(i_ray,micro_normal);
	return (n*c - sign(dot(i_ray,normal)) * sqrt( 1 + n * n * ( c * c - 1) )) * micro_normal - n * i_ray;
}

float GGX_D(vec3 normal, vec3 micro_normal, float roughness){
	float cos_theta = dot(normal, micro_normal);

	if(cos_theta <= 0)
		return 0;

	float alpha = roughness * roughness;
	float cos4_theta = cos_theta * cos_theta;
	cos4_theta = cos4_theta * cos4_theta;
	float tan2_theta = tan(acos(cos_theta));
	tan2_theta = tan2_theta * tan2_theta;

	float div = PI * cos4_theta * (alpha + tan2_theta) * (alpha + tan2_theta);
	float xi = 3;

	return alpha / div;
}

float GGX_G(vec3 viewer, vec3 normal, vec3 micro_normal, float roughness){
	float alpha = roughness * roughness;
	float check = dot(viewer, micro_normal) / dot(viewer, normal);

	if(check <= 0)
		return 0;
	
	float tan_theta = tan(acos(dot(normal, micro_normal)));

	return 2 / (1 + sqrt(1 + alpha * tan_theta * tan_theta));
}

float F(float refraction_index, vec3 viewer, vec3 halfway_vector){
	float F0 = (refraction_index - 1) / (refraction_index + 1);
	F0 = F0 * F0;

	return F0 + (1 - F0) * pow(1 - dot(viewer, halfway_vector), 5);
}

float CT_brdf(vec3 light, vec3 viewer, vec3 normal, vec3 micro_normal, float roughness, float refraction_index){
	vec3 halfway_vector = normalize(light + viewer);
	
	float D = GGX_D(normal, micro_normal, roughness);
	float F = F(refraction_index, viewer, halfway_vector);
	float G = GGX_G(viewer, normal, micro_normal, roughness);

	return D * F * G / (4 * dot(normal, light) * dot(normal, viewer));
}