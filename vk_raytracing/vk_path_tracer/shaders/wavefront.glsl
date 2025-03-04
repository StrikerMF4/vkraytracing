#ifndef WAVEFRONT
#define WAVEFRONT

#include "raycommon.glsl"
#include "random.glsl"

float geometric_term(vec3 xi, vec3 ni, vec3 xo, vec3 no){
    vec3 x_diff = xo - xi;
    vec3 x_diff_norm = normalize(x_diff);

    float cos_theta_i = dot(ni, x_diff_norm);
    float cos_theta_o = dot(no, x_diff_norm);

    return abs(cos_theta_o * cos_theta_i) / (dot(x_diff, x_diff) + EPSILON);
}


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

    return D * F * G / (4 * abs(dot(normal, w_i)) * abs(dot(normal, w_o)) + EPSILON);
}


/* DISNEY */

float Luminance(vec3 c)
{
    return 0.212671 * c.x + 0.715160 * c.y + 0.072169 * c.z;
}

void TintColors(WaveFrontMaterial material, float eta, out float F0, out vec3 Csheen, out vec3 Cspec0)
{
    float lum = Luminance(material.baseColor);
    vec3 ctint = lum > 0.0 ? material.baseColor / lum : vec3(1.0);

    F0 = (1.0 - eta) / (1.0 + eta);
    F0 *= F0;
    
    Cspec0 = F0 * mix(vec3(1.0), ctint, material.specularTint);
    Csheen = mix(vec3(1.0), ctint, material.sheenTint);
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

    float rs = (eta * cosThetaT - cosThetaI) / (eta * cosThetaT + cosThetaI + EPSILON);
    float rp = (eta * cosThetaI - cosThetaT) / (eta * cosThetaI + cosThetaT + EPSILON);

    return 0.5f * (rs * rs + rp * rp);
}

/* DISNEY START */


float GGXAnisotropicD(vec3 w, float ax, float ay)
{
    float a = w.x / ax;
    float b = w.y / ay;

    float c = a * a + b * b + w.z * w.z;

    return 1.0f / (PI * ax * ay * c * c);
}

float GTR2Aniso(float NDotH, float HDotX, float HDotY, float ax, float ay)
{
    float a = HDotX / ax;
    float b = HDotY / ay;
    float c = a * a + b * b + NDotH * NDotH;
    return 1.0 / (PI * ax * ay * c * c);
}


float SmithG(float NDotV, float alphaG)
{
    float a = alphaG * alphaG;
    float b = NDotV * NDotV;
    return (2.0 * NDotV) / (NDotV + sqrt(a + b - a * b));
}

float SmithGAniso(float NDotV, float VDotX, float VDotY, float ax, float ay)
{
    float a = VDotX * ax;
    float b = VDotY * ay;
    float c = NDotV;
    return (2.0 * NDotV) / (NDotV + sqrt(a * a + b * b + c * c));
}


//float SeparableSmithGGXG1(vec3 w, float ax, float ay)
//{
//    float theta = acos(w.z); // check if w is normalized
//    float phi = sign(w.y) * acos(w.x / sqrt(w.x * w.x + w.y * w.y));
//    float a1 = cos(phi) * ax;
//    float a2 = sin(phi) * ay;
//    float a = 1 / (tan(theta) * sqrt(a1 * a1 + a2 * a2));
//    float delta = (-1.0 + sqrt(1.0 + ( 1.0 / (a * a)))) / 2.0;
//    return 1.0 / (1.0 + delta);
//}

float SeparableSmithGGXG1(vec3 w, float ax, float ay)
{
    float a1 = w.x * ax;
    float a2 = w.y * ay;
    float a = (a1 * a1 + a2 * a2) / (w.z * w.z);
    float delta = (-1.0 + sqrt(1.0 + a)) / 2.0;
    return 1.0 / (1.0 + delta);
}

float GTR1(float NDotH, float a)
{
    if (a >= 1.0)
        return INV_PI;
    float a2 = a * a;
    float t = 1.0 + (a2 - 1.0) * NDotH * NDotH;
    return (a2 - 1.0) / (PI * log(a2) * t);
}

vec3 SampleGTR1(float rgh, float r1, float r2)
{
    float a = max(0.001, rgh);
    float a2 = a * a;

    float phi = r1 * TWO_PI;

    float cosTheta = sqrt((1.0 - pow(a2, 1.0 - r2)) / (1.0 - a2));
    float sinTheta = clamp(sqrt(1.0 - (cosTheta * cosTheta)), 0.0, 1.0);
    float sinPhi = sin(phi);
    float cosPhi = cos(phi);

    return vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
}

