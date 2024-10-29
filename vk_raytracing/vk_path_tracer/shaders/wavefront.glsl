
#include "host_device.h"
#include "random.glsl"

const float PI = 3.14159265;

vec3 computeDiffuse(WaveFrontMaterial mat, vec3 lightDir, vec3 normal)
{
  // Lambertian
  float dotNL = max(dot(normal, lightDir), 0.0);
  vec3  c     = mat.baseColor * dotNL;
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

vec3 ggx_micronormal(vec3 normal, float alpha, inout uint seed, inout float theta)
{
	if (alpha == 0) return normal;

	float e1 = rand(seed);
	float e2 = rand(seed);
	theta = atan(alpha * sqrt(e1) / sqrt(1.0 - e1));
	float phi = 2 * PI * e2;

	float x = sin(theta) * cos(phi);
    float y = sin(theta) * sin(phi);
    float z = cos(theta);
	vec3 micro_normal = vec3(x, y, z);

	return from_tangent_to_local(normal, micro_normal);
}

vec3 micro_reflect(vec3 i_ray, vec3 micro_normal)
{
	return normalize(2 * abs(dot(i_ray, micro_normal)) * micro_normal - i_ray);
}


vec3 micro_transmit(vec3 i_ray, vec3 micro_normal, vec3 normal, float n)
{
	float c =  dot(i_ray,micro_normal);
	float ndoti = sign(dot(i_ray,normal));
	float nc = n*c;
	float nsqr =  n * n;
	float csqr = c * c;

	return normalize((n*c - sign(dot(i_ray,normal)) * sqrt(abs((1 + n * n * ( c * c - 1))))) * micro_normal - n * i_ray);
}


float F(float refraction_index, vec3 viewer, vec3 halfway_vector){
	return Schlick(dot(viewer, halfway_vector), refraction_index);
}


float GGX_G1(vec3 v, vec3 m, vec3 n, float alpha)
{
	float vdotm = dot(v, m);
	float vdotn = dot(v, n);
    if (vdotm * vdotn > 0){
		vdotn = clamp(vdotn, -1.0 + 1e-5, 1.0 - 1e-5);
        float theta_v = acos(vdotn);
        return 2.0 / (1.0 + sqrt(1.0 + pow(alpha, 2) * pow(tan(theta_v), 2)));
    } else {
        return 0.01;
    }
}

float GGX_G(vec3 w_i, vec3 w_o, vec3 m, vec3 n, float alpha){

    if(dot(w_i, n)*dot(w_i, m) <= 0 ||
            dot(w_o, n)*dot(w_o, m) <= 0)
    {
        return 0.0f;
    }
    else
    {
        float g1_i = GGX_G1(w_i, m, n, alpha);
        float g1_o = GGX_G1(w_o, m, n, alpha);
        float result = g1_i * g1_o;

        return result;
    }
}

float GGX_D(vec3 m, vec3 n, float alpha, float theta)
{
	float mDotn = cos(theta);
	float alpha2 = alpha * alpha;
	return (mDotn > 0 ? alpha2 / (PI * pow(mDotn, 4) * pow(alpha2 + pow(tan(theta), 2), 2) + 0.01) : 1);
}



float CT_brdf(vec3 w_i, vec3 w_o, vec3 normal, vec3 micro_normal, float refraction_index, float alpha, float theta){
	vec3 halfway_vector = normalize(w_i + w_o);
	
	float D = GGX_D(micro_normal, normal, alpha, theta);
	float F = F(refraction_index, w_o, halfway_vector);
	float G = GGX_G(w_i, w_o, micro_normal, normal, alpha);

	return D * F * G / (4 * abs(dot(normal, w_i)) * abs(dot(normal, w_o)) + 0.000001);
}
