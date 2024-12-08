
#include "scene_loader.h"

using json = nlohmann::json;

Scene::Scene(const std::string& filename) {
	std::ifstream f(filename);
	json data = json::parse(f);

	std::map<std::string, objl::Material*> materials_map;

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

			material.name = (*it)["name"].template get<std::string>();

			if (material.name == "default_material")
				defines_default_material = true;

			material.baseColor = glm::vec3(
				(*it)["color"][0].template get<double>(),
				(*it)["color"][1].template get<double>(),
				(*it)["color"][2].template get<double>()
			);

			material.ID = materials.size();
			materials.push_back(material);
			
			materials_map.insert({ material.name, &materials[material.ID] });

			if (data.contains("albedotexture")) {
				material.albedoTextureID = textures.size();
				textures.push_back(data["albedotexture"].template get<std::string>());
			}
			if (data.contains("metallicroughnesstexture")) {
				material.metallicRoughnessTextureID = textures.size();
				textures.push_back(data["metallicroughnesstexture"].template get<std::string>());
			}
			if (data.contains("normaltexture")) {
				material.normalTextureID = textures.size();
				textures.push_back(data["normaltexture"].template get<std::string>());
			}
			if (data.contains("emissiontexture")) {
				material.emissionTextureID = textures.size();
				textures.push_back(data["emissiontexture"].template get<std::string>());
			}

		}
	}

	if (!defines_default_material) {
		objl::Material default_material;

		default_material.ID = materials.size();
		materials.push_back(default_material);
	}


	if (data.contains("entities")) {
		json entities_data = data["entities"];

		for (json::iterator it = entities_data.begin(); it != entities_data.end(); ++it) {
			//Entity entity;
			if (!(*it).contains("file"))
				continue;

			std::string path = (*it)["file"].template get<std::string>();

			objl::Material* default_material = nullptr;
			if ((*it).contains("default_material"))
				default_material = materials_map[(*it)["default_material"].template get<std::string>()];
			else
				default_material = materials_map["default_material"];

			entities.push_back(Shape());
			Shape* shape = (Shape*)&entities[entities.size() - 1];

			shape->model_loader.LoadFile(path, &materials_map, default_material);
		}
	}
}