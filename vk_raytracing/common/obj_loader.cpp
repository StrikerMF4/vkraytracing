
#include <obj_loader.h>

using namespace objl;

float math::MagnitudeV3(const glm::vec3 in)
{
	return (sqrtf(powf(in.x, 2) + powf(in.y, 2) + powf(in.z, 2)));
}

float math::AngleBetweenV3(const glm::vec3 a, const glm::vec3 b)
{
	float angle = glm::dot(a, b);
	angle /= (MagnitudeV3(a) * MagnitudeV3(b));
	return angle = acosf(angle);
}

glm::vec3 math::ProjV3(const glm::vec3 a, const glm::vec3 b)
{
	glm::vec3 bn = b / math::MagnitudeV3(b);
	return bn * glm::dot(a, bn);
}


// A test to see if P1 is on the same side as P2 of a line segment ab
bool algorithm::SameSide(glm::vec3 p1, glm::vec3 p2, glm::vec3 a, glm::vec3 b)
{
	glm::vec3 cp1 = glm::cross(b - a, p1 - a);
	glm::vec3 cp2 = glm::cross(b - a, p2 - a);

	if (glm::dot(cp1, cp2) >= 0)
		return true;
	else
		return false;
}

// Generate a cross produect normal for a triangle
glm::vec3 algorithm::GenTriNormal(glm::vec3 t1, glm::vec3 t2, glm::vec3 t3)
{
	glm::vec3 u = t2 - t1;
	glm::vec3 v = t3 - t1;

	glm::vec3 normal = glm::cross(u, v);

	return normal;
}

// Check to see if a glm::vec3 Point is within a 3 glm::vec3 Triangle
bool algorithm::inTriangle(glm::vec3 point, glm::vec3 tri1, glm::vec3 tri2, glm::vec3 tri3)
{
	// Test to see if it is within an infinite prism that the triangle outlines.
	bool within_tri_prisim = SameSide(point, tri1, tri2, tri3) && SameSide(point, tri2, tri1, tri3)
		&& SameSide(point, tri3, tri1, tri2);

	// If it isn't it will never be on the triangle
	if (!within_tri_prisim)
		return false;

	// Calulate Triangle's Normal
	glm::vec3 n = GenTriNormal(tri1, tri2, tri3);

	// Project the point onto this normal
	glm::vec3 proj = math::ProjV3(point, n);

	// If the distance from the triangle to the point is 0
	//	it lies on the triangle
	if (math::MagnitudeV3(proj) == 0)
		return true;
	else
		return false;
}

// Split a String into a string array at a given token
inline void algorithm::split(const std::string& in,
	std::vector<std::string>& out,
	std::string token)
{
	out.clear();

	std::string temp;

	for (int i = 0; i < int(in.size()); i++)
	{
		std::string test = in.substr(i, token.size());

		if (test == token)
		{
			if (!temp.empty())
			{
				out.push_back(temp);
				temp.clear();
				i += (int)token.size() - 1;
			}
			else if (token != " ")
			{
				out.push_back("");
			}
		}
		else if (i + token.size() >= in.size())
		{
			temp += in.substr(i, token.size());
			out.push_back(temp);
			break;
		}
		else
		{
			temp += in[i];
		}
	}
}

// Get tail of string after first token and possibly following spaces
inline std::string algorithm::tail(const std::string& in)
{
	size_t token_start = in.find_first_not_of(" \t");
	size_t space_start = in.find_first_of(" \t", token_start);
	size_t tail_start = in.find_first_not_of(" \t", space_start);
	size_t tail_end = in.find_last_not_of(" \t");
	if (tail_start != std::string::npos && tail_end != std::string::npos)
	{
		return in.substr(tail_start, tail_end - tail_start + 1);
	}
	else if (tail_start != std::string::npos)
	{
		return in.substr(tail_start);
	}
	return "";
}