vec3 SampleGGXVNDF(vec3 V, float ax, float ay, float r1, float r2)
{
    vec3 Vh = normalize(vec3(ax * V.x, ay * V.y, V.z));

    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    vec3 T1 = lensq > 0 ? vec3(-Vh.y, Vh.x, 0) * inversesqrt(lensq) : vec3(1, 0, 0);
    vec3 T2 = cross(Vh, T1);

    float r = sqrt(r1);
    float phi = 2.0 * PI * r2;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

    vec3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * Vh;

    return normalize(vec3(ax * Nh.x, ay * Nh.y, max(0.0, Nh.z)));
}

vec3 EvalDisneyDiffuse(WaveFrontMaterial material, vec3 Csheen, vec3 w_i, vec3 w_o, vec3 H, vec3 normal, out float pdf)
{
    pdf = 0.0;

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

    pdf = ODotN * INV_PI;
    return INV_PI * material.baseColor * mix(Fd + Fretro, ss, material.subsurface) + Fsheen;
}

vec3 EvalMicrofacetReflection(WaveFrontMaterial material, vec3 w_i, vec3 w_o, vec3 normal, vec3 H, vec3 F, out float pdf)
{
    pdf = 0.0;

    float ODotN = dot(normal, w_o);
    if (ODotN <= 0.0)
        return vec3(0.0);

    float IDotN = dot(normal, w_i);

    float aspect = sqrt(1.0 - material.anisotropic * 0.9);
    float ax = max(0.001, material.roughness * material.roughness / aspect);
    float ay = max(0.001, material.roughness * material.roughness * aspect);

    float D = GGXAnisotropicD(H, ax, ay);
    float G1 = SeparableSmithGGXG1(w_i, ax, ay);
    float G2 = G1 * SeparableSmithGGXG1(w_o, ax, ay);
//    float D = GTR2Aniso(H.z, H.x, H.y, ax, ay);
//    float G1 = SmithGAniso(abs(V.z), V.x, V.y, ax, ay);
//    float G2 = G1 * SmithGAniso(abs(L.z), L.x, L.y, ax, ay);

    pdf = G1 * D / (4.0 * IDotN);
    return F * D * G2 / (4.0 * ODotN * IDotN);
}

//vec3 EvalMicrofacetRefraction(WaveFrontMaterial material, vec3 w_i, vec3 w_o, vec3 normal, vec3 H, vec3 F, float eta, out float pdf)
//{
//    pdf = 0.0;
//    float ODotN = dot(normal, w_o);
//    float IDotN = dot(normal, w_i);
//
//    float ODotH = dot(w_o, H);
//    float IDotH = dot(w_i, H);
//
//    float aspect = sqrt(1.0 - material.anisotropic * 0.9);
//    float ax = max(0.001, material.roughness * material.roughness / aspect);
//    float ay = max(0.001, material.roughness * material.roughness * aspect);
//
//    float D = GGXAnisotropicD(H, ax, ay) + 0.001;
//    float G1 = SeparableSmithGGXG1(w_i, ax, ay) + 0.001;
//    float G2 = G1 * SeparableSmithGGXG1(w_o, ax, ay) + 0.001;
//
//    float denom = ODotH + eta * IDotH;
//    denom *= denom;
//    float eta2 = eta * eta;
//    float jacobian = abs(ODotH) / denom;
//        
//    pdf = G1 * max(0.0, IDotH) * D * jacobian / IDotN;
//    return sqrt(material.baseColor) * (1.0 - F) * D * G2 * abs(IDotH) * jacobian * eta2 / abs(ODotN * IDotN);
////    float c = (abs(ODotH) * abs(IDotH)) / (abs(ODotN) * abs(IDotN));
////    float den = (IDotH + material.ior * ODotH);
////    float t = ((material.ior * material.ior) / (den * den)); 
////    return material.baseColor * D * G2 * c * t;
////    return (1.0 - F) * D * G2 * eta2 * abs(IDotH * ODotH) / (denom * abs(IDotN * ODotN));
//}

