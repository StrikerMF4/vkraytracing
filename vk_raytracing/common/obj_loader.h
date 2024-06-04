/*
 * Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
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

#pragma once
#include <glm/glm.hpp>
#include "tiny_obj_loader.h"
#include <array>
#include <iostream>
#include <stdint.h>
#include <unordered_map>
#include <vector>

 // Structure holding the material
struct MaterialObj
{
	glm::vec3 color = glm::vec3(0.1f, 0.1f, 0.1f);

	float IOR = 1.0f;
	float roughness;
	float metallic;
	glm::vec3 emittance = glm::vec3(0.0f, 0.0f, 0.0f);
	float transparent = 1.0;

	int textureID = -1;
};
// OBJ representation of a vertex
// NOTE: BLAS builder depends on pos being the first member
struct VertexObj
{
	glm::vec3 pos;
	glm::vec3 nrm;
	glm::vec3 color;
	glm::vec2 texCoord;
};


struct shapeObj
{
	uint32_t offset;
	uint32_t nbIndex;
	uint32_t matIndex;
};

class ObjLoader
{
public:
	void loadModel(const std::string& filename);

	std::vector<VertexObj>   m_vertices;
	std::vector<uint32_t>    m_indices;
	std::vector<MaterialObj> m_materials;
	std::vector<std::string> m_textures;
	std::vector<int32_t>     m_matIndx;
};
