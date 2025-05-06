
#version 460
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_ray_tracing : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_GOOGLE_include_directive : enable

#extension GL_EXT_shader_explicit_arithmetic_types_int64 : require
#extension GL_EXT_buffer_reference2 : require

#include "material.glsl"

hitAttributeEXT vec2 attribs;

// clang-format off
layout(location = 0) rayPayloadInEXT rayPayload payload;

layout(buffer_reference, scalar) buffer Vertices {Vertex v[]; }; // Positions of an object
layout(buffer_reference, scalar) buffer Indices {ivec3 i[]; }; // Triangle indices
layout(buffer_reference, scalar) buffer Materials {Material m[]; }; // Array of all materials on an object
layout(buffer_reference, scalar) buffer MatIndices {int i[]; }; // Material ID for each triangle
layout(set = 0, binding = eTlas) uniform accelerationStructureEXT topLevelAS;
layout(set = 1, binding = eObjDescs, scalar) buffer ObjDesc_ { ObjDesc i[]; } objDesc;
layout(set = 1, binding = eTextures) uniform sampler2D textureSamplers[];
layout(set = 1, binding = eImplicit, scalar) buffer implicitObjs_ { ImplicitObj i[]; } implicitObjs;
layout(set = 1, binding = eImplicitSpheres, scalar) buffer allSpheres_ { Sphere i[]; } allSpheres;

layout(push_constant) uniform _PushConstantRayTracer { PushConstantRayTracer settings; };
// clang-format on

void main() {
    //Object data
    ObjDesc    objResource = objDesc.i[gl_InstanceCustomIndexEXT];
    MatIndices matIndices  = MatIndices(objResource.materialIndexAddress);
    Materials  materials   = Materials(objResource.materialAddress);
    
    vec3 hit_position = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;

    ImplicitObj object = implicitObjs.i[gl_PrimitiveID];

    // Computing the normal and uv at hit position
    vec2 texCoord;
    if(gl_HitKindEXT == KIND_SPHERE) 
    {
        Sphere instance = allSpheres.i[object.kind_id];

        payload.surface_normal = normalize(hit_position - instance.center);

        texCoord = vec2(
            atan(payload.surface_normal.x, payload.surface_normal.z) / (2 * PI) + 0.5,
            payload.surface_normal.y * 0.5 + 0.5
        );
    }

    // Material of the object
    int matIdx = matIndices.i[gl_PrimitiveID];
    payload.material = materials.m[matIdx];

    // Texture
    vec3 texture_color = vec3(1);
    if(payload.material.albedoTextureID >= 0) {
        uint txtId    = payload.material.albedoTextureID + objDesc.i[gl_InstanceCustomIndexEXT].txtOffset;
        texture_color = texture(textureSamplers[nonuniformEXT(txtId)], texCoord).xyz;
    }

    payload.material.baseColor = payload.material.baseColor * texture_color;
    payload.origin = hit_position;

    DisneyBSDFSample(payload);

    payload.origin = hit_position + payload.direction * EPSILON2;
}

