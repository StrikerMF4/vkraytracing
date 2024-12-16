
#include "raycommon.glsl"
#include "random.glsl"

const float PI = 3.14159265;

vec3 computeDiffuse(WaveFrontMaterial mat, vec3 lightDir, vec3 normal)
{
    // Lambertian
    float dotNL = max(dot(normal, lightDir), 0.0);
    vec3  c = mat.baseColor * dotNL;
    return c;
}

vec3 computeSpecular(WaveFrontMaterial mat, vec3 viewDir, vec3 lightDir, vec3 normal)
{
    // Compute specular only if not in shadow
    const float kPi = 3.14159265;
    const float kShininess = 4.0;

    // Specular
    const float kEnergyConservation = (2.0 + kShininess) / (2.0 * kPi);
    vec3        V = normalize(-viewDir);
    vec3        R = reflect(-lightDir, normal);
    float       specular = kEnergyConservation * pow(max(dot(V, R), 0.0), kShininess);

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
    float a = -1.0F / (sgn + normal.z);
    float b = normal.x * normal.y * a;

    vec3 tangent = vec3(1.0f + sgn * normal.x * normal.x * a, sgn * b, -sgn * normal.x);
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
    float c = dot(i_ray, micro_normal);
    float ndoti = sign(dot(i_ray, normal));
    float nc = n * c;
    float nsqr = n * n;
    float csqr = c * c;

    return normalize((n * c - sign(dot(i_ray, normal)) * sqrt(abs((1 + n * n * (c * c - 1))))) * micro_normal - n * i_ray);
}


float F(float refraction_index, vec3 viewer, vec3 halfway_vector) {
    return Schlick(dot(viewer, halfway_vector), refraction_index);
}


float GGX_G1(vec3 v, vec3 m, vec3 n, float alpha)
{
    float vdotm = dot(v, m);
    float vdotn = dot(v, n);
    if (vdotm * vdotn > 0) {
        vdotn = clamp(vdotn, -1.0 + 1e-5, 1.0 - 1e-5);
        float theta_v = acos(vdotn);
        return 2.0 / (1.0 + sqrt(1.0 + pow(alpha, 2) * pow(tan(theta_v), 2)));
    }
    else {
        return 0.01;
    }
}

