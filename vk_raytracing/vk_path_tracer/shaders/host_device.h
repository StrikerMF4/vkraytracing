
#ifndef COMMON_HOST_DEVICE
#define COMMON_HOST_DEVICE

#ifdef __cplusplus
#include <glm/glm.hpp>
// GLSL Type
using vec2 = glm::vec2;
using vec3 = glm::vec3;
using vec4 = glm::vec4;
using mat3 = glm::mat3;
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
eImplicitSpheres = 5,
eDirectionalLights = 6
END_BINDING();

START_BINDING(RtxBindings)
eTlas = 0,  // Top-level acceleration structure
eOutImage = 1,   // Ray tracer output image
eBidirectionalLightImage = 2   // Ray tracer bidirectional image for light tracing
END_BINDING();

START_BINDING(PostBindings)
eRenderedImage = 0,   // Ray tracer output image
eRenderedLightImage = 1   // Ray tracer bidirectional image for light tracing
END_BINDING();

// clang-format on

#define KIND_SPHERE 0
#define KIND_CUBE 1
#define KIND_GEOMETRY 2
const uint MAX_DEPTH = 11;
const float FLOAT_UINT_CONVERSION_CONSTANT = 1048576.0; //2^20

// Information of a obj model when referenced in a shader
struct ObjDesc
{
	int      txtOffset;             // Texture index offset in the array of textures
	uint64_t vertexAddress;         // Address of the Vertex buffer
	uint64_t indexAddress;          // Address of the index buffer
	uint64_t materialAddress;       // Address of the material buffer
	uint64_t materialIndexAddress;  // Address of the triangle material index buffer
	uint64_t lightIndexAddress;  // Address of the triangle material index buffer
};

// Uniform buffer set at each frame
struct CameraUniforms
{
	mat4 viewProj;     // Camera view * projection
	mat4 view;  // Camera view matrix
	mat4 proj;  // Camera proj matrix
	mat4 viewInverse;  // Camera inverse view matrix
	mat4 projInverse;  // Camera inverse projection matrix

	float camAperture;
	float focusDist;
	float fov;
};

// Push constant structure
struct PushConstantPost
{
	uint image_width;
	uint image_height;
	bool bidirectional_correction;
	int   frame;
	float exposition;
};

// Push constant structure for the ray tracer
struct PushConstantRayTracer
{
	uint light_count;
	uint directional_light_count;
	int   frame;

	float antialiasing_radius;

	int max_depth;
	int debug_technique_s;
	int debug_technique_t;
	
	int debug_multiply_mis;
	int debug_multiply_contribution;
};

struct Vertex  // See ObjLoader, copy of VertexObj, could be compressed for device
{
	vec3 position;
	vec3 normal;
	vec2 texCoord;
	vec4 tangent;
};

struct ImplicitObj {
	uint kind; //type of implicit geometry
	uint kind_id; //index in the corresponding array
};

struct Sphere {
	vec3 center;
	float radius;
	int inverted_normal;
	vec3 anisotropic_direction; // Anisotropic direction for the sphere
};

struct AABB {
	vec3 minimum;
	vec3 maximum;
};


struct Material  // See ObjLoader, copy of MaterialObj, could be compressed for device
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
	int anisotropicTextureID;
	int metallicTextureID;
	int roughnessTextureID;
	int opacityTextureID;
	int maskTextureID;
	int normalTextureID;
	int emissionTextureID;

	float opacity;
	float alphaMode;
	float alphaCutoff;

	float tiling;
};

struct Light {
	int object_id;
	mat4 object_to_world;
	mat3 world_to_object;
	vec3 emission;
	float area;
	float weight; 
	uint mesh_type;
	//If mesh_type is KIND_GEOMETRY, first_index is the index of the sphere in the implicit objects buffer
	uint first_index;
	uint last_index;
};

struct DirectionalLight {
	vec3 direction;
	float weight;
	vec3 radiance;
	float _pad0;
};


#endif
