#ifndef WAVEFRONT
#define WAVEFRONT

#include "raycommon.glsl"
#include "random.glsl"

vec3 TangentToLocal(vec3 normal, vec3 vector) {
    float sgn = normal.z > 0.0F ? 1.0F : -1.0F;
    float a = -1.0F / (sgn + normal.z);
    float b = normal.x * normal.y * a;

    vec3 tangent = vec3(1.0f + sgn * normal.x * normal.x * a, sgn * b, -sgn * normal.x);
    vec3 bitangent = vec3(b, sgn + normal.y * normal.y * a, -normal.y);

    return vector.x * tangent + vector.y * bitangent + vector.z * normal;
}

//void TangentVectors(in vec3 N, inout vec3 T, inout vec3 B) {
//    vec3 up = abs(N.z) < 0.9999999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
//    T = normalize(cross(up, N));
//    B = cross(N, T);
//}

void TangentVectors(in vec3 N, in vec3 tangent, out vec3 T, out vec3 B) 
{
    if (length(tangent) < EPSILON2) {
        vec3 up = abs(N.z) < 0.9999999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
        T = normalize(cross(up, N));
    } else {
        T = normalize(tangent - dot(tangent, N) * N);
    }
    B = cross(N, T);
}

float GeometricTerm(vec3 xi, vec3 ni, vec3 xo, vec3 no) {
    vec3 x_diff = xo - xi;
    vec3 x_diff_norm = normalize(x_diff);

    float cos_theta_i = dot(ni, x_diff_norm);
    float cos_theta_o = dot(no, x_diff_norm);

    return abs(cos_theta_o * cos_theta_i) / (dot(x_diff, x_diff) + EPSILON);
}

float Schlick(const float cosine, const float refractionIndex) {
    float r0 = (1 - refractionIndex) / (1 + refractionIndex);
    r0 *= r0;
    return r0 + (1 - r0) * pow(1 - cosine, 5);
}

float SchlickWeight(float u) {
    float m = clamp(1.0 - u, 0.0, 1.0);
    float m2 = m * m;
    return m2 * m2 * m;
}

float DielectricFresnel(float cosThetaI, float eta) {
    float sinThetaTSq = eta * eta * (1.0f - cosThetaI * cosThetaI);

    // Total internal reflection
    if (sinThetaTSq > 1.0)
        return 1.0;

    float cosThetaT = sqrt(max(1.0 - sinThetaTSq, 0.0));

    float rs = (eta * cosThetaT - cosThetaI) / (eta * cosThetaT + cosThetaI + EPSILON);
    float rp = (eta * cosThetaI - cosThetaT) / (eta * cosThetaI + cosThetaT + EPSILON);

    return 0.5f * (rs * rs + rp * rp);
}

vec3 GGXMicronormal(vec3 normal, float alpha, inout uint seed, inout float theta) {
    if (alpha == 0) return normal;

    float e1 = rand(seed);
    float e2 = rand(seed);
    theta = atan(alpha * sqrt(e1) / sqrt(1.0 - e1));
    float phi = 2 * PI * e2;

    float x = sin(theta) * cos(phi);
    float y = sin(theta) * sin(phi);
    float z = cos(theta);
    vec3 micro_normal = vec3(x, y, z);

    return TangentToLocal(normal, micro_normal);
}

vec3 GGXAnisotropicMicronormal(vec3 N, vec3 T, vec3 B, float ax, float ay, inout uint seed) {
    float e1 = rand(seed);
    float e2 = rand(seed);

    // Mapeo a disco elíptico en el plano tangente
    float phi = 2.0 * PI * e1;
    float r = sqrt(e2);
    float x = r * cos(phi);
    float y = r * sin(phi);

    // Proyección al hemisferio
    vec3 H_tan;
    H_tan.x = ax * x;
    H_tan.y = ay * y;
    H_tan.z = sqrt(max(0.0, 1.0 - (H_tan.x * H_tan.x) - (H_tan.y * H_tan.y)));

    // Transformar del espacio tangente al espacio del mundo
    return normalize(T * H_tan.x + B * H_tan.y + N * H_tan.z);
}

