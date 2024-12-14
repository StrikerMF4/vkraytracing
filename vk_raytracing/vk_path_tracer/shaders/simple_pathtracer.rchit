
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

    

    payload.origin = hit_position;
    if(length(material.emission) > 0) {
        // TO-DO: Cambiar esto por alguna aproximaci�n al L de Veach
        payload.bsdf_sample = 3 * material.emission * texture_color.rgb;
        payload.Le = 3 * material.emission * texture_color.rgb;
        payload.status = RAY_HIT_LIGHT;
    } else {
     
        payload.material = material;

        float rnd = rand(payload.random_seed);
        float absorption = 0;

        float trans_prob = 1 - material.opacity;
        float refl_prob = trans_prob + material.metallic;
        float absor_prob = refl_prob + absorption;

        float alpha_ggx = material.roughness;// * material.roughness; //Estaba en nvcore
        vec3 micro_normal = normalize(ggx_micronormal(payload.surface_normal, alpha_ggx, payload.random_seed, payload.theta)); //vec3 ggx_micronormal(vec3 normal, float alpha, inout uint seed)
        payload.surface_micronormal = micro_normal;
        
        if(rnd < trans_prob) {
            payload.bsdf_sample = vec3(0);
            payload.direction = transmition(micro_normal, material);
            payload.bsdf_sample = material.baseColor * texture_color; //specular color?
        } 
        else if(rnd < refl_prob) {
            payload.direction = micro_reflect(-payload.direction, micro_normal);
            payload.bsdf_sample = vec3(1); //specular color?
            payload.bsdf_type = BSDF_REFLECTION;
        }
        else if(rnd < absor_prob) {
            payload.status = RAY_ABSORBED;
        }
        else {
            payload.direction = micro_reflect(-payload.direction, micro_normal);
            payload.bsdf_sample = material.baseColor * texture_color;
            payload.bsdf_type = BSDF_DIFFUSE;
        }

    }
}