// Get first token of string
inline std::string algorithm::firstToken(const std::string& in)
{
	if (!in.empty())
	{
		size_t token_start = in.find_first_not_of(" \t");
		size_t token_end = in.find_first_of(" \t", token_start);
		if (token_start != std::string::npos && token_end != std::string::npos)
		{
			return in.substr(token_start, token_end - token_start);
		}
		else if (token_start != std::string::npos)
		{
			return in.substr(token_start);
		}
	}
	return "";
}

// Get element at given index position
template <class T>
inline const T& algorithm::getElement(const std::vector<T>& elements, std::string& index)
{
	int idx = std::stoi(index);
	if (idx < 0)
		idx = int(elements.size()) + idx;
	else
		idx--;
	return elements[idx];
}




bool Loader::LoadFile(std::string Path, glm::vec3 scale, std::map<std::string, objl::Material>* materials, objl::Material* default_material, bool replace_materials)
{
	// If the file is not an .obj file return false
	if (Path.substr(Path.size() - 4, 4) != ".obj")
		return false;


	std::ifstream file(Path);

	if (!file.is_open())
		return false;

	LoadedMeshes.clear();
	LoadedVertices.clear();
	LoadedIndices.clear();
	LoadedMaterialIndices.clear();
	LoadedLightIDs.clear();
	LoadedLights.clear();

	std::vector<glm::vec3> Positions;
	std::vector<glm::vec2> TCoords;
	std::vector<glm::vec3> Normals;

	std::vector<Vertex> Vertices;
	std::vector<unsigned int> Indices;

	bool listening = false;
	std::string meshname;

	Mesh tempMesh;
	Material* tempMaterial = default_material;

#ifdef OBJL_CONSOLE_OUTPUT
	const unsigned int outputEveryNth = 1000;
	unsigned int outputIndicator = outputEveryNth;
#endif

	std::string curline;
	while (std::getline(file, curline))
	{
#ifdef OBJL_CONSOLE_OUTPUT
		if ((outputIndicator = ((outputIndicator + 1) % outputEveryNth)) == 1)
		{
			if (!meshname.empty())
			{
				std::cout
					<< "\r- " << meshname
					<< "\t| vertices > " << Positions.size()
					<< "\t| texcoords > " << TCoords.size()
					<< "\t| normals > " << Normals.size()
					<< "\t| triangles > " << (Vertices.size() / 3);
			}
		}
#endif

		// Generate a Mesh Object or Prepare for an object to be created
		if (algorithm::firstToken(curline) == "o" || algorithm::firstToken(curline) == "g" || curline[0] == 'g')
		{
			if (!listening)
			{
				listening = true;

				if (algorithm::firstToken(curline) == "o" || algorithm::firstToken(curline) == "g")
				{
					meshname = algorithm::tail(curline);
				}
				else
				{
					meshname = "unnamed";
				}
			}
			else
			{
				// Generate the mesh to put into the array

				if (!Indices.empty() && !Vertices.empty())
				{
					// Create Mesh
					tempMesh = Mesh(Vertices, Indices);
					tempMesh.MeshName = meshname;
					tempMesh.MeshMaterial = tempMaterial; //El material anterior

					if (abs(tempMesh.MeshMaterial->emission.x) + abs(tempMesh.MeshMaterial->emission.y) + abs(tempMesh.MeshMaterial->emission.z) > 0) {
						Light light;

						light.emission = tempMesh.MeshMaterial->emission;
						light.first_index = (LoadedIndices.size() - Indices.size()) / 3;
						light.last_index = (LoadedIndices.size() - 1) / 3;

						float area = 0.0f;
						for (int i = 0; i < Indices.size(); i += 3) {
							glm::vec3 a = Vertices[Indices[i]].Position * scale;
							glm::vec3 b = Vertices[Indices[i + 1]].Position * scale;
							glm::vec3 c = Vertices[Indices[i + 2]].Position * scale;

							glm::vec3 AB = b - a;
							glm::vec3 AC = c - a;

							area += (glm::length(glm::cross(AB, AC))) / 2;
						}
						light.area = area;

						std::cout << "First index" << light.first_index << "/ last index " << light.last_index << std::endl;

						LoadedLights.push_back(light);
					}

					// Insert Mesh
					LoadedMeshes.push_back(tempMesh);

					tempMaterial = default_material;

					// Cleanup
					Vertices.clear();
					Indices.clear();
					meshname.clear();

					meshname = algorithm::tail(curline);
				}
				else
				{
					if (algorithm::firstToken(curline) == "o" || algorithm::firstToken(curline) == "g")
					{
						meshname = algorithm::tail(curline);
					}
					else
					{
						meshname = "unnamed";
					}
				}
			}
#ifdef OBJL_CONSOLE_OUTPUT
			std::cout << std::endl;
			outputIndicator = 0;
#endif
		}
		// Generate a Vertex Position
		if (algorithm::firstToken(curline) == "v")
		{
			std::vector<std::string> spos;
			algorithm::split(algorithm::tail(curline), spos, " ");
			glm::vec3 vpos(std::stof(spos[0]), std::stof(spos[1]), std::stof(spos[2]));

			Positions.push_back(vpos);
		}
		// Generate a Vertex Texture Coordinate
		if (algorithm::firstToken(curline) == "vt")
		{
			std::vector<std::string> stex;
			algorithm::split(algorithm::tail(curline), stex, " ");
			glm::vec2 vtex(std::stof(stex[0]), 1.0 - std::stof(stex[1]));

			TCoords.push_back(vtex);
		}
		// Generate a Vertex Normal;
		if (algorithm::firstToken(curline) == "vn")
		{
			std::vector<std::string> snor;
			algorithm::split(algorithm::tail(curline), snor, " ");
			glm::vec3 vnor(std::stof(snor[0]), std::stof(snor[1]), std::stof(snor[2]));

			Normals.push_back(vnor);
		}
		// Generate a Face (vertices & indices)
		if (algorithm::firstToken(curline) == "f")
		{
			// Generate the vertices
			std::vector<Vertex> vVerts;
			GenVerticesFromRawOBJ(vVerts, Positions, TCoords, Normals, curline);

			// Add Vertices
			for (int i = 0; i < int(vVerts.size()); i++)
			{
				Vertices.push_back(vVerts[i]);

				LoadedVertices.push_back(vVerts[i]);
			}

			std::vector<unsigned int> iIndices;

			VertexTriangluation(iIndices, vVerts);

			// Add Indices
			for (int i = 0; i < int(iIndices.size()); i++)
			{
				unsigned int indnum = (unsigned int)((Vertices.size()) - vVerts.size()) + iIndices[i];
				Indices.push_back(indnum);

				indnum = (unsigned int)((LoadedVertices.size()) - vVerts.size()) + iIndices[i];
				LoadedIndices.push_back(indnum);

			}

			for (int i = 0; i < iIndices.size() / 3; i++)
				LoadedMaterialIndices.push_back(tempMaterial->ID);
		}
		// Get Mesh Material Name
		if (algorithm::firstToken(curline) == "usemtl")
		{
			// Create new Mesh, if Material changes within a group
			if (!Indices.empty() && !Vertices.empty())
			{
				// Create Mesh
				tempMesh = Mesh(Vertices, Indices);
				tempMesh.MeshName = meshname;
				tempMesh.MeshMaterial = tempMaterial; //El material anterior, a partir de este momento va a ser otro para el siguiente mesh
				int i = 2;
				while (1) {
					tempMesh.MeshName = meshname + "_" + std::to_string(i++);

					for (auto& m : LoadedMeshes)
						if (m.MeshName == tempMesh.MeshName)
							continue;
					break;
				}

				if (abs(tempMesh.MeshMaterial->emission.x) + abs(tempMesh.MeshMaterial->emission.y) + abs(tempMesh.MeshMaterial->emission.z) > 0) {
					Light light;

					light.emission = tempMesh.MeshMaterial->emission;
					light.first_index = (LoadedIndices.size() - Indices.size()) / 3;
					light.last_index = (LoadedIndices.size() - 1) / 3;

					float area = 0.0f;
					for (int i = 0; i < Indices.size(); i += 3) {
						glm::vec3 a = Vertices[Indices[i]].Position * scale;
						glm::vec3 b = Vertices[Indices[i + 1]].Position * scale;
						glm::vec3 c = Vertices[Indices[i + 2]].Position * scale;

						glm::vec3 AB = b - a;
						glm::vec3 AC = c - a;

						area += (glm::length(glm::cross(AB, AC))) / 2;
					}
					light.area = area;

					LoadedLights.push_back(light);
				}

				// Insert Mesh
				LoadedMeshes.push_back(tempMesh);

				// Cleanup
				Vertices.clear();
				Indices.clear();
			}

			if (!replace_materials)
				tempMaterial = &(*materials)[algorithm::tail(curline)];

#ifdef OBJL_CONSOLE_OUTPUT
			outputIndicator = 0;
#endif
		}
	}

#ifdef OBJL_CONSOLE_OUTPUT
	std::cout << std::endl;
#endif

	// Deal with last mesh

	if (!Indices.empty() && !Vertices.empty())
	{
		// Create Mesh
		tempMesh = Mesh(Vertices, Indices);
		tempMesh.MeshName = meshname;
		tempMesh.MeshMaterial = tempMaterial;

		if (abs(tempMesh.MeshMaterial->emission.x) + abs(tempMesh.MeshMaterial->emission.y) + abs(tempMesh.MeshMaterial->emission.z) > 0) {
			Light light;

			light.emission = tempMesh.MeshMaterial->emission;
			light.first_index = (LoadedIndices.size() - Indices.size()) / 3;
			light.last_index = (LoadedIndices.size() - 1) / 3;
			
			float area = 0.0f;
			for (int i = 0; i < Indices.size(); i += 3) {
				glm::vec3 a = Vertices[Indices[i]].Position * scale;
				glm::vec3 b = Vertices[Indices[i + 1]].Position * scale;
				glm::vec3 c = Vertices[Indices[i + 2]].Position * scale;

				glm::vec3 AB = b - a;
				glm::vec3 AC = c - a;

				area += (glm::length(glm::cross(AB, AC))) / 2;
			}
			light.area = area;

			LoadedLights.push_back(light);
		}

		// Insert Mesh
		LoadedMeshes.push_back(tempMesh);
	}

	file.close();

	if (LoadedMeshes.empty() && LoadedVertices.empty() && LoadedIndices.empty())
	{
		return false;
	}
	else
	{
		return true;
	}
}