vec3 MicroReflect(vec3 i_ray, vec3 micro_normal) {
    return normalize(2 * abs(dot(i_ray, micro_normal)) * micro_normal - i_ray);
}

vec3 MicroTransmit(vec3 i_ray, vec3 micro_normal, vec3 normal, float n) {
    float c = dot(i_ray, micro_normal);
    float ndoti = sign(dot(i_ray, normal));
    float nc = n * c;
    float nsqr = n * n;
    float csqr = c * c;

    return normalize((n * c - sign(dot(i_ray, normal)) * sqrt(abs((1 + n * n * (c * c - 1))))) * micro_normal - n * i_ray);
}

float Luminance(vec3 c) {
    return 0.212671 * c.x + 0.715160 * c.y + 0.072169 * c.z;
}

void TintColors(Material material, float eta, out float F0, out vec3 Csheen, out vec3 Cspec0) {
    float lum = Luminance(material.baseColor);
    vec3 ctint = lum > 0.0 ? material.baseColor / lum : vec3(1.0);

    F0 = (1.0 - eta) / (1.0 + eta);
    F0 *= F0;
    
    Cspec0 = F0 * mix(vec3(1.0), ctint, material.specularTint);
    Csheen = mix(vec3(1.0), ctint, material.sheenTint);
}

float GGXAnisotropicD(float NDotH, float HDotX, float HDotY, float ax, float ay) {
    float a = HDotX / ax;
    float b = HDotY / ay;
    float c = a * a + b * b + NDotH * NDotH;
    return 1.0 / (PI * ax * ay * c * c);
}

float GGXAnisotropicG(float NDotV, float VDotX, float VDotY, float ax, float ay) {
    float a = VDotX * ax;
    float b = VDotY * ay;
    float c = NDotV;
    return (2.0 * NDotV) / (NDotV + sqrt(a * a + b * b + c * c));
}

vec3 EvalDisneyDiffuse(Material material, vec3 Csheen, vec3 w_i, vec3 w_o, vec3 H, vec3 normal, out float pdfF, out float pdfB) {
    pdfF = 0.0;
    pdfB = 0.0;

    float ODotH = dot(w_o, H);
    float ODotN = dot(normal, w_o);
    float IDotN = dot(normal, w_i);

    if (ODotN <= 0.0)
        return vec3(0.0);

    float Rr = 2.0 * material.roughness * ODotH * ODotH;

    // Diffuse
    float FL = SchlickWeight(ODotN);
    float FV = SchlickWeight(IDotN);
    float Fretro = Rr * (FL + FV + FL * FV * (Rr - 1.0));
    float Fd = (1.0 - 0.5 * FL) * (1.0 - 0.5 * FV);

    // Fake subsurface
    float Fss90 = 0.5 * Rr;
    float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
    float ss = 1.25 * (Fss * (1.0 / (ODotN + IDotN) - 0.5) + 0.5);

    // Sheen
    float FH = SchlickWeight(ODotH);
    vec3 Fsheen = FH * material.sheen * Csheen;

    pdfF = ODotN * INV_PI;
    pdfB = IDotN * INV_PI;
    return INV_PI * material.baseColor * mix(Fd + Fretro, ss, material.subsurface) + Fsheen;
}

