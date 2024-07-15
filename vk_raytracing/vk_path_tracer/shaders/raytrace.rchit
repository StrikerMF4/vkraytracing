
#version 460
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
        // TO-DO: Cambiar esto por alguna aproximaci�n al L de Veach
        payload.bsdf_sample = 3 * material.emittance * texture_color.rgb;
        payload.Le = 3 * material.emittance * texture_color.rgb;
        payload.status = RAY_HIT_LIGHT;
    } else {
        
        //Primero, determinar la nueva direcci�n basado en el material
        //Luego, se calcula el BSDF seg�n esta nueva direcci�n

        //Cuando la nueva direcci�n est� en el sentido de la normal, se calcula el BRDF
        //Cuando la nueva direcci�n est� en el sentido opuesto a la normal, se calcula el BTDF

        //Habr�a que hacer una ruleta rusa para saber si rebota o se transmite? (en el caso de que pueda hacer las dos cosas)
        //el "rebota" pude ser por lo difuso o por el brillo glossy, pero se elige la direcci�n de la misma forma 
        //  (si en la direcci�n elegida el glossy no afecta, va a aportar poco al BRDF)

        payload.material = material;

        vec3 wi = vec3(0.0f);
        float rnd = rand(payload.random_seed);

        float trans_prob = 1 - material.transparent;
        float refl_prob = trans_prob + material.metallic;
        float diff_prob = refl_prob + max(max(material.color.x, material.color.y), material.color.z);

        if(diff_prob > 1){
            trans_prob = trans_prob / diff_prob;
            refl_prob = refl_prob / diff_prob;
            diff_prob = 1.0;
        }

        float alpha_ggx = material.roughness;// * material.roughness; //Estaba en nvcore
        vec3 micro_normal = normalize(ggx_micronormal(payload.surface_normal, alpha_ggx, payload.random_seed, payload.theta)); //vec3 ggx_micronormal(vec3 normal, float alpha, inout uint seed)
        payload.surface_micronormal = micro_normal;
        
        if(rnd < trans_prob){
            const float angle = dot(payload.direction, payload.surface_normal);
            const float microAngle = dot(payload.direction, micro_normal);
            const vec3 outwardNormal = angle > 0 ? -payload.surface_normal : payload.surface_normal;
            const vec3 outwardMicro = microAngle > 0 ? -micro_normal : micro_normal;
            const float niOverNt = microAngle > 0 ? material.IOR : 1 / material.IOR;
            const float cosine = microAngle > 0 ? material.IOR * microAngle : -microAngle;

            if(rand(payload.random_seed) > Schlick(cosine, material.IOR)){
                //wi = refract(payload.direction, outwardMicro, material.IOR);
                wi = micro_transmit(-payload.direction, outwardMicro, outwardNormal, niOverNt);
                payload.bsdf_sample = vec3(length(wi));
            }
            else{
               //wi = reflect(payload.direction, micro_normal);
               wi = micro_reflect(-payload.direction, micro_normal);
            }
            payload.bsdf_sample = material.color; //specular color?
            payload.bsdf_type = BSDF_TRANSMISSION;
        }
        else if(rnd < refl_prob){
            //wi = reflect(payload.direction, payload.surface_normal);
            wi = micro_reflect(-payload.direction, micro_normal);
            payload.bsdf_sample = material.color; //specular color?
            payload.bsdf_type = BSDF_REFLECTION;
        }
        else if(rnd < diff_prob){
            wi = normalize(micro_reflect(-payload.direction, micro_normal) + RandomInUnitSphere(payload.random_seed));
            //wi = normalize(payload.surface_normal + RandomInUnitSphere(payload.random_seed));
            payload.bsdf_sample = material.color;
            payload.bsdf_type = BSDF_DIFFUSE;
        }else{
            payload.status = RAY_ABSORBED;
        }

        //payload.bsdf_sample = micro_normal * 0.5 + 0.5;
        
        //vec3 normal, vec3 wo, vec3 wi, WaveFrontMaterial material
        //payload.bsdf_sample = bsdf(payload.surface_normal, -payload.direction, wi, material);// material.color;

        payload.direction = wi;
    }
}

