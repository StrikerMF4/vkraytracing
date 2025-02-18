
#ifndef COMMON_HOST_DEVICE
#define COMMON_HOST_DEVICE

#ifdef __cplusplus
#include <glm/glm.hpp>
// GLSL Type
using vec2 = glm::vec2;
using vec3 = glm::vec3;
using vec4 = glm::vec4;
using mat4 = glm::mat4;
using uint = unsigned int;
#endif

// clang-format off
#ifdef __cplusplus // Descriptor binding helper for C++ and GLSL
#define START_BINDING(a) enum a {
#define END_BINDING() }
#else
#define START_BINDING(a)  const uint
#define END_BINDING() 
#endif

START_BINDING(SceneBindings)
eGlobals = 0,  // Global uniform containing camera matrices
eObjDescs = 1,  // Access to the object descriptions
eTextures = 2,  // Access to textures
eLights = 3,
eImplicit = 4,
eImplicitSpheres = 5
END_BINDING();

START_BINDING(RtxBindings)
eTlas = 0,  // Top-level acceleration structure
eOutImage = 1   // Ray tracer output image
END_BINDING();
// clang-format on

#define KIND_SPHERE 0
#define KIND_CUBE 1

// Information of a obj model when referenced in a shader
struct ObjDesc
{
	int      txtOffset;             // Texture index offset in the array of textures
	uint64_t vertexAddress;         // Address of the Vertex buffer
	uint64_t indexAddress;          // Address of the index buffer
	uint64_t materialAddress;       // Address of the material buffer
	uint64_t materialIndexAddress;  // Address of the triangle material index buffer
};

// Uniform buffer set at each frame
struct GlobalUniforms
{
	mat4 viewProj;     // Camera view * projection
	mat4 viewInverse;  // Camera inverse view matrix
	mat4 projInverse;  // Camera inverse projection matrix
};

// Push constant structure for the raster
struct PushConstantRaster
{
	mat4  modelMatrix;  // matrix of the instance
	vec3  lightPosition;
	uint  objIndex;
	float lightIntensity;
	int   lightType;
};


// Push constant structure for the ray tracer
struct PushConstantRayTracer
{
	vec4  clearColor;

	int   frame;
	float camAperture;
	float focusDist;
	float shininess;
	float fuzziness;
	bool ambientLigth;

	int light_count;
};

struct Vertex  // See ObjLoader, copy of VertexObj, could be compressed for device
{
	vec3 pos;
	vec3 nrm;
	vec2 texCoord;
};

struct ImplicitObj {
	uint kind; //type of implicit geometry
	uint kind_id; //index in the corresponding array
};

struct Sphere {
	vec3 center;
	float radius;
	int inverted_normal;
};

struct AABB {
	vec3 minimum;
	vec3 maximum;
};


struct WaveFrontMaterial  // See ObjLoader, copy of MaterialObj, could be compressed for device
{
	uint ID;

	vec3 baseColor;

	vec3 emission;

	float metallic;
	float roughness;
	float subsurface;
	float specularTint;
	float anisotropic;

	float sheen;
	float sheenTint;
	float clearcoat;
	float clearcoatGloss;

	float specTrans;
	float ior;

	int albedoTextureID;
	int metallicRoughnessTextureID;
	int normalTextureID;
	int emissionTextureID;

	float opacity;
	float alphaMode;
	float alphaCutoff;
};

struct Light {
	int object_id;
	mat4 object_to_world;
	mat4 world_to_object;
	vec3 emission;
	float area;

	uint first_index;
	uint last_index;
};


#endif