vec3 EvalMicrofacetReflection(Material material, vec3 w_i, vec3 w_o, vec3 normal, vec3 tangent, vec3 H, vec3 F, out float pdfF, out float pdfB) {
    pdfF = 0.0;
    pdfB = 0.0;

    float ODotN = dot(normal, w_o);
    if (ODotN <= 0.0)
        return vec3(0.0);

    float IDotN = dot(normal, w_i);
    vec3 T, B;
    TangentVectors(normal,tangent, T, B);

    float aspect = sqrt(1.0 - material.anisotropic * 0.9);
    float ax = max(0.001, material.roughness * material.roughness / aspect);
    float ay = max(0.001, material.roughness * material.roughness * aspect);

    float D = GGXAnisotropicD(dot(H, normal), dot(H, T), dot(H, B), ax, ay);
    float G1 = GGXAnisotropicG(abs(IDotN), dot(w_i, T), dot(w_i, B), ax, ay);
    float G2 = GGXAnisotropicG(abs(ODotN), dot(w_o, T), dot(w_o, B), ax, ay);
    float G = G1 * G2;

    pdfF = G1 * D / (4.0 * IDotN);
    pdfB = G2 * D / (4.0 * IDotN);
    return F * D * G / (4.0 * ODotN * IDotN);
}

vec3 EvalMicrofacetRefraction(Material material, vec3 w_i, vec3 w_o, vec3 normal, vec3 tangent, vec3 H, vec3 F, float eta, out float pdfF, out float pdfB) {
    float IDotN = dot(w_i, normal);
    float ODotN = dot(w_o, normal);
    float IDotH = dot(w_i, H);
    float ODotH = dot(w_o, H);

    float aspect = sqrt(1.0 - material.anisotropic * 0.9);
    float ax = max(0.001, material.roughness * material.roughness / aspect);
    float ay = max(0.001, material.roughness * material.roughness * aspect);

    vec3 T, B;
    TangentVectors(normal,tangent, T, B);
    float D = GGXAnisotropicD(dot(H, normal), dot(H, T), dot(H, B), ax, ay);
    float G1 = GGXAnisotropicG(abs(IDotN), dot(w_i, T), dot(w_i, B), ax, ay);
    float G2 = GGXAnisotropicG(abs(ODotN), dot(w_o, T), dot(w_o, B), ax, ay);
    float G = G1 * G2;

    float eta2 = eta * eta;
    float denom = (abs(IDotH) + eta * abs(ODotH));
    denom *= denom;
    float denom_f = denom * abs(IDotN) * abs(ODotN);
    float factor = abs((abs(IDotH * ODotH)) / (denom_f));

    vec3 f = sqrt(material.baseColor) * (1.0 - F) * D * G * factor;

    pdfF = (G1 * abs(IDotH) * abs(ODotH) * D) / ((denom) * IDotN);
    pdfB = (G2 * abs(IDotH) * abs(ODotH) * D) / ((denom) * ODotN);

    return f;
}


