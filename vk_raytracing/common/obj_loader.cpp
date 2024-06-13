/*
 * Copyright (c) 2021-2023, NVIDIA CORPORATION.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-FileCopyrightText: Copyright (c) 2014-2021 NVIDIA CORPORATION
 * SPDX-License-Identifier: Apache-2.0
 */

 // This file exist only to do the implementation of tiny obj loader
#define TINYOBJLOADER_IMPLEMENTATION
#include "obj_loader.h"
#include "nvh/nvprint.hpp"


void ObjLoader::loadModel(const std::string& filename)
{
	tinyobj::ObjReader reader;
	reader.ParseFromFile(filename);
	if (!reader.Valid())
	{
		LOGE("Cannot load %s: %s", filename.c_str(), reader.Error().c_str());
		assert(reader.Valid());
	}

	std::vector<int> lights_materials_indexes;

	// Collecting the material in the scene
	int i = 0;
	for (const auto& material : reader.GetMaterials())
	{
		MaterialObj m;

		m.color = glm::vec3(material.diffuse[0], material.diffuse[1], material.diffuse[2]);

		m.IOR = material.ior;
		m.roughness = material.roughness;
		m.metallic = material.metallic;
		m.emittance = glm::vec3(material.emission[0], material.emission[1], material.emission[2]);
		m.transparent = material.dissolve;

		if (!material.diffuse_texname.empty())
		{
			m_textures.push_back(material.diffuse_texname);
			m.textureID = static_cast<int>(m_textures.size()) - 1;
		}

		//Record the materials that emit light
		if (abs(m.emittance.x) + abs(m.emittance.y) + abs(m.emittance.z) > 0)
			lights_materials_indexes.push_back(i);

		m_materials.emplace_back(m);
		i++;
	}

	// If there were none, add a default
	if (m_materials.empty())
		m_materials.emplace_back(MaterialObj());

	const tinyobj::attrib_t& attrib = reader.GetAttrib();

	for (const auto& shape : reader.GetShapes())
	{
		m_vertices.reserve(shape.mesh.indices.size() + m_vertices.size());
		m_indices.reserve(shape.mesh.indices.size() + m_indices.size());
		m_matIndx.insert(m_matIndx.end(), shape.mesh.material_ids.begin(), shape.mesh.material_ids.end());

		int length = shape.mesh.material_ids.size();

		int material_index = shape.mesh.material_ids[0];
		bool is_light = count(lights_materials_indexes.begin(), lights_materials_indexes.end(), material_index) > 0;

		LightObj light{ -1, m_materials[material_index].emittance, INT32_MAX, -1 };

		int i = 0;
		for (const auto& index : shape.mesh.indices)
		{
			VertexObj    vertex = {};
			const float* vp = &attrib.vertices[3 * index.vertex_index];
			vertex.pos = { *(vp + 0), *(vp + 1), *(vp + 2) };

			//int material_id = shape.mesh.material_ids[i++];

			if (!attrib.normals.empty() && index.normal_index >= 0)
			{
				const float* np = &attrib.normals[3 * index.normal_index];
				vertex.nrm = { *(np + 0), *(np + 1), *(np + 2) };
			}

			if (!attrib.texcoords.empty() && index.texcoord_index >= 0)
			{
				const float* tp = &attrib.texcoords[2 * index.texcoord_index + 0];
				vertex.texCoord = { *tp, 1.0f - *(tp + 1) };
			}

			if (!attrib.colors.empty())
			{
				const float* vc = &attrib.colors[3 * index.vertex_index];
				vertex.color = { *(vc + 0), *(vc + 1), *(vc + 2) };
			}

			if (is_light) {
				int current_index = m_indices.size();
				if (light.first_index > current_index) {
					light.first_index = current_index;
				}
				else if (light.last_index < current_index) {
					light.last_index = current_index;
				}
			}

			m_vertices.push_back(vertex);
			m_indices.push_back(static_cast<int>(m_indices.size()));
		}

		if (is_light) {
			m_lights.push_back(light);
		}
	}

	// Fixing material indices
	for (auto& mi : m_matIndx)
	{
		if (mi < 0 || mi > m_materials.size())
			mi = 0;
	}


	// Compute normal when no normal were provided.
	if (attrib.normals.empty())
	{
		for (size_t i = 0; i < m_indices.size(); i += 3)
		{
			VertexObj& v0 = m_vertices[m_indices[i + 0]];
			VertexObj& v1 = m_vertices[m_indices[i + 1]];
			VertexObj& v2 = m_vertices[m_indices[i + 2]];

			glm::vec3 n = glm::normalize(glm::cross((v1.pos - v0.pos), (v2.pos - v0.pos)));
			v0.nrm = n;
			v1.nrm = n;
			v2.nrm = n;
		}
	}
}
