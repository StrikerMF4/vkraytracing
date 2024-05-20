
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

layout(push_constant) uniform _PushConstantRay { PushConstantRay pcRay; };
// clang-format on


void main() {
    //Object data-------------------------------------------------------------------------------------------
    ObjDesc    objResource = objDesc.i[gl_InstanceCustomIndexEXT];
    MatIndices matIndices  = MatIndices(objResource.materialIndexAddress);
    Materials  materials   = Materials(objResource.materialAddress);
    Indices    indices     = Indices(objResource.indexAddress);
    Vertices   vertices    = Vertices(objResource.vertexAddress);

    // Indices of the triangle
    ivec3 ind = indices.i[gl_PrimitiveID];
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
    if(length(material.emission) > 0) {
        // TO-DO: Cambiar esto por alguna aproximación al L de Veach
        payload.bsdf_sample = 3 * material.emission * texture_color.rgb;
        payload.status = HIT_LIGHT;
    } else {
        
        //Primero, determinar la nueva dirección basado en el material
        //Luego, se calcula el BSDF según esta nueva dirección

        //Cuando la nueva dirección está en el sentido de la normal, se calcula el BRDF
        //Cuando la nueva dirección está en el sentido opuesto a la normal, se calcula el BTDF

        //Habría que hacer una ruleta rusa para saber si rebota o se transmite? (en el caso de que pueda hacer las dos cosas)
        //el "rebota" pude ser por lo difuso o por el brillo glossy, pero se elige la dirección de la misma forma 
        //  (si en la dirección elegida el glossy no afecta, va a aportar poco al BRDF)



        //En el programa actual cada material tiene una posible cualidad
        float reflectProb;
        switch (material.illum) {
            case 5: //metal
                payload.bsdf_sample = material.specular * texture_color.rgb;
                payload.status = CONTINUE;//isScattered ? 1 : 0;
                payload.direction = reflect(payload.direction, payload.surface_normal) + pcRay.fuzziness*RandomInUnitSphere(payload.random_seed); //editar parametro para fuzzy material
                break;
            case 7:	//dielectric
                const float dot = dot(payload.direction, payload.surface_normal);
                const vec3 outwardNormal = dot > 0 ? -payload.surface_normal : payload.surface_normal;
                const float niOverNt = dot > 0 ? material.ior : 1 / material.ior;
                const float cosine = dot > 0 ? material.ior * dot : -dot;
                const vec3 refracted = refract(payload.direction, outwardNormal, niOverNt);
                reflectProb = refracted != vec3(0) ? Schlick(cosine, material.ior) : 1; //total internal refraction
                payload.bsdf_sample = material.specular * texture_color.rgb;
                payload.status = CONTINUE;
                payload.direction = rnd(payload.random_seed) < reflectProb
                    ? reflect(payload.direction, payload.surface_normal)
                    : refracted;
                payload.direction += 0.0 * RandomInUnitSphere(payload.random_seed);
                break;
            default: //lambetian and glossy (se modula con respecto al coeficiente specular)
                //const bool isScattered = dot(payload.direction, payload.surface_normal) < 0;
                reflectProb = max(max(material.specular.x, material.specular.y),  material.specular.z);
                payload.bsdf_sample = material.diffuse.rgb * texture_color.rgb;
                payload.status = CONTINUE;//isScattered ? 1 : 0;
                payload.direction = rnd(payload.random_seed) < reflectProb
                    ? reflect(payload.direction, payload.surface_normal) + (pcRay.shininess/material.shininess)*RandomInUnitSphere(payload.random_seed)
                    : payload.surface_normal + RandomInUnitSphere(payload.random_seed);
        }
    }
}

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
//float bsdf(normal: &glm::DVec3, wo: &glm::DVec3, wi: &glm::DVec3) -> Color {
//    float n_dot_wi = normal.dot(wi);
//    float n_dot_wo = normal.dot(wo);
//    bool wi_outside = n_dot_wi > 0;
//    bool wo_outside = n_dot_wo > 0;
//    if (!self.transparent && (!wi_outside || !wo_outside)) {
//        // Opaque materials do not transmit light
//        return glm::vec3(0.0, 0.0, 0.0);
//    }
//    if (wi_outside == wo_outside) {
//        vec3 h = (wi + wo).normalize(); // halfway vector
//        float wo_dot_h = wo.dot(&h);
//        float n_dot_h = normal.dot(&h);
//        float nh2 = n_dot_h * n_dot_h;
//
//        // d: microfacet distribution function
//        // D = exp(((normal . h)^2 - 1) / (m^2 (normal . h)^2)) / (pi m^2 (normal . h)^4)
//        float m2 = self.roughness * self.roughness;
//        float d = ((nh2 - 1.0) / (m2 * nh2)).exp() / (m2 * glm::pi::<f64>() * nh2 * nh2);
//
//        // f: fresnel, schlick's approximation
//        // F = F0 + (1 - F0)(1 - wi . h)^5
//        vec3 f = 0;
//        if !wi_outside && (1.0 - wo_dot_h * wo_dot_h).sqrt() * self.index > 1.0 {
//            // Total internal reflection
//            f = vec3(1.0, 1.0, 1.0)
//        } else {
//            let f0 = ((self.index - 1.0) / (self.index + 1.0)).powi(2);
//            let f0 = glm::lerp(vec3(f0, f0, f0), self.color, self.metallic);
//            f0 + (vec3(1.0, 1.0, 1.0) - f0) * (1.0 - wo_dot_h).powi(5)
//        };
//
//        // g: geometry function, microfacet shadowing
//        // G = min(1, 2(normal . h)(normal . wo)/(wo . h), 2(normal . h)(normal . wi)/(wo . h))
//        let g = f64::min(n_dot_wi * n_dot_h, n_dot_wo * n_dot_h);
//        let g = (2.0 * g) / wo_dot_h;
//        let g = g.min(1.0);
//
//        // BRDF: putting it all together
//        // Cook-Torrance = DFG / (4(normal . wi)(normal . wo))
//        // Lambert = (1 - F) * c / pi
//        float specular = d * f * g / (4.0 * n_dot_wo * n_dot_wi);
//        if self.transparent {
//            specular
//        } else {
//            let diffuse =
//                (glm::vec3(1.0, 1.0, 1.0) - f).component_mul(&self.color) / glm::pi::<f64>();
//            specular + diffuse
//        }
//    } else {
//        // Ratio of refractive indices, n_i / n_o
//        let eta_t = if wo_outside {
//            self.index
//        } else {
//            1.0 / self.index
//        };
//        let h = (wi * eta_t + wo).normalize(); // halfway vector
//        let wi_dot_h = wi.dot(&h);
//        let wo_dot_h = wo.dot(&h);
//        let n_dot_h = normal.dot(&h);
//        let nh2 = n_dot_h.powi(2);
//
//        // d: microfacet distribution function
//        // D = exp(((normal . h)^2 - 1) / (m^2 (normal . h)^2)) / (pi m^2 (normal . h)^4)
//        let m2 = self.roughness * self.roughness;
//        let d = ((nh2 - 1.0) / (m2 * nh2)).exp() / (m2 * glm::pi::<f64>() * nh2 * nh2);
//
//        // f: fresnel, schlick's approximation
//        // F = F0 + (1 - F0)(1 - wi . h)^5
//        let f0 = ((self.index - 1.0) / (self.index + 1.0)).powi(2);
//        let f0 = glm::lerp(&glm::vec3(f0, f0, f0), &self.color, self.metallic);
//        let f = f0 + (glm::vec3(1.0, 1.0, 1.0) - f0) * (1.0 - wi_dot_h.abs()).powi(5);
//
//        // g: geometry function, microfacet shadowing
//        // G = min(1, 2(normal . h)(normal . wo)/(wo . h), 2(normal . h)(normal . wi)/(wo . h))
//        let g = f64::min((n_dot_wi * n_dot_h).abs(), (n_dot_wo * n_dot_h).abs());
//        let g = (2.0 * g) / wo_dot_h.abs();
//        let g = g.min(1.0);
//
//        // BTDF: putting it all together
//        // Cook-Torrance = |h . wi|/|normal . wi| * |h . wo|/|normal . wo|
//        //                  * n_o^2 (1 - F)DG / (n_i (h . wi) + n_o (h . wo))^2
//        let btdf = (wi_dot_h * wo_dot_h / (n_dot_wi * n_dot_wo)).abs()
//            * (d * (glm::vec3(1.0, 1.0, 1.0) - f) * g / (eta_t * wi_dot_h + wo_dot_h).powi(2));
//        btdf.component_mul(&self.color)
//    }
//}
