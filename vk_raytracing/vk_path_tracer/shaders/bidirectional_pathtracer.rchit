
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
layout(buffer_reference, scalar) buffer LightIndices {int i[]; }; // Light ID for each triangle
layout(set = 0, binding = eTlas) uniform accelerationStructureEXT topLevelAS;
layout(set = 1, binding = eObjDescs, scalar) buffer ObjDesc_ { ObjDesc i[]; } objDesc;
layout(set = 1, binding = eTextures) uniform sampler2D textureSamplers[];

layout(push_constant) uniform _PushConstantRayTracer { PushConstantRayTracer settings; };
// clang-format on

void main() {
    //Object data
    ObjDesc    objResource = objDesc.i[gl_InstanceCustomIndexEXT];
    MatIndices matIndices  = MatIndices(objResource.materialIndexAddress);
    Materials  materials   = Materials(objResource.materialAddress);
    LightIndices lightIndices = LightIndices(objResource.lightIndexAddress);
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
    const vec3 local_position = v0.position * barycentrics.x + v1.position * barycentrics.y + v2.position * barycentrics.z;
    const vec3 hit_position = vec3(gl_ObjectToWorldEXT * vec4(local_position, 1.0));  // Transforming the position to world space
    // Computing the normal at hit position
    const vec3 local_normal = v0.normal * barycentrics.x + v1.normal * barycentrics.y + v2.normal * barycentrics.z;
    mat3 objToWorld = mat3(gl_ObjectToWorldEXT);
    payload.surface_normal = normalize(transpose(inverse(objToWorld)) * local_normal);

    payload.light_id = lightIndices.i[gl_PrimitiveID];

    // Material of the object
    int matIdx = matIndices.i[gl_PrimitiveID];
    payload.material = materials.m[matIdx];

    vec2 texCoord = v0.texCoord * barycentrics.x + v1.texCoord * barycentrics.y + v2.texCoord * barycentrics.z;
    vec3 local_geom_tangent = v0.tangent.xyz * barycentrics.x + v1.tangent.xyz * barycentrics.y + v2.tangent.xyz * barycentrics.z;
    vec3 world_geom_tangent = objToWorld * local_geom_tangent;
    float tangent_sign = (v0.tangent.w * barycentrics.x + v1.tangent.w * barycentrics.y + v2.tangent.w * barycentrics.z) < 0.0 ? -1.0 : 1.0;

    vec2 anisotropic_texture_dir = vec2(0.0);
    bool has_anisotropic_texture_dir = false;
    if (payload.material.anisotropicTextureID >= 0) {
        uint txtId = payload.material.anisotropicTextureID + objResource.txtOffset;
        anisotropic_texture_dir = texture(textureSamplers[nonuniformEXT(txtId)], texCoord * payload.material.tiling).rg * 2.0 - 1.0;
        has_anisotropic_texture_dir = dot(anisotropic_texture_dir, anisotropic_texture_dir) > EPSILON2;
    }

    payload.tangent = ResolveAnisotropicTangent(
        payload.surface_normal,
        world_geom_tangent,
        tangent_sign,
        payload.material.anisotropicDirection,
        anisotropic_texture_dir,
        has_anisotropic_texture_dir
    );
    

    // Texture
    vec3 texture_color = vec3(1);
    if(payload.material.albedoTextureID >= 0) {
        uint txtId    = payload.material.albedoTextureID + objResource.txtOffset;
        texture_color = texture(textureSamplers[nonuniformEXT(txtId)], texCoord * payload.material.tiling).xyz;
    }
        
    if(payload.material.metallicTextureID >= 0) {
        uint txtId    = payload.material.metallicTextureID + objResource.txtOffset;
        payload.material.metallic = texture(textureSamplers[nonuniformEXT(txtId)], texCoord * payload.material.tiling).x;
    }

    if(payload.material.roughnessTextureID >= 0) {
        uint txtId    = payload.material.roughnessTextureID + objResource.txtOffset;
        payload.material.roughness = texture(textureSamplers[nonuniformEXT(txtId)], texCoord * payload.material.tiling).x;
    }

    if(payload.material.opacityTextureID >= 0) {
        uint txtId    = payload.material.opacityTextureID + objResource.txtOffset;
        payload.material.opacity = texture(textureSamplers[nonuniformEXT(txtId)], texCoord * payload.material.tiling).x;
    }

    payload.material.baseColor = payload.material.baseColor * texture_color;
    payload.origin = hit_position;

    DisneyBSDFSample(payload);

    payload.origin = hit_position + payload.direction * EPSILON2;
}