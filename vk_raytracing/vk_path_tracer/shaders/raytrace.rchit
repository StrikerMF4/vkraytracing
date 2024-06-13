
#version 460
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_GOOGLE_include_directive : enable

#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_buffer_reference2 : require

#include "raycommon.glsl"
#include "wavefront.glsl"
#include "random.glsl"

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


//La saqué de github https://github.com/ekzhang/rpt/blob/master/src/material.rs

/// Bidirectional scattering distribution function
///
/// - `normal` - surface normal vector
/// - `wo` - unit direction vector toward the viewer
/// - `wi` - unit direction vector toward the incident ray
///
/// This works for both opaque and transmissive materials, based on a Beckmann
/// microfacet distribution model, Cook-Torrance shading for the specular component,
/// and Lambertian shading for the diffuse component. Useful references:
///
/// - http://www.codinglabs.net/article_physically_based_rendering_cook_torrance.aspx
/// - https://computergraphics.stackexchange.com/q/4394
/// - https://graphics.stanford.edu/courses/cs148-10-summer/docs/2006--degreve--reflection_refraction.pdf
/// - http://www.pbr-book.org/3ed-2018/Materials/BSDFs.html
/// - https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf
vec3 bsdf(vec3 normal, vec3 wo, vec3 wi, WaveFrontMaterial material) {
    float n_dot_wi = dot(normal, wi);
    float n_dot_wo = dot(normal, wo);
    bool wi_outside = n_dot_wi > 0;
    bool wo_outside = n_dot_wo > 0;

    


//    if (material.transparent > 0.999 && (!wi_outside || !wo_outside)) {
//        // Opaque materials do not transmit light
//        return vec3(0.0);
//    }
    if (wi_outside == wo_outside) {
        vec3 h = normalize(wi + wo); // halfway vector
        float wo_dot_h = dot(wo, h);
        float n_dot_h = dot(normal, h);
        float nh2 = n_dot_h * n_dot_h;

        // d: microfacet distribution function
        // D = exp(((normal . h)^2 - 1) / (m^2 (normal . h)^2)) / (pi m^2 (normal . h)^4)
        float m2 = material.roughness * material.roughness;
        float d = exp((nh2 - 1.0) / (m2 * nh2)) / (m2 * PI * nh2 * nh2);

        // f: fresnel, schlick's approximation
        // F = F0 + (1 - F0)(1 - wi . h)^5
        vec3 f = vec3(0);
        if (!wi_outside && sqrt(1.0 - wo_dot_h * wo_dot_h) * material.IOR > 1.0) {
            // Total internal reflection
            f = vec3(1.0);
        } else {
            float f0 = pow((material.IOR - 1.0) / (material.IOR + 1.0), 2);
            vec3 f1 = mix(vec3(f0), material.color, material.metallic);
            f = f1 + (vec3(1.0) - f1) * pow(1.0 - wo_dot_h, 5);
        }

        // g: geometry function, microfacet shadowing
        // G = min(1, 2(normal . h)(normal . wo)/(wo . h), 2(normal . h)(normal . wi)/(wo . h))
        float g = min(n_dot_wi * n_dot_h, n_dot_wo * n_dot_h);
        g = (2.0 * g) / wo_dot_h;
        g = min(g, 1.0);

        // BRDF: putting it all together
        // Cook-Torrance = DFG / (4(normal . wi)(normal . wo))
        // Lambert = (1 - F) * c / pi
        vec3 specular = d * f * g / (4.0 * n_dot_wo * n_dot_wi);

        if (material.transparent < 1.0) {
            return specular;
        } else {
            vec3 diffuse = (vec3(1.0) - f) * material.color / PI;
            return specular + diffuse;
        }
    } else {
        // Ratio of refractive indices, n_i / n_o
        float eta_t = 0;
        if (wo_outside) {
            eta_t = material.IOR;
        } else {
            eta_t = 1.0 / material.IOR;
        };
        vec3 h = normalize(wi * eta_t + wo); // halfway vector
        float wi_dot_h = dot(wi, h);
        float wo_dot_h = dot(wo, h);
        float n_dot_h = dot(normal, h);
        float nh2 = pow(n_dot_h, 2);

        // d: microfacet distribution function
        // D = exp(((normal . h)^2 - 1) / (m^2 (normal . h)^2)) / (pi m^2 (normal . h)^4)
        float m2 = material.roughness * material.roughness;
        float d = exp((nh2 - 1.0) / (m2 * nh2)) / (m2 * PI * nh2 * nh2);

        // f: fresnel, schlick's approximation
        // F = F0 + (1 - F0)(1 - wi . h)^5
        float f0 = pow((material.IOR - 1.0) / (material.IOR + 1.0), 2.0);
        vec3 f1 = mix(vec3(f0), material.color, material.metallic);
        vec3 f = f1 + (vec3(1.0) - f1) * pow(1.0 - abs(wi_dot_h), 5);

        // g: geometry function, microfacet shadowing
        // G = min(1, 2(normal . h)(normal . wo)/(wo . h), 2(normal . h)(normal . wi)/(wo . h))
        float g = min(abs(n_dot_wi * n_dot_h), abs(n_dot_wo * n_dot_h));
        g = (2.0 * g) / abs(wo_dot_h);
        g = min(g, 1.0);

        // BTDF: putting it all together
        // Cook-Torrance = |h . wi|/|normal . wi| * |h . wo|/|normal . wo|
        //                  * n_o^2 (1 - F)DG / (n_i (h . wi) + n_o (h . wo))^2
        vec3 btdf = abs(wi_dot_h * wo_dot_h / (n_dot_wi * n_dot_wo))
            * (d * (vec3(1.0) - f) * g / pow(eta_t * wi_dot_h + wo_dot_h, 2));
        return btdf * material.color;
    }
}