// todo: define equation
vec3 EvalMicrofacetRefraction(WaveFrontMaterial material, vec3 w_i, vec3 w_o, vec3 normal, vec3 H, vec3 F, float eta_i, float eta_t, out float pdf)
{
    pdf = 0.0;
    float ODotN = dot(normal, w_o);
    float IDotN = dot(normal, w_i);

    vec3 h_t = -(eta_i* w_i + eta_t * w_o);

    float ODotH = dot(w_o, h_t);
    float IDotH = dot(w_i, h_t);

    float aspect = sqrt(1.0 - material.anisotropic * 0.9);
    float ax = max(0.001, material.roughness * material.roughness / aspect);
    float ay = max(0.001, material.roughness * material.roughness * aspect);

    float D = GGXAnisotropicD(h_t, ax, ay) + 0.001;
    float G1 = SeparableSmithGGXG1(w_i, ax, ay) + 0.001;
    float G2 = G1 * SeparableSmithGGXG1(w_o, ax, ay) + 0.001;

    float eta2 = eta_t * eta_t;
        
    pdf = G1 * abs(IDotH) * D  / abs(IDotN);
    float c = (abs(ODotH) * abs(IDotH)) / (abs(ODotN) * abs(IDotN));
    float t = ((material.ior * material.ior)); 
//    return sqrt(material.baseColor) * (1.0 - F) * D * G2 * c * t;
    return sqrt(material.baseColor) * (1.0 - F) * D * G2 * abs(IDotH) * eta2 / abs(ODotN * IDotN);
//    return (1.0 - F) * D * G2 * eta2 * abs(IDotH * ODotH) / (denom * abs(IDotN * ODotN));
}

vec3 EvalClearcoat(WaveFrontMaterial material, vec3 V, vec3 L, vec3 H, out float pdf)
{
    pdf = 0.0;
    if (L.z <= 0.0)
        return vec3(0.0);

    float VDotH = dot(V, H);

    float clearcoatRoughness = mix(0.1, 0.001, material.clearcoatGloss);

    float F = mix(0.04, 1.0, SchlickWeight(VDotH));
    float D = GTR1(H.z, clearcoatRoughness);
    float G = SmithG(L.z, 0.25) * SmithG(V.z, 0.25);
    float jacobian = 1.0 / (4.0 * VDotH);

    pdf = D * H.z * jacobian;
    return vec3(F) * D * G;
}

/* END DISNEY */


