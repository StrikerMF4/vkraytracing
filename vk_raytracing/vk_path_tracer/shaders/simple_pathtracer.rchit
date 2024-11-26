
#version 460
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_GOOGLE_include_directive : enable

#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_buffer_reference2 : require

#include "raycommon.glsl"
//#include "wavefront.glsl"
//#include "random.glsl"

hitAttributeEXT vec2 attribs;

// clang-format off
layout(location = 0) rayPayloadInEXT rayPayload payload;

layout(buffer_reference, scalar) buffer Vertices {Vertex v[]; }; // Positions of an object
layout(buffer_reference, scalar) buffer Indices {ivec3 i[]; }; // Triangle indices
layout(buffer_reference, scalar) buffer Materials {WaveFrontMaterial m[]; }; // Array of all materials on an object
layout(buffer_reference, scalar) buffer MatIndices {int i[]; }; // Material ID for each triangle
layout(set = 0, binding = eTlas) uniform accelerationStructureEXT topLevelAS;
layout(set = 1, binding = eObjDescs, scalar) buffer ObjDesc_ { ObjDesc i[]; } objDesc;
layout(set = 1, binding = eTextures) uniform sampler2D textureSamplers[];

layout(push_constant) uniform _PushConstantRayTracer { PushConstantRayTracer settings; };
// clang-format on


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

vec3 transmition(vec3 micro_normal, WaveFrontMaterial material) {
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
    float sin_theta = n * n * (1.0 - cos_theta*cos_theta);

    bool cannot_refract = (ni > nt && sin_theta > 1);

    payload.bsdf_sample = vec3(1);

    if (cannot_refract || Schlick(cos_theta, n) > rand(payload.random_seed))
    {
        payload.bsdf_type = BSDF_REFLECTION;
        return micro_reflect(-payload.direction, micro_normal);
    }
    else{
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
    } else {
        tangent = normalize(vec3(0.0, -normal.z, normal.y));
    }
    bitangent = normalize(cross(normal, tangent));

    // Transform sample vector from tangent space to world space
    vec3 sample_dir = x * tangent + y * bitangent + z * normal;

    return normalize(sample_dir);
}

void main() {
    //Object data-------------------------------------------------------------------------------------------
    ObjDesc    objResource = objDesc.i[gl_InstanceCustomIndexEXT];
    MatIndices matIndices  = MatIndices(objResource.materialIndexAddress);
    Materials  materials   = Materials(objResource.materialAddress);
    Indices    indices     = Indices(objResource.indexAddress);
    Vertices   vertices    = Vertices(objResource.vertexAddress);

    // Indices of the triangle
    ivec3 ind = indices.i[gl_PrimitiveID];
    //int ind = gl_PrimitiveID * 3;
    // Vertex of the triangle
    Vertex v0 = vertices.v[ind.x];
    Vertex v1 = vertices.v[ind.y];
    Vertex v2 = vertices.v[ind.z];
    const vec3 barycentrics = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
    // Computing the coordinates of the hit position
    const vec3 local_position = v0.pos * barycentrics.x + v1.pos * barycentrics.y + v2.pos * barycentrics.z;
    const vec3 hit_position = vec3(gl_ObjectToWorldEXT * vec4(local_position, 1.0));  // Transforming the position to world space
    // Computing the normal at hit position
    const vec3 local_normal = v0.nrm * barycentrics.x + v1.nrm * barycentrics.y + v2.nrm * barycentrics.z;
    payload.surface_normal = normalize(vec3(local_normal * gl_WorldToObjectEXT));  // Transforming the normal to world space

    
    // Material of the object
    int               matIdx = matIndices.i[gl_PrimitiveID];

    WaveFrontMaterial material    = materials.m[matIdx];

    // Texture
    vec3 texture_color = vec3(1);
    if(material.albedoTextureID >= 0) {
        uint txtId    = material.albedoTextureID + objDesc.i[gl_InstanceCustomIndexEXT].txtOffset;
        vec2 texCoord = v0.texCoord * barycentrics.x + v1.texCoord * barycentrics.y + v2.texCoord * barycentrics.z;
        texture_color = texture(textureSamplers[nonuniformEXT(txtId)], texCoord).xyz;
    }
    //--------------------------------------------------------------------------------------------------------

    
    vec3 albedo = material.color * texture_color;

    payload.origin = hit_position;
    if(length(material.emission) > 0) {
        // TO-DO: Cambiar esto por alguna aproximaci�n al L de Veach
        payload.bsdf_sample = material.emission * albedo;
        payload.Le = material.emission * albedo;
        payload.status = RAY_HIT_LIGHT;
    } else {
     

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
        float metallic     = clamp(material.metallic, 0.0, 1.0);
        float roughness    = clamp(material.roughness, 0.005, 1.0); // Minimum roughness to avoid singularities
        float alpha        = roughness * roughness;
        float transmission = 1 - clamp(material.transparent, 0.0, 1.0);
        float eta_i        = 1.0;           // Index of refraction of the incident medium (air)
        float eta_t        = material.IOR;  // Index of refraction of the transmitted medium (material)
        if (!entering) {
            // Swap indices if exiting the material
            float temp = eta_i;
            eta_i = eta_t;
            eta_t = temp;
        }
        float eta = eta_i / eta_t;

        float F0;
        vec3 Csheen, Cspec0;
        TintColors(albedo, eta, F0, Csheen, Cspec0); // void TintColors(vec3 color, float eta, out float F0, out vec3 Csheen, out vec3 Cspec0)

        float NdotV = dot(n,w_i);

        float schlickWt = SchlickWeight(NdotV);

        // Model weights
        float dielectricWt = (1.0 - metallic) * (1.0 - transmission);
        float glassWt = (1.0 - metallic) * transmission;

        float diffPr = dielectricWt * Luminance(albedo);
        float dielectricPr = dielectricWt * Luminance(mix(Cspec0, vec3(1.0), schlickWt));
        float metalPr = metallic * Luminance(mix(albedo, vec3(1.0), schlickWt));
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
            vec3 f_diffuse = albedo / PI;

            // Compute PDF
            float pdf = max(dot(n, w_o), 0.0) / PI;

            // Update payload
            payload.direction    = w_o;
            payload.bsdf_sample  = f_diffuse;
            payload.pdf          = pdf;
            payload.origin       = hit_position + payload.direction * 1e-4; // Offset to avoid self-intersection
            payload.status       = RAY_CONTINUE;
        }
        else if (rnd < cdf[2]) { // Dielectric + Metallic reflection

            // vec3 H = SampleGGXVNDF(V, state.mat.ax, state.mat.ay, r1, r2);
            float theta_m;
            vec3 micro_normal = ggx_micronormal(n, alpha, payload.random_seed, theta_m);
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

                float VDotH = dot(w_i,micro_normal);
                float F = (DielectricFresnel(VDotH, 1.0 / material.IOR) - F0) / (1.0 - F0);
                float pdf;
                vec3 f = EvalMicrofacetReflection(micro_normal, w_o, w_i, n, alpha, theta_m, mix(Cspec0, vec3(1.0), F), pdf);

                payload.direction    = w_o;
                payload.bsdf_sample  = f;
                payload.pdf          = pdf;
                payload.origin       = hit_position + payload.direction * 1e-4; // Offset to avoid self-intersection
                payload.status       = RAY_CONTINUE;
            }
            else {
                
            }
            
        }
        
    }
}

