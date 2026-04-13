#ifndef MASKING_GLSL
#define MASKING_GLSL

#include "raycommon.glsl"

layout(buffer_reference, scalar) buffer Vertices { Vertex v[]; };
layout(buffer_reference, scalar) buffer Indices { ivec3 i[]; };
layout(buffer_reference, scalar) buffer Materials { Material m[]; };
layout(buffer_reference, scalar) buffer MatIndices { int i[]; };

layout(set = 1, binding = eObjDescs, scalar) buffer ObjDesc_ { ObjDesc i[]; } objDesc;
layout(set = 1, binding = eTextures) uniform sampler2D textureSamplers[];

bool isMaskedTriangleIntersection(vec2 attribs)
{
    ObjDesc objResource = objDesc.i[gl_InstanceCustomIndexEXT];
    Materials materials = Materials(objResource.materialAddress);
    MatIndices matIndices = MatIndices(objResource.materialIndexAddress);

    int matIdx = matIndices.i[gl_PrimitiveID];
    Material material = materials.m[matIdx];
    if (material.maskTextureID < 0) {
        return false;
    }

    Indices indices = Indices(objResource.indexAddress);
    Vertices vertices = Vertices(objResource.vertexAddress);

    ivec3 ind = indices.i[gl_PrimitiveID];
    Vertex v0 = vertices.v[ind.x];
    Vertex v1 = vertices.v[ind.y];
    Vertex v2 = vertices.v[ind.z];

    vec3 barycentrics = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);
    vec2 texCoord = v0.texCoord * barycentrics.x + v1.texCoord * barycentrics.y + v2.texCoord * barycentrics.z;

    uint txtId = material.maskTextureID + objResource.txtOffset;
    float mask = texture(textureSamplers[nonuniformEXT(txtId)], texCoord * material.tiling).x;
    return mask < 0.5;
}

#endif