void Loader::GenVerticesFromRawOBJ(std::vector<Vertex>& oVerts,
	const std::vector<glm::vec3>& iPositions,
	const std::vector<glm::vec2>& iTCoords,
	const std::vector<glm::vec3>& iNormals,
	std::string icurline)
{
	std::vector<std::string> sface, svert;
	Vertex vVert{};
	algorithm::split(algorithm::tail(icurline), sface, " ");

	bool noNormal = false;
	bool noTexCoord = false;

	// For every given vertex do this
	for (int i = 0; i < int(sface.size()); i++)
	{
		// See What type the vertex is.
		int vtype = 0;

		algorithm::split(sface[i], svert, "/");

		// Check for just position - v1
		if (svert.size() == 1)
		{
			// Only position
			vtype = 1;
		}

		// Check for position & texture - v1/vt1
		if (svert.size() == 2)
		{
			// Position & Texture
			vtype = 2;
		}

		// Check for Position, Texture and Normal - v1/vt1/vn1
		// or if Position and Normal - v1//vn1
		if (svert.size() == 3)
		{
			if (svert[1] != "")
			{
				// Position, Texture, and Normal
				vtype = 4;
			}
			else
			{
				// Position & Normal
				vtype = 3;
			}
		}

		// Calculate and store the vertex
		switch (vtype)
		{
		case 1: // P
			vVert.Position = algorithm::getElement(iPositions, svert[0]);
			vVert.TextureCoordinate = glm::vec2(0, 0);
			noNormal = true;
			noTexCoord = true;
			oVerts.push_back(vVert);
			break;
		case 2: // P/T
			vVert.Position = algorithm::getElement(iPositions, svert[0]);
			vVert.TextureCoordinate = algorithm::getElement(iTCoords, svert[1]);
			noNormal = true;
			noTexCoord = false;
			oVerts.push_back(vVert);
			break;
		case 3: // P//N
			vVert.Position = algorithm::getElement(iPositions, svert[0]);
			vVert.TextureCoordinate = glm::vec2(0, 0);
			vVert.Normal = algorithm::getElement(iNormals, svert[2]);
			noTexCoord = true;
			oVerts.push_back(vVert);
			break;
		case 4: // P/T/N
			vVert.Position = algorithm::getElement(iPositions, svert[0]);
			vVert.TextureCoordinate = algorithm::getElement(iTCoords, svert[1]);
			vVert.Normal = algorithm::getElement(iNormals, svert[2]);
			noTexCoord = false;
			oVerts.push_back(vVert);
			break;
		default:
			break;
		}
	}

	// take care of missing normals
	// these may not be truly acurate but it is the 
	// best they get for not compiling a mesh with normals	
	if (noNormal)
	{
		glm::vec3 A = oVerts[0].Position - oVerts[1].Position;
		glm::vec3 B = oVerts[2].Position - oVerts[1].Position;

		glm::vec3 normal = glm::cross(A, B);

		for (int i = 0; i < int(oVerts.size()); i++)
		{
			oVerts[i].Normal = normal;
		}
	}

	if (!noTexCoord && oVerts.size() >= 3)
	{
		// Tomamos los primeros 3 vértices para definir el plano del triángulo
		glm::vec3& v0 = oVerts[0].Position;
		glm::vec3& v1 = oVerts[1].Position;
		glm::vec3& v2 = oVerts[2].Position;

		glm::vec2& uv0 = oVerts[0].TextureCoordinate;
		glm::vec2& uv1 = oVerts[1].TextureCoordinate;
		glm::vec2& uv2 = oVerts[2].TextureCoordinate;

		// Edges del triángulo en el espacio del objeto
		glm::vec3 deltaPos1 = v1 - v0;
		glm::vec3 deltaPos2 = v2 - v0;

		// Edges en el espacio de la textura (UV)
		glm::vec2 deltaUV1 = uv1 - uv0;
		glm::vec2 deltaUV2 = uv2 - uv0;

		// Cálculo matemático de la tangente y bitangente
		float r = 1.0f / (deltaUV1.x * deltaUV2.y - deltaUV1.y * deltaUV2.x);
		if (isinf(r) || isnan(r)) r = 0.0f; // Evitar división por cero si las UVs están degeneradas

		glm::vec3 tangent = (deltaPos1 * deltaUV2.y - deltaPos2 * deltaUV1.y) * r;
		// glm::vec3 bitangent = (deltaPos2 * deltaUV1.x - deltaPos1 * deltaUV2.x) * r; // Opcional

		// Asignamos la misma tangente a todos los vértices de esta cara.
		// Una mejora sería promediar las tangentes de caras adyacentes, pero esto es mucho más complejo.
		for (int i = 0; i < int(oVerts.size()); i++)
		{
			// Ortogonalizamos la tangente con la normal del vértice y la normalizamos
			oVerts[i].Tangent = glm::normalize(tangent - oVerts[i].Normal * glm::dot(oVerts[i].Normal, tangent));
		}
	}
}