float GGX_G(vec3 w_i, vec3 w_o, vec3 m, vec3 n, float alpha) {

    if (dot(w_i, n) * dot(w_i, m) <= 0 ||
        dot(w_o, n) * dot(w_o, m) <= 0)
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



float CT_brdf(vec3 w_i, vec3 w_o, vec3 normal, vec3 micro_normal, float refraction_index, float alpha, float theta) {
    vec3 halfway_vector = normalize(w_i + w_o);

    float D = GGX_D(micro_normal, normal, alpha, theta);
    float F = F(refraction_index, w_o, halfway_vector);
    float G = GGX_G(w_i, w_o, micro_normal, normal, alpha);

    return D * F * G / (4 * abs(dot(normal, w_i)) * abs(dot(normal, w_o)) + 0.000001);
}


/* DISNEY */

float Luminance(vec3 c)
{
    return 0.212671 * c.x + 0.715160 * c.y + 0.072169 * c.z;
}


void TintColors(vec3 color, float eta, out float F0, out vec3 Csheen, out vec3 Cspec0)
{
    float lum = Luminance(color);
    vec3 ctint = lum > 0.0 ? color / lum : vec3(1.0);

    F0 = (1.0 - eta) / (1.0 + eta);
    F0 *= F0;

    Cspec0 = F0 * mix(vec3(1.0), ctint, 0/*mat.specularTint*/);
    Csheen = mix(vec3(1.0), ctint, 0/*mat.sheenTint*/);
}

float SchlickWeight(float u)
{
    float m = clamp(1.0 - u, 0.0, 1.0);
    float m2 = m * m;
    return m2 * m2 * m;
}


float DielectricFresnel(float cosThetaI, float eta)
{
    float sinThetaTSq = eta * eta * (1.0f - cosThetaI * cosThetaI);

    // Total internal reflection
    if (sinThetaTSq > 1.0)
        return 1.0;

    float cosThetaT = sqrt(max(1.0 - sinThetaTSq, 0.0));

    float rs = (eta * cosThetaT - cosThetaI) / (eta * cosThetaT + cosThetaI);
    float rp = (eta * cosThetaI - cosThetaT) / (eta * cosThetaI + cosThetaT);

    return 0.5f * (rs * rs + rp * rp);
}

vec3 EvalMicrofacetReflection(vec3 micro_normal, vec3 w_o, vec3 w_i, vec3 n, float alpha, float theta_m, vec3 F, out float pdf)
{
    pdf = 0.0;
    float NDotL = dot(n, w_o);
    float NDotV = dot(n, w_i);

    //float D = GTR2Aniso(H.z, H.x, H.y, mat.ax, mat.ay);
    float D = GGX_D(micro_normal, n, alpha, theta_m);
    // float G1 = SmithGAniso(abs(V.z), V.x, V.y, mat.ax, mat.ay); (NDotL = L.z; NDotV = V.z; NDotH = H.z)
    // float G2 = G1 * SmithGAniso(abs(L.z), L.x, L.y, mat.ax, mat.ay);
    float G = GGX_G(w_i, w_o, micro_normal, n, alpha);

    // D * abs(dot(n, micro_normal)) / (4.0 * abs(dot(w_o, micro_normal)) + 1e-7);
    pdf = abs(dot(n, micro_normal)) * D / (4.0 * NDotV);
    return F * D * G / (4.0 * NDotL * NDotV);
}

vec3 transmition(vec3 micro_normal, rayPayload payload) {
    bool ray_entering = dot(payload.direction, payload.surface_normal) < 0;
    float ni = 1;
    float nt = payload.material.ior;
    if (!ray_entering) {
        ni = nt;
        nt = 1;
    }

    float n = ni / nt;
    vec3 normal_alt = ray_entering ? payload.surface_normal : -payload.surface_normal;
    vec3 micro_normal_alt = ray_entering ? micro_normal : -micro_normal;

    float cos_theta = -dot(payload.direction, normal_alt);
    float sin_theta = n * n * (1.0 - cos_theta * cos_theta);

    bool cannot_refract = (ni > nt && sin_theta > 1);

    payload.bsdf_sample = vec3(1);

    if (cannot_refract || Schlick(cos_theta, n) > rand(payload.random_seed))
    {
        payload.bsdf_type = BSDF_REFLECTION;
        return micro_reflect(-payload.direction, micro_normal);
    }
    else {
        payload.bsdf_type = BSDF_TRANSMISSION;
        return micro_transmit(-payload.direction, micro_normal_alt, normal_alt, n);
    }
}


// Sample hemisphere with cosine weighting
vec3 sampleHemisphereCosineWeighted(vec3 normal, inout uint seed) {
    // Generate two random numbers
    float u1 = rand(seed);
    float u2 = rand(seed);

    // Transform the random numbers to spherical coordinates
    float r = sqrt(u1);
    float theta = 2.0 * PI * u2;

    // Convert spherical coordinates to Cartesian coordinates in tangent space
    float x = r * cos(theta);
    float y = r * sin(theta);
    float z = sqrt(1.0 - u1);

    // Construct an orthonormal basis (TBN) from the normal
    vec3 tangent, bitangent;

    if (abs(normal.x) > abs(normal.z)) {
        tangent = normalize(vec3(-normal.y, normal.x, 0.0));
    }
    else {
        tangent = normalize(vec3(0.0, -normal.z, normal.y));
    }
    bitangent = normalize(cross(normal, tangent));

    // Transform sample vector from tangent space to world space
    vec3 sample_dir = x * tangent + y * bitangent + z * normal;

    return normalize(sample_dir);
}

void disney_bsdf(inout rayPayload payload) {
    if (length(payload.material.emission) > 0) {
        // TO-DO: Cambiar esto por alguna aproximaci�n al L de Veach
        payload.bsdf_sample = payload.material.emission * payload.material.baseColor;
        payload.Le = payload.material.emission * payload.material.baseColor;
        payload.status = RAY_HIT_LIGHT;
    }
    else {


        // Initialize variables
        vec3 w_i = -payload.direction; // Incident direction (towards the surface)
        float cos_theta_i = dot(payload.surface_normal, w_i);
        cos_theta_i = clamp(cos_theta_i, -1.0, 1.0);

        // Determine if the ray is entering or exiting the material
        bool entering = cos_theta_i >= 0.0;

        // Adjust normal and cosine for transmission if necessary
        vec3 n = payload.surface_normal;
        /*
        if (!entering) {
            n = -payload.surface_normal;
            cos_theta_i = dot(n, w_i);
        }
        */

        // Material properties
        float metallic = clamp(payload.material.metallic, 0.0, 1.0);
        float roughness = clamp(payload.material.roughness, 0.005, 1.0); // Minimum roughness to avoid singularities
        float alpha = roughness * roughness;
        float transmission = 1 - clamp(payload.material.opacity, 0.0, 1.0);
        float eta_i = 1.0;           // Index of refraction of the incident medium (air)
        float eta_t = payload.material.ior;  // Index of refraction of the transmitted medium (material)
        if (!entering) {
            // Swap indices if exiting the material
            float temp = eta_i;
            eta_i = eta_t;
            eta_t = temp;
        }
        float eta = eta_i / eta_t;

        float F0;
        vec3 Csheen, Cspec0;
        TintColors(payload.material.baseColor, eta, F0, Csheen, Cspec0); // void TintColors(vec3 color, float eta, out float F0, out vec3 Csheen, out vec3 Cspec0)

        float NdotV = dot(n, w_i);

        float schlickWt = SchlickWeight(NdotV);

        // Model weights
        float dielectricWt = (1.0 - metallic) * (1.0 - transmission);
        float glassWt = (1.0 - metallic) * transmission;

        float diffPr = dielectricWt * Luminance(payload.material.baseColor);
        float dielectricPr = dielectricWt * Luminance(mix(Cspec0, vec3(1.0), schlickWt));
        float metalPr = metallic * Luminance(mix(payload.material.baseColor, vec3(1.0), schlickWt));
        float glassPr = glassWt;

        // Normalize probabilities
        float invTotalWt = 1.0 / (diffPr + dielectricPr + metalPr + glassPr);
        diffPr *= invTotalWt;
        dielectricPr *= invTotalWt;
        metalPr *= invTotalWt;
        glassPr *= invTotalWt;

        // Generate a random number to select the scattering event
        float rnd = rand(payload.random_seed);

        // CDF of the sampling probabilities
        float cdf[5];
        cdf[0] = diffPr;
        cdf[1] = cdf[0] + dielectricPr;
        cdf[2] = cdf[1] + metalPr;
        cdf[3] = cdf[2] + glassPr;

        if (rnd < cdf[0]) {
            // Diffuse Reflection

            // Sample outgoing direction over hemisphere
            //vec3 w_o = sampleHemisphereCosineWeighted(n, payload.random_seed);
            vec3 w_o = RandomInUnitSemiSphere(payload.random_seed, n);

            if (dot(payload.direction, n) > 0.0) {
                payload.status = RAY_ABSORBED;
                return;
            }

            // Compute diffuse BRDF
            vec3 f_diffuse = payload.material.baseColor / PI;

            // Compute PDF
            float pdf = max(dot(n, w_o), 0.0) / PI;

            // Update payload
            payload.direction = w_o;
            payload.bsdf_sample = f_diffuse;
            payload.pdf = pdf;
            payload.status = RAY_CONTINUE;
        }
        else if (rnd < cdf[2]) { // Dielectric + Metallic reflection

            // vec3 H = SampleGGXVNDF(V, state.mat.ax, state.mat.ay, r1, r2);
            float theta_m;
            vec3 micro_normal = ggx_micronormal(n, alpha, payload.random_seed, theta_m);
            float VDotH = clamp(dot(w_i, micro_normal), 0.0, 1.0);
            vec3 w_o = micro_reflect(w_i, micro_normal);

            // Dielectric Reflection
            if (rnd < cdf[1]) {
                // Normalize for interpolating based on Cspec0
                // float DielectricFresnel(float cosThetaI, float eta)
                float NDotL = dot(n, w_o);

                if (NDotL <= 0.0)
                {
                    payload.bsdf_sample = vec3(0.0);
                    payload.status = RAY_ABSORBED;
                    return;
                }

                float F = (DielectricFresnel(VDotH, 1.0 / payload.material.ior) - F0) / (1.0 - F0);
                float pdf;
                vec3 f = EvalMicrofacetReflection(micro_normal, w_o, w_i, n, alpha, theta_m, mix(Cspec0, vec3(1.0), F), pdf);

                payload.direction = w_o;
                payload.bsdf_sample = f;
                payload.pdf = pdf;
                payload.status = RAY_CONTINUE;
            }
            else {
                vec3 w_o = micro_reflect(w_i, micro_normal);

                float pdf;

                vec3 F = mix(payload.material.baseColor, vec3(1.0), SchlickWeight(VDotH));

                vec3 f = EvalMicrofacetReflection(micro_normal, w_o, w_i, n, alpha, theta_m, F, pdf);

                payload.direction = w_o;
                payload.bsdf_sample = f;
                payload.pdf = pdf;
                payload.status = RAY_CONTINUE;

            }
        }
        else if (rnd < cdf[3]) {  // Glass/Specular BSDF
            // Dielectric fresnel (achromatic)
            float theta_m;
            vec3 micro_normal = ggx_micronormal(n, alpha, payload.random_seed, theta_m);
            float VDotH = dot(w_i, micro_normal);

            float F = DielectricFresnel(VDotH, 1.0 / payload.material.ior);

            bool ray_entering = dot(payload.direction, payload.surface_normal) < 0;
            float ni = 1;
            float nt = payload.material.ior;
            if (!ray_entering) {
                ni = nt;
                nt = 1;
            }
            // float Schlick(const float cosine, const float refractionIndex)
            if (Schlick(cos_theta_i, ni / nt) > rand(payload.random_seed))
            {
                vec3 w_o = micro_reflect(w_i, micro_normal);

                float pdf;

                vec3 f = EvalMicrofacetReflection(micro_normal, w_o, w_i, n, alpha, theta_m, vec3(F), pdf);

                payload.direction = w_o;
                payload.bsdf_sample = f;
                payload.pdf = pdf;
                payload.status = RAY_CONTINUE;
            }
            /*else
            {
                vec3 w_o = micro_transmit(-payload.direction, micro_normal_alt, normal_alt, ni/nt);
                f += EvalMicrofacetRefraction(state.mat, state.eta, V, L, H, vec3(F), tmpPdf) * glassWt;
                // pdf += tmpPdf * glassPr * (1.0 - F);
            }*/
        }

    }
}