void DisneyBSDF(vec3 w_o, vec3 w_i, vec3 normal, vec3 tangent, Material material, out vec3 outputColor, out float pdfF, out float pdfB, inout uint random_seed) {
    pdfF = 0.0;
    pdfB = 0.0;
    vec3 f = vec3(0.0);
    float cos_theta_i = dot(normal, w_i);
    // Determine if the ray is entering or exiting the material
    bool entering = cos_theta_i >= 0.0;
    float eta_i = 1;
    float eta_t = material.ior;
    if (!entering) {
        normal = -normal;
        eta_i = material.ior;
        eta_t = 1.0;
    }
    float eta = eta_i / eta_t;

    float ODotN = dot(normal, w_o);
    float IDotN = dot(normal, w_i);

    // Tint colors
    vec3 Csheen, Cspec0;
    float F0;
    TintColors(material, eta, F0, Csheen, Cspec0);

    // Model weights
    float dielectricWt = (1.0 - material.metallic) * material.opacity;
    float metalWt = material.metallic;
    float glassWt = (1.0 - material.metallic) * (1.0 - material.opacity);

    // Lobe probabilities
    float schlickWt = SchlickWeight(IDotN);

    float diffPr = dielectricWt * Luminance(material.baseColor);
    float dielectricPr = dielectricWt * Luminance(mix(Cspec0, vec3(1.0), schlickWt));
    float metalPr = metalWt * Luminance(mix(material.baseColor, vec3(1.0), schlickWt));
    float glassPr = glassWt;
    float clearCtPr = 0.25 * material.clearcoat;

    // Normalize probabilities
    float invTotalWt = 1.0 / (diffPr + dielectricPr + metalPr + glassPr + clearCtPr);
    diffPr *= invTotalWt;
    dielectricPr *= invTotalWt;
    metalPr *= invTotalWt;
    glassPr *= invTotalWt;
    clearCtPr *= invTotalWt;

    bool reflect = ODotN * IDotN > 0;

    vec3 H;

    if (reflect)
        H = normalize(w_i + w_o);
    else
        H = normalize(w_o + eta * w_i);

    float NDotH = dot(normal, H);
    if (NDotH < 0.0)
        H = -H;

    float tmpPdfF = 0.0;
    float tmpPdfB = 0.0;
    float IDotH = clamp(dot(w_i, H), 0.0, 1.0);

    if (diffPr > 0.0 && reflect) { // Diffuse
        f += EvalDisneyDiffuse(material, Csheen, w_i, w_o, H, normal, tmpPdfF, tmpPdfB) * dielectricWt;
        pdfF += tmpPdfF * diffPr;
        pdfB += tmpPdfB * diffPr;
    }
    
    if (dielectricPr > 0.0 && reflect) { // Dielectric Reflection
        // Normalize for interpolating based on Cspec0
        float F = (DielectricFresnel(IDotH, 1.0 / material.ior) - F0) / (1.0 - F0);

        f += EvalMicrofacetReflection(material, w_i, w_o, normal, tangent, H, mix(Cspec0, vec3(1.0), F), tmpPdfF, tmpPdfB) * dielectricWt;
        pdfF += tmpPdfF * dielectricPr;
        pdfB += tmpPdfB * dielectricPr;
    }
    
    if (metalPr > 0.0 && reflect) { // Metallic Reflection
        vec3 F = mix(material.baseColor, vec3(1.0), SchlickWeight(IDotH));

        f += EvalMicrofacetReflection(material, w_i, w_o, normal, tangent, H, F, tmpPdfF, tmpPdfB)  * metalWt;
        pdfF += tmpPdfF * metalPr;
        pdfB += tmpPdfB * metalPr;
    }
    
    if (glassPr > 0.0) { // Glass/Specular BSDF
        float F = DielectricFresnel(IDotH, eta);

        if (reflect) {
            f += EvalMicrofacetReflection(material, w_i, w_o, normal, tangent, H, vec3(F), tmpPdfF, tmpPdfB) * glassWt;
            pdfF += tmpPdfF * glassPr * F;
            pdfB += tmpPdfB * glassPr * F;
        }
        else {
            f += EvalMicrofacetRefraction(material, w_i, w_o, normal, tangent, H, vec3(F), eta, tmpPdfF, tmpPdfB) * glassWt;
            pdfF += tmpPdfF * glassPr * (1.0 - F);
            pdfB += tmpPdfB * glassPr * (1.0 - F);
        }
    }

    outputColor = f;
}

