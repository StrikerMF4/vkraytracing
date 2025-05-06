#pragma once

#ifndef SCENE_LOADER
#define SCENE_LOADER

#include "obj_loader.h"
#include <json.hpp>
#include <fstream>
#include <glm/glm.hpp>

static int const DEFAULT_RESOLUTION_WIDTH = 1280;
static int const DEFAULT_RESOLUTION_HEIGHT = 720;

namespace SceneLoader {
	class Entity {
	public:
		virtual ~Entity() {}

		glm::vec3 position = glm::vec3(0.0f);
		glm::vec3 rotation = glm::vec3(0.0f);
		glm::vec3 scale = glm::vec3(1.0f);

	};

	class Shape: public Entity {

	public:
		objl::Loader model_loader;
	};

	class Sphere : public Entity {

	public:
		float radius;
		unsigned int material_idx;
		int inverted_normal = 1;
	};


	class Scene {
	public:
		Scene()
		{

		}
		~Scene()
		{
			for (int i = 0; i < entities.size(); i++) {
				delete entities[i];
			}
		}

		//Rendering parameters
		unsigned int resolution_x = DEFAULT_RESOLUTION_WIDTH;
		unsigned int resolution_y = DEFAULT_RESOLUTION_HEIGHT;
		unsigned int maxdepth = 5;

		glm::vec3 camera_position = glm::vec3(0, 0, 0);
		glm::vec3 camera_lookat = glm::vec3(0, 0, 2);
		float camera_fov = 45;

		//Models in scene
		std::vector<Entity*> entities;
		std::vector<objl::Material> materials;
		std::vector<std::string> textures;

		Scene(const std::string& filename);

	};
}


#endif // !SCENE_LOADER