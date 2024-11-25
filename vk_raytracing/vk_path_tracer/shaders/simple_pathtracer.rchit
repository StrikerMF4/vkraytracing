
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
        float metallic     = 0;
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

        // Fresnel reflectance at normal incidence (F0)
        vec3 F0;
        /* if (metallic > 0.0) {
            // For metals, F0 is the albedo color
            F0 = albedo;
        } else {
            // For dielectrics, use Schlick's approximation with IOR
            float r0 = pow((eta_i - eta_t) / (eta_i + eta_t), 2.0);
            F0 = vec3(r0);
        }
        */

        F0 = mix(vec3(0.04), albedo, metallic);

        // Compute Fresnel reflectance using Schlick's approximation
        vec3 F = F0 + (vec3(1.0) - F0) * pow(1.0 - max(cos_theta_i, 0.0), 5.0);
        // vec3 F = F0;

        float reflectance = dot(F, vec3(0.2126, 0.7152, 0.0722));

        // Determine scattering probabilities
        float P_reflect = reflectance;
        float P_diffuse  = (1.0 - metallic) * (1.0 - transmission) * (1.0 - reflectance);
        float P_transmit = transmission * (1.0 - metallic) * (1.0 - reflectance);



        /*if (metallic > 0.0 || transmission > 0.0) {
            // For metals and transparent materials, use Fresnel reflectance
            P_reflect = dot(F, vec3(0.2126, 0.7152, 0.0722));
        } else {
            // For dielectrics, adjust reflectance probability
            P_reflect = dot(F, vec3(0.2126, 0.7152, 0.0722));
            P_diffuse *= (1.0 - P_reflect);
        }
        */


        // Normalize probabilities
        float sum_probs = P_reflect + P_transmit + P_diffuse;
        P_reflect  /= sum_probs;
        P_transmit /= sum_probs;
        P_diffuse  /= sum_probs;

        // Generate a random number to select the scattering event
        float rnd = rand(payload.random_seed);

        if (rnd < P_reflect) {
            // Specular Reflection

            // Sample microfacet normal using GGX distribution
            float theta_m;
            vec3 micro_normal = ggx_micronormal(n, alpha, payload.random_seed, theta_m);

            // Compute outgoing direction
            vec3 w_o = micro_reflect(w_i, micro_normal);

            // Ensure that the outgoing direction is in the same hemisphere
            if (dot(w_o, n) <= 0.0 || dot(payload.direction, n) > 0.0) {
                payload.status = RAY_ABSORBED;
                return;
            }

            // Compute BRDF value
            float cos_theta_o = max(dot(n, w_o), 0.0);
            F = F0 + (vec3(1.0) - F0) * pow(1.0 - max(cos_theta_o, 0.0), 5.0);
            float D = GGX_D(micro_normal, n, alpha, theta_m);
            float G = GGX_G(w_i, w_o, micro_normal, n, alpha);
            float denom = 4.0 * max(cos_theta_i, 0.01) * max(cos_theta_o, 0.01);
            vec3 f_specular = F * min((D * G) / denom, 1);

            // Compute denominator
            // float denominator = 4.0 * abs(dot(-payload.direction, payload.surface_normal)) * abs(dot(payload.direction, payload.surface_normal)) + 1e-7;
            // float denominator = abs(dot(micro_normal, n)) * abs(dot(w_i, n));

            // Compute specular BRDF
            // vec3 f_specular = F * ((G * abs(dot(w_i, micro_normal))) / denominator);

            // Set bsdf_sample and pdf
            payload.bsdf_sample = f_specular;


            // Compute PDF
            float pdf = D * abs(dot(n, micro_normal)) / (4.0 * abs(dot(w_o, micro_normal)) + 1e-7);

            // Update payload
            payload.direction    = w_o;
            // payload.bsdf_sample  = F;
            payload.pdf          = pdf;
            payload.origin       = hit_position + payload.direction * 1e-4; // Offset to avoid self-intersection
            payload.status       = RAY_CONTINUE;

        } else if (rnd < 0) {
            // Transmission (Refraction)

            // Only proceed if the material is transparent
            if (transmission > 0.0) {
                // Sample microfacet normal
                float theta_m, phi_m;
                vec3 micro_normal = ggx_micronormal(n, alpha, payload.random_seed, theta_m);

                // Compute refracted direction using Snell's Law
                vec3 w_o = micro_transmit(w_i, micro_normal, n, eta);

                // Check for total internal reflection
                if (length(w_o) == 0.0) {
                    // Total internal reflection, treat as reflection
                    w_o = micro_reflect(w_i, micro_normal);
                }

                // Compute Fresnel transmittance
                vec3 T = vec3(1.0) - F;

                // Compute BTDF value
                float D = GGX_D(micro_normal, n, alpha, theta_m);
                float G = GGX_G(w_i, w_o, micro_normal, n, alpha);
                float denom = abs(dot(n, w_i)) * abs(dot(n, w_o)) + 1e-7;
                vec3 f_transmission = (T * D * G * eta * eta) / denom;

                // Adjust for refracted solid angle
                f_transmission *= abs(dot(w_i, micro_normal)) * abs(dot(w_o, micro_normal)) / (abs(dot(n, w_i)) * abs(dot(n, w_o)) + 1e-7);

                // Compute PDF
                float pdf = D * abs(dot(n, micro_normal)) * abs(dot(w_o, micro_normal)) / pow(abs(dot(w_i, micro_normal) + eta * dot(w_o, micro_normal)), 2.0);

                // Update payload
                payload.direction    = w_o;
                payload.bsdf_sample  = f_transmission;
                payload.pdf          = pdf;
                payload.origin       = hit_position + payload.direction * 1e-4; // Offset to avoid self-intersection
                payload.status       = RAY_CONTINUE;

                // Apply Beer's Law for absorption
                // float distance = 0.0; // You may need to compute the actual distance
                // vec3 absorption = exp(-material.absorption * distance);
                // payload.bsdf_sample *= absorption;

            } else {
                // Material is not transparent, absorb the ray
                payload.status = RAY_ABSORBED;
            }

        } else {
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
    }
}