vec3 DisneyBSDFDirection(vec3 w_i, vec3 normal, vec3 tangent, Material material, inout uint bsdf_type, inout uint random_seed) {
    float cos_theta_i = dot(normal, w_i);
    cos_theta_i = clamp(cos_theta_i, -1.0, 1.0);
    // Determine if the ray is entering or exiting the material
    bool entering = cos_theta_i >= 0.0;
    float eta_i = 1.0;
    float eta_t = material.ior;
    if (!entering) {
        normal = -normal;
        cos_theta_i = -cos_theta_i;
        eta_i = material.ior;
        eta_t = 1.0;
    }
    float eta = eta_i / eta_t;

    float alpha = material.roughness * material.roughness;

    // Tint colors
    vec3 Csheen, Cspec0;
    float F0;
    TintColors(material, eta, F0, Csheen, Cspec0);

    // Model weights
    float dielectricWt = (1.0 - material.metallic) * material.opacity;
    float metalWt = material.metallic;
    float glassWt = (1.0 - material.metallic) * (1.0 - material.opacity);

    // Lobe probabilities
    float schlickWt = SchlickWeight(cos_theta_i);

    float diffPr = dielectricWt * Luminance(material.baseColor);
    float dielectricPr = dielectricWt * Luminance(mix(Cspec0, vec3(1.0), schlickWt));
    float metalPr = metalWt * Luminance(mix(material.baseColor, vec3(1.0), schlickWt));
    float glassPr = glassWt;

    // Normalize probabilities
    float invTotalWt = 1.0 / (diffPr + dielectricPr + metalPr + glassPr);
    diffPr *= invTotalWt;
    dielectricPr *= invTotalWt;
    metalPr *= invTotalWt;
    glassPr *= invTotalWt;

    // CDF of the sampling probabilities
    float cdf[5];
    cdf[0] = diffPr;
    cdf[1] = cdf[0] + dielectricPr;
    cdf[2] = cdf[1] + metalPr;
    cdf[3] = cdf[2] + glassPr;

    // Sample a lobe based on its importance
    float r3 = rand(random_seed);

    float tmpPdf;
    vec3 L, f;
    vec3 w_o;
    if (r3 < cdf[0]) { // Diffuse
        w_o = RandomCosineHemisphereDirection(normal, random_seed);
        bsdf_type = BSDF_DIFFUSE;
    }
    else if (r3 < cdf[2]) { // Dielectric + Metallic reflection - CORREGIDO
        float aspect = sqrt(1.0 - material.anisotropic * 0.9);
        float roughness_sq = material.roughness * material.roughness;
        float ax = max(0.001, roughness_sq / aspect);
        float ay = max(0.001, roughness_sq * aspect);

        vec3 T, B;
        TangentVectors(normal,tangent, T, B);

        vec3 micro_normal = GGXAnisotropicMicronormal(normal, T, B, ax, ay, random_seed);
        
        w_o = normalize(MicroReflect(w_i, micro_normal));

        bsdf_type = r3 < cdf[1] ? BSDF_DIFFUSE : BSDF_REFLECTION;
    }
    else { // Glass
        float theta_m;
        vec3 micro_normal = GGXMicronormal(normal, alpha, random_seed, theta_m);
        float VDotH = dot(w_i, micro_normal);

        float sin_theta = eta * eta * (1.0 - cos_theta_i * cos_theta_i);

        bool cannot_refract = (eta_i > eta_t && sin_theta > 1);

        if (cannot_refract || Schlick(cos_theta_i, eta) > rand(random_seed)) {
            w_o = MicroReflect(w_i, micro_normal);
            bsdf_type = BSDF_REFLECTION;
        }
        else {
            w_o = MicroTransmit(w_i, micro_normal, normal, eta);
            bsdf_type = BSDF_TRANSMISSION;
        }
    }
  
    return w_o;
}

void DisneyBSDFSample(inout rayPayload payload) {
    if (length(payload.material.emission) > 0) {
        if (dot(payload.surface_normal, -payload.direction) > 0)
            payload.bsdf_sample = payload.Le = payload.material.emission * payload.material.baseColor;
        else
            payload.bsdf_sample = payload.Le = vec3(0.f);

        payload.status = RAY_HIT_LIGHT;
    }
    else {
        payload.direction = normalize(payload.direction);
        vec3 new_direction = DisneyBSDFDirection(-payload.direction, payload.surface_normal, payload.tangent, payload.material, payload.bsdf_type, payload.random_seed);
        new_direction = normalize(new_direction);

        if(payload.backward_propagation == 0)
            DisneyBSDF(new_direction, -payload.direction, payload.surface_normal, payload.tangent, payload.material, payload.bsdf_sample, payload.pdfF, payload.pdfB, payload.random_seed);
        else
            DisneyBSDF(-payload.direction, new_direction, payload.surface_normal, payload.tangent, payload.material, payload.bsdf_sample, payload.pdfF, payload.pdfB, payload.random_seed);

        payload.direction = new_direction;
        payload.status = RAY_CONTINUE;
    }
}


#endif