float chiGGX(float v)
{
    return v > 0 ? 1 : 0;
}

float GGX_Distribution(vec3 n, vec3 h, float alpha)
{
    float NoH = dot(n,h);
    float alpha2 = alpha * alpha;
    float NoH2 = NoH * NoH;
    float den = NoH2 * alpha2 + (1 - NoH2);
    return (chiGGX(NoH) * alpha2) / ( PI * den * den );
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
    if(material.textureId >= 0) {
        uint txtId    = material.textureId + objDesc.i[gl_InstanceCustomIndexEXT].txtOffset;
        vec2 texCoord = v0.texCoord * barycentrics.x + v1.texCoord * barycentrics.y + v2.texCoord * barycentrics.z;
        texture_color = texture(textureSamplers[nonuniformEXT(txtId)], texCoord).xyz;
    }
    //--------------------------------------------------------------------------------------------------------

    payload.origin = hit_position;
    if(length(material.emittance) > 0) {
        // TO-DO: Cambiar esto por alguna aproximación al L de Veach
        payload.Le = 3 * material.emittance * texture_color.rgb;
        payload.status = HIT_LIGHT;
    } else {
        
        //Primero, determinar la nueva dirección basado en el material
        //Luego, se calcula el BSDF según esta nueva dirección

        //Cuando la nueva dirección está en el sentido de la normal, se calcula el BRDF
        //Cuando la nueva dirección está en el sentido opuesto a la normal, se calcula el BTDF

        //Habría que hacer una ruleta rusa para saber si rebota o se transmite? (en el caso de que pueda hacer las dos cosas)
        //el "rebota" pude ser por lo difuso o por el brillo glossy, pero se elige la dirección de la misma forma 
        //  (si en la dirección elegida el glossy no afecta, va a aportar poco al BRDF)

        vec3 wi = vec3(0.0f);

        float rnd = rand(payload.random_seed);

        float diff_prob = 1 - material.metallic;
        float trans_prob = 1 - material.transparent;
        
        if(rand(payload.random_seed) < trans_prob){
            const float angle = dot(payload.direction, payload.surface_normal);
            const vec3 outwardNormal = angle > 0 ? -payload.surface_normal : payload.surface_normal;
            const float niOverNt = angle > 0 ? material.IOR : 1 / material.IOR;
            const float cosine = angle > 0 ? material.IOR * angle : -angle;

            if(rand(payload.random_seed) > Schlick(cosine, material.IOR)){
                wi = refract(payload.direction, outwardNormal, niOverNt);
            }
            else{
                wi = reflect(payload.direction, payload.surface_normal);
            }
            payload.bsdf_sample = material.color;
        }
        else if(rand(payload.random_seed) < diff_prob){
            wi = normalize(payload.surface_normal + RandomInUnitSphere(payload.random_seed));

            float eta_t = 0;
            float n_dot_wo = dot(payload.surface_normal, -payload.direction);
            bool wo_outside = n_dot_wo > 0;
            if (wo_outside) {
                eta_t = material.IOR;
            } else {
                eta_t = 1.0 / material.IOR;
            };
            vec3 h = normalize(wi * eta_t + -payload.direction);
            //float micro = GGX_Distribution(payload.surface_normal, h, material.roughness);


            payload.bsdf_sample = material.color;// * micro;// / PI;
        }
        else{
            wi = reflect(payload.direction, payload.surface_normal);
            payload.bsdf_sample = material.color;
        }
        //vec3 normal, vec3 wo, vec3 wi, WaveFrontMaterial material
        //payload.bsdf_sample = bsdf(payload.surface_normal, -payload.direction, wi, material);// material.color;

        payload.direction = wi;
    }
}

