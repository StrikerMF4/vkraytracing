#pragma once

// Iostream - STD I/O Library
#include <iostream>

// Vector - STD Vector/Array Library
#include <vector>
#include <map>


// String - STD String Library
#include <string>

// fStream - STD File I/O Library
#include <fstream>

// Math.h - STD math Library
#include <math.h>

#include <glm/glm.hpp>

// Print progress to console while loading (large models)
#define OBJL_CONSOLE_OUTPUT

// Namespace: OBJL
//
// Description: The namespace that holds eveyrthing that
//	is needed and used for the OBJ Model Loader
namespace objl
{
	// Structure: Vertex
	//
	// Description: Model Vertex object that holds
	//	a Position, Normal, and Texture Coordinate
	struct Vertex
	{
		// Position Vector
		glm::vec3 Position;

		// Normal Vector
		glm::vec3 Normal;

		// Texture Coordinate Vector
		glm::vec2 TextureCoordinate;
	};

	struct Material
	{
		Material()
		{
			ID = 0;
			baseColor = glm::vec3(1.0);
			emission = glm::vec3(0.0);
			anisotropic = 0.0f;
			metallic = 0.0f;
			roughness = 1.0f;
			subsurface = 0.0f;
			specularTint = 0.0f;
			sheen = 0.0f;
			sheenTint = 0.0f;
			clearcoat = 0.0f;
			clearcoatGloss = 0.0f;
			specTrans = 0.0f;
			ior = 1.5f;
			albedoTextureID = -1;
			metallicRoughnessTextureID = -1;
			normalTextureID = -1;
			emissionTextureID = -1;
			opacity = 1.0f;
			alphaMode = 0.0f;
			alphaCutoff = 0.0f;
		}

		unsigned int ID;

		glm::vec3 baseColor;

		glm::vec3 emission;

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
		int metallicRoughnessTextureID;
		int normalTextureID;
		int emissionTextureID;

		float opacity;
		float alphaMode;
		float alphaCutoff;
	};

	// Structure: Mesh
	//
	// Description: A Simple Mesh Object that holds
	//	a name, a vertex list, and an index list
	struct Mesh
	{
		// Default Constructor
		Mesh()
		{
			MeshMaterial = nullptr;
		}
		// Variable Set Constructor
		Mesh(std::vector<Vertex>& _Vertices, std::vector<unsigned int>& _Indices)
		{
			Vertices = _Vertices;
			Indices = _Indices;
			MeshMaterial = nullptr;
		}
		// Mesh Name
		std::string MeshName;
		// Vertex List
		std::vector<Vertex> Vertices;
		// Index List
		std::vector<unsigned int> Indices;

		// Material
		Material* MeshMaterial;
	};

	struct Light {
		Light()
		{
			object_id = -1;

			emission = glm::vec3(0.0);
			area = 1.0;
			first_index = 0;
			last_index = 0;
		}

		int object_id;
		glm::vec3 emission;
		float area;

		unsigned int first_index;
		unsigned int last_index;
	};

	// Namespace: Math
	//
	// Description: The namespace that holds all of the math
	//	functions need for OBJL
	namespace math
	{
		// glm::vec3 Magnitude Calculation
		float MagnitudeV3(const glm::vec3 in);

		// Angle between 2 glm::vec3 Objects
		float AngleBetweenV3(const glm::vec3 a, const glm::vec3 b);

		// Projection Calculation of a onto b
		glm::vec3 ProjV3(const glm::vec3 a, const glm::vec3 b);
	}

	// Namespace: Algorithm
	//
	// Description: The namespace that holds all of the
	// Algorithms needed for OBJL
	namespace algorithm
	{
		// A test to see if P1 is on the same side as P2 of a line segment ab
		bool SameSide(glm::vec3 p1, glm::vec3 p2, glm::vec3 a, glm::vec3 b);

		// Generate a cross produect normal for a triangle
		glm::vec3 GenTriNormal(glm::vec3 t1, glm::vec3 t2, glm::vec3 t3);

		// Check to see if a glm::vec3 Point is within a 3 glm::vec3 Triangle
		bool inTriangle(glm::vec3 point, glm::vec3 tri1, glm::vec3 tri2, glm::vec3 tri3);

		// Split a String into a string array at a given token
		inline void split(const std::string& in,
			std::vector<std::string>& out,
			std::string token);

		// Get tail of string after first token and possibly following spaces
		inline std::string tail(const std::string& in);

		// Get first token of string
		inline std::string firstToken(const std::string& in);

		// Get element at given index position
		template <class T>
		inline const T& getElement(const std::vector<T>& elements, std::string& index);
	}

	// Class: Loader
	//
	// Description: The OBJ Model Loader
	class Loader
	{
	public:
		// Default Constructor
		Loader()
		{

		}
		~Loader()
		{
			LoadedMeshes.clear();
		}

		// Load a file into the loader
		//
		// If file is loaded return true
		//
		// If the file is unable to be found
		// or unable to be loaded return false
		bool LoadFile(std::string Path, glm::vec3 scale, std::map<std::string, objl::Material>* materials, objl::Material* default_material, bool replace_materials = false);

		// Loaded Mesh Objects
		std::vector<Mesh> LoadedMeshes;
		// Loaded Vertex Objects
		std::vector<Vertex> LoadedVertices;
		// Loaded Index Positions
		std::vector<unsigned int> LoadedIndices;
		// Loaded Material indexes
		std::vector<unsigned int> LoadedMaterialIndices;
		// Loaded Emissive Objects
		std::vector<Light> LoadedLights;
		// Loaded Light indexes
		std::vector<unsigned int> LoadedLightIDs;

	private:
		// Generate vertices from a list of positions, 
		//	tcoords, normals and a face line
		void GenVerticesFromRawOBJ(std::vector<Vertex>& oVerts,
			const std::vector<glm::vec3>& iPositions,
			const std::vector<glm::vec2>& iTCoords,
			const std::vector<glm::vec3>& iNormals,
			std::string icurline);

		// Triangulate a list of vertices into a face by printing
		//	inducies corresponding with triangles within it
		void VertexTriangluation(std::vector<unsigned int>& oIndices,
			const std::vector<Vertex>& iVerts);
	};
}