// Triangulate a list of vertices into a face by printing
//	inducies corresponding with triangles within it
void Loader::VertexTriangluation(std::vector<unsigned int>& oIndices,
	const std::vector<Vertex>& iVerts)
{
	// If there are 2 or less verts,
	// no triangle can be created,
	// so exit
	if (iVerts.size() < 3)
	{
		return;
	}
	// If it is a triangle no need to calculate it
	if (iVerts.size() == 3)
	{
		oIndices.push_back(0);
		oIndices.push_back(1);
		oIndices.push_back(2);
		return;
	}

	// Create a list of vertices
	std::vector<Vertex> tVerts = iVerts;

	while (true)
	{
		// For every vertex
		for (int i = 0; i < int(tVerts.size()); i++)
		{
			// pPrev = the previous vertex in the list
			Vertex pPrev;
			if (i == 0)
			{
				pPrev = tVerts[tVerts.size() - 1];
			}
			else
			{
				pPrev = tVerts[i - 1];
			}

			// pCur = the current vertex;
			Vertex pCur = tVerts[i];

			// pNext = the next vertex in the list
			Vertex pNext;
			if (i == tVerts.size() - 1)
			{
				pNext = tVerts[0];
			}
			else
			{
				pNext = tVerts[i + 1];
			}

			// Check to see if there are only 3 verts left
			// if so this is the last triangle
			if (tVerts.size() == 3)
			{
				// Create a triangle from pCur, pPrev, pNext
				for (int j = 0; j < int(tVerts.size()); j++)
				{
					if (iVerts[j].Position == pCur.Position)
						oIndices.push_back(j);
					if (iVerts[j].Position == pPrev.Position)
						oIndices.push_back(j);
					if (iVerts[j].Position == pNext.Position)
						oIndices.push_back(j);
				}

				tVerts.clear();
				break;
			}
			if (tVerts.size() == 4)
			{
				// Create a triangle from pCur, pPrev, pNext
				for (int j = 0; j < int(iVerts.size()); j++)
				{
					if (iVerts[j].Position == pCur.Position)
						oIndices.push_back(j);
					if (iVerts[j].Position == pPrev.Position)
						oIndices.push_back(j);
					if (iVerts[j].Position == pNext.Position)
						oIndices.push_back(j);
				}

				glm::vec3 tempVec;
				for (int j = 0; j < int(tVerts.size()); j++)
				{
					if (tVerts[j].Position != pCur.Position
						&& tVerts[j].Position != pPrev.Position
						&& tVerts[j].Position != pNext.Position)
					{
						tempVec = tVerts[j].Position;
						break;
					}
				}

				// Create a triangle from pCur, pPrev, pNext
				for (int j = 0; j < int(iVerts.size()); j++)
				{
					if (iVerts[j].Position == pPrev.Position)
						oIndices.push_back(j);
					if (iVerts[j].Position == pNext.Position)
						oIndices.push_back(j);
					if (iVerts[j].Position == tempVec)
						oIndices.push_back(j);
				}

				tVerts.clear();
				break;
			}

			// If Vertex is not an interior vertex
			float angle = math::AngleBetweenV3(pPrev.Position - pCur.Position, pNext.Position - pCur.Position) * (180 / 3.14159265359f);
			if (angle <= 0 && angle >= 180)
				continue;

			// If any vertices are within this triangle
			bool inTri = false;
			for (int j = 0; j < int(iVerts.size()); j++)
			{
				if (algorithm::inTriangle(iVerts[j].Position, pPrev.Position, pCur.Position, pNext.Position)
					&& iVerts[j].Position != pPrev.Position
					&& iVerts[j].Position != pCur.Position
					&& iVerts[j].Position != pNext.Position)
				{
					inTri = true;
					break;
				}
			}
			if (inTri)
				continue;

			// Create a triangle from pCur, pPrev, pNext
			for (int j = 0; j < int(iVerts.size()); j++)
			{
				if (iVerts[j].Position == pCur.Position)
					oIndices.push_back(j);
				if (iVerts[j].Position == pPrev.Position)
					oIndices.push_back(j);
				if (iVerts[j].Position == pNext.Position)
					oIndices.push_back(j);
			}

			// Delete pCur from the list
			for (int j = 0; j < int(tVerts.size()); j++)
			{
				if (tVerts[j].Position == pCur.Position)
				{
					tVerts.erase(tVerts.begin() + j);
					break;
				}
			}

			// reset i to the start
			// -1 since loop will add 1 to it
			i = -1;
		}

		// if no triangles were created
		if (oIndices.size() == 0)
			break;

		// if no more vertices
		if (tVerts.size() == 0)
			break;
	}
}
