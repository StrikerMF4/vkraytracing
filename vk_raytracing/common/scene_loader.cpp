
#include "scene_loader.h"
#include <nvh/nvprint.hpp>

using json = nlohmann::json;

Scene::Scene(const std::string& filepath) {

	std::filesystem::path path = filepath;

	// Get the parent directory of the file
	std::filesystem::path parentDir = path.parent_path();

	std::ifstream f(filepath);
	json data = json::parse(f);

	std::map<std::string, objl::Material> materials_map;

	if (data.contains("resolution")) {
		resolution_x = data["resolution"][0].template get<unsigned int>();
		resolution_y = data["resolution"][1].template get<unsigned int>();
	}
	if (data.contains("maxdepth"))
		maxdepth = data["maxdepth"].template get<unsigned int>();

	if (data.contains("camera")) {
		json camera_data = data["parameters"];

		if (data.contains("fov"))
			camera_fov = camera_data["fov"].template get<unsigned int>();
		if (data.contains("position"))
			camera_position = glm::vec3(
				camera_data["position"][0].template get<double>(),
				camera_data["position"][1].template get<double>(),
				camera_data["position"][2].template get<double>());
		if (data.contains("lookat"))
			camera_position = glm::vec3(
				camera_data["lookat"][0].template get<double>(),
				camera_data["lookat"][1].template get<double>(),
				camera_data["lookat"][2].template get<double>());
	}

	bool defines_default_material = false;
	if (data.contains("materials")) {
		json materials_data = data["materials"];

		for (json::iterator it = materials_data.begin(); it != materials_data.end(); ++it) {
			objl::Material material;

			std::string name = (*it)["name"].template get<std::string>();

			if (name == "default_material")
				defines_default_material = true;

			if ((*it).contains("color"))
				material.baseColor = glm::vec3(
					(*it)["color"][0].template get<double>(),
					(*it)["color"][1].template get<double>(),
					(*it)["color"][2].template get<double>()
				);

			if ((*it).contains("emission"))
				material.emission = glm::vec3(
					(*it)["emission"][0].template get<double>(),
					(*it)["emission"][1].template get<double>(),
					(*it)["emission"][2].template get<double>()
				);

			if ((*it).contains("roughness"))
				material.roughness = (*it)["roughness"].template get<double>();

			if ((*it).contains("albedotexture")) {
				material.albedoTextureID = textures.size();
				textures.push_back((*it)["albedotexture"].template get<std::string>());
			}
			if ((*it).contains("metallicroughnesstexture")) {
				material.metallicRoughnessTextureID = textures.size();
				textures.push_back((*it)["metallicroughnesstexture"].template get<std::string>());
			}
			if ((*it).contains("normaltexture")) {
				material.normalTextureID = textures.size();
				textures.push_back((*it)["normaltexture"].template get<std::string>());
			}
			if ((*it).contains("emissiontexture")) {
				material.emissionTextureID = textures.size();
				textures.push_back((*it)["emissiontexture"].template get<std::string>());
			}

			//Save the material
			material.ID = materials.size();
			materials.push_back(material);

			materials_map.insert({ name, material });
		}
	}

	if (!defines_default_material) {
		objl::Material default_material;

		default_material.ID = materials.size();

		materials.push_back(default_material);
		materials_map["default_material"] = default_material;
	}


	if (data.contains("entities")) {
		json entities_data = data["entities"];

		for (json::iterator it = entities_data.begin(); it != entities_data.end(); ++it) {
			Entity* entity;

			std::string entity_type = (*it)["type"].template get<std::string>();

			if (entity_type == "mesh") {
				if (!(*it).contains("file"))
					continue;

				std::filesystem::path model_name = (*it)["file"].template get<std::string>();
				std::filesystem::path path = parentDir / model_name;


				//TO-DO: Agregar opción para sobreescribir el material con uno fijo
				objl::Material* default_material = nullptr;
				if ((*it).contains("default_material"))
					default_material = &materials_map[(*it)["default_material"].template get<std::string>()];
				else
					default_material = &materials_map["default_material"];

				Shape* shape = new Shape();

				shape->model_loader.LoadFile(path.string(), &materials_map, default_material);

				entity = shape;
			}
			else {
				LOGI("SCENE_LOADER::UNRECOGNISED_ENTITY_TYPE:: received type: ",entity_type);
			}

			if ((*it).contains("position"))
				entity->position = glm::vec3(
					(*it)["position"][0].template get<double>(),
					(*it)["position"][1].template get<double>(),
					(*it)["position"][2].template get<double>()
				);

			if ((*it).contains("rotation"))
				entity->rotation = glm::vec3(
					(*it)["rotation"][0].template get<double>(),
					(*it)["rotation"][1].template get<double>(),
					(*it)["rotation"][2].template get<double>()
				);

			if ((*it).contains("scale"))
				entity->scale = glm::vec3(
					(*it)["scale"][0].template get<double>(),
					(*it)["scale"][1].template get<double>(),
					(*it)["scale"][2].template get<double>()
				);

			entities.push_back(entity);
		}
	}
}