vec3 EvalMicrofacetReflection(vec3 micro_normal, vec3 w_o, vec3 w_i, vec3 n, float alpha, float theta_m, vec3 F, out float pdf)
{
    pdf = 0.0;
    float IDotN = dot(n, w_i) + EPSILON;
    float ODotN = dot(n, w_o) + EPSILON;

    //float D = GTR2Aniso(H.z, H.x, H.y, mat.ax, mat.ay);
    float D = GGX_D(micro_normal, n, alpha, theta_m);
    // float G1 = SmithGAniso(abs(V.z), V.x, V.y, mat.ax, mat.ay); (ODotN = L.z; IDotN = V.z; NDotH = H.z)
    // float G2 = G1 * SmithGAniso(abs(L.z), L.x, L.y, mat.ax, mat.ay);
    float G = GGX_G(w_i, w_o, micro_normal, n, alpha);

    // D * abs(dot(n, micro_normal)) / (4.0 * abs(dot(w_o, micro_normal)) + 1e-7);
    pdf = abs(dot(n, micro_normal)) * D / (4.0 * IDotN);
    return F * D * G / ((4.0 * ODotN * IDotN) + EPSILON);
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

vec3 CosineSampleHemisphere(float r1, float r2)
{
    vec3 dir;
    float r = sqrt(r1);
    float phi = TWO_PI * r2;
    dir.x = r * cos(phi);
    dir.y = r * sin(phi);
    dir.z = sqrt(max(0.0, 1.0 - dir.x * dir.x - dir.y * dir.y));
    return dir;
}

vec3 ToWorld(vec3 X, vec3 Y, vec3 Z, vec3 V)
{
    return V.x * X + V.y * Y + V.z * Z;
}

vec3 ToLocal(vec3 X, vec3 Y, vec3 Z, vec3 V)
{
    return vec3(dot(V, X), dot(V, Y), dot(V, Z));
}

void TangentVectors(in vec3 N, inout vec3 T, inout vec3 B)
{
    vec3 up = abs(N.z) < 0.9999999 ? vec3(0, 0, 1) : vec3(1, 0, 0);
    T = normalize(cross(up, N));
    B = cross(N, T);
}

void disney_pdf(vec3 w_o, vec3 w_i, vec3 normal, WaveFrontMaterial material, out vec3 outputColor, out float pdf, inout uint random_seed)
{
    pdf = 0.0;
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
    
    vec3 H;
    if (ODotN > 0.0)
        H = normalize(w_i + w_o);
    else
        H = normalize(w_i + w_o * eta);

    float NDotH = dot(normal, H);

    if (NDotH < 0.0)
        H = -H;


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

    float tmpPdf = 0.0;
    float IDotH = clamp(dot(w_i, H), 0.0, 1.0);

    if (diffPr > 0.0 && reflect) { // Diffuse
        f += EvalDisneyDiffuse(material, Csheen, w_i, w_o, H, normal, tmpPdf) * dielectricWt;
        pdf += tmpPdf * diffPr;
    }
    
    if (dielectricPr > 0.0 && reflect) { // Dielectric Reflection
        // Normalize for interpolating based on Cspec0
        float F = (DielectricFresnel(IDotH, 1.0 / material.ior) - F0) / (1.0 - F0);

        f += EvalMicrofacetReflection(material, w_i, w_o, normal, H, mix(Cspec0, vec3(1.0), F), tmpPdf) * dielectricWt;
        pdf += tmpPdf * dielectricPr;
    }
    
    if (metalPr > 0.0 && reflect) { // Metallic Reflection
        vec3 F = mix(material.baseColor, vec3(1.0), SchlickWeight(IDotH));

        f += EvalMicrofacetReflection(material, w_i, w_o, normal, H, F, tmpPdf)  * metalWt;
        pdf += tmpPdf * metalPr;
    }
    
    if (glassPr > 0.0) { // Glass/Specular BSDF
        // Dielectric fresnel (achromatic)
        float F = DielectricFresnel(dot(w_i, normal), eta);

        if (reflect)
        {
            f += EvalMicrofacetReflection(material, w_i, w_o, normal, H, vec3(F), tmpPdf) * glassWt;
            pdf += tmpPdf * glassPr * F;
        }
        else
        {
            f += EvalMicrofacetRefraction(material, w_i, w_o, normal, H, vec3(F), eta_i, eta_t, tmpPdf) * glassWt;
//            pdf += tmpPdf * glassPr * (1.0 - F);
            pdf += tmpPdf * glassPr;
        }
    }
//
//    if (clearCtPr > 0.0 && reflect) { // Clearcoat
//        f += EvalClearcoat(material, V, L, H, tmpPdf) * 0.25 * material.clearcoat;
//        pdf += tmpPdf * clearCtPr;
//    }

    outputColor = f;
}

vec3 disney_bsdf(vec3 w_i, vec3 normal, WaveFrontMaterial material, inout uint bsdf_type, inout uint random_seed) {
    float cos_theta_i = dot(normal, w_i);
    cos_theta_i = clamp(cos_theta_i, -1.0, 1.0);
    // Determine if the ray is entering or exiting the material
    bool entering = cos_theta_i >= 0.0;
    float eta_i = 1;
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
    if (r3 < cdf[0]) // Diffuse
    {
        w_o = RandomCosineHemisphereDirection(normal, random_seed);
        bsdf_type = BSDF_DIFFUSE;
    }
    else if (r3 < cdf[2])  // Dielectric + Metallic reflection
    {
        
        float theta_m;
        vec3 micro_normal = ggx_micronormal(normal, alpha, random_seed, theta_m);
        w_o = normalize(micro_reflect(w_i, micro_normal));

        bsdf_type = BSDF_REFLECTION;
    }
    else // Glass
    {
        float theta_m;
        vec3 micro_normal = ggx_micronormal(normal, alpha, random_seed, theta_m);
        float VDotH = dot(w_i, micro_normal);

        float sin_theta = eta * eta * (1.0 - cos_theta_i * cos_theta_i);

        bool cannot_refract = (eta_i > eta_t && sin_theta > 1);

        if (cannot_refract || Schlick(cos_theta_i, eta) > rand(random_seed))
        {
            w_o = micro_reflect(w_i, micro_normal);
            bsdf_type = BSDF_REFLECTION;
        }
        else 
        {
            w_o = micro_transmit(w_i, micro_normal, normal, eta);
            bsdf_type = BSDF_TRANSMISSION;
        }
    }
    // Clearcoat
  
    return w_o;
}

void disney_bsdf_sample(inout rayPayload payload) {
    if (length(payload.material.emission) > 0) {
        // TO-DO: Cambiar esto por alguna aproximacion al L de Veach
        payload.bsdf_sample = payload.material.emission * payload.material.baseColor;
        payload.Le = payload.material.emission * payload.material.baseColor;
        payload.status = RAY_HIT_LIGHT;
    }
    else {
        payload.direction = normalize(payload.direction);
        vec3 new_direction = disney_bsdf(-payload.direction, payload.surface_normal, payload.material, payload.bsdf_type, payload.random_seed);
        new_direction = normalize(new_direction);
        if(!payload.backward_propagation) {
            disney_pdf(new_direction, -payload.direction, payload.surface_normal, payload.material, payload.bsdf_sample, payload.pdf, payload.random_seed);
        }
        else{
            disney_pdf(-payload.direction, new_direction, payload.surface_normal, payload.material, payload.bsdf_sample, payload.pdf, payload.random_seed);
        }

        payload.direction = new_direction;
        payload.status = RAY_CONTINUE;
    }
}


#endif