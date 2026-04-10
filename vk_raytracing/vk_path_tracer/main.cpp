#include <array>
#define IMGUI_DEFINE_MATH_OPERATORS
#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_vulkan.h"
#include "imgui.h"
#include <imgui_helper.h>
#include <imfilebrowser.h>
#include <scene_loader.h>

#include "vulkan_handler.h"
#include "imgui/imgui_camera_widget.h"
#include "nvh/cameramanipulator.hpp"
#include "nvh/fileoperations.hpp"
#include "nvpsystem.hpp"
#include "nvvk/commands_vk.hpp"
#include "nvvk/context_vk.hpp"
#include <iostream>
#include <chrono>
#include <ctime>
#include <time.h>
#include <fstream>

//////////////////////////////////////////////////////////////////////////
#define UNUSED(x) (void)(x)
//////////////////////////////////////////////////////////////////////////

static int const SAMPLE_WIDTH = 1280;
static int const SAMPLE_HEIGHT = 720;

static ImVec4 const yellow = ImVec4(1.0f, 0.96f, 0.25f, 1.0f);
static ImVec4 const white = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);
static ImVec4 const green = ImVec4(0.33f, 0.91f, 0.29f, 1.0f);
static ImVec4 const red = ImVec4(0.98f, 0.24f, 0.24f, 1.0f);
static float const alpha = 0.6;

// Default search path for shaders
std::vector<std::string> defaultSearchPaths;

//Shared
VulkanHandler vulkanHandler;
Technique current_technique = Technique::BACKWARD_PATHTRACER;

VkExtent2D window_size{};
int window_posx, window_posy;

bool paused = false;
bool fullscreen = false;
bool gui_visible = true;
bool config_menu_visible = false;
int g_auto_exit = 0;
int screenshot_count = 0;
int debug_technique_s = -1;
int debug_technique_t = -1;
bool debug_mis_disabled = false;
bool debug_contribution_disabled = false;

int max_depth = MAX_DEPTH / 2;
bool bidirectional_debug_technique = false;
auto pause_timer_start = std::chrono::high_resolution_clock::now();

double screenshot_time = 0;
int screenshot_iter = 0;
std::string scene_path;
std::string screenshot_path = "screenshots";

glm::vec3 camera_default_position;
glm::vec3 camera_default_lookat;

// GLFW Callback functions
static void onErrorCallback(int error, const char* description);
static void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);

// GUI
static void drawOverlay(std::string& technique_codename, float& render_time, int iterations);
static void drawConfigWindow(float& time_limit, float& time_elapsed, int& iteration_limit);

// Render
static bool scene_file_dialog_loop(GLFWwindow* window, std::string* scene_path);
static void render_initialization(SceneLoader::Scene* scene, GLFWwindow* window);
static void render_loop(GLFWwindow* window);

//--------------------------------------------------------------------------------------------------
// Application Entry
//
int main(int argc, char** argv)
{
	//UNUSED(argc);

	auto print_usage = []() {
		std::cerr <<
			"Uso:\n"
			"  programa -scene <ruta_escena>\n"
			"          [-technique <bpt|nee|bdpt>]\n"
			"          [-screenshot_time <segundos>]\n"
			"          [-screenshot_iter <iteraciones>]\n"
			"          [-auto-exit <num_capturas>]\n"
			"          [-h | --help]\n"
			"\n"
			"Descripcion de parametros:\n"
			"  -scene <ruta>              Ruta al archivo .scn de la escena.\n"
			"  -technique <...>           Tecnica de render: bpt | nee | bdpt.\n"
			"  -screenshot_time <s>       Toma una captura cada <s> segundos.\n"
			"  -screenshot_iter <n>       Toma una captura cada <n> iteraciones.\n"
			"  -screenshot_path <ruta>    Ruta donde se guardan las capturas.\n"
			"  -auto-exit <k>             Cierra el programa luego de <k> capturas.\n"
			"  -debug_technique_s <s>	  Valor de debug - bidirectional s.\n"
			"  -debug_technique_t <t>     Valor de debug - bidirectional t.\n"
			"  -debug_mis_disabled <s>	  Valor de debug - deshabilitar el mis.\n"
			"  -debug_contribution_disabled <t>     Valor de debug - deshabilitar la contribucion.\n"
			"  -h, --help                 Muestra esta ayuda.\n";
		};

	std::string technique = "bdpt";  // valor por defecto

	for (int i = 1; i < argc; ++i) {
		std::string arg = argv[i];

		if (arg == "-auto-exit") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -auto-exit requiere valor entero.\n";
				print_usage();
				return 1;
			}
			try {
				g_auto_exit = std::stoi(argv[++i]);
			}
			catch (...) {
				std::cerr << "Error: valor inválido para -auto-exit.\n";
				print_usage();
				return 1;
			}
		}
		else if (arg == "-scene") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -scene requiere una ruta de escena.\n";
				print_usage();
				return 1;
			}
			scene_path = argv[++i];
		}
		else if (arg == "-technique") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -technique requiere un valor (bpt|nee|bdpt).\n";
				print_usage();
				return 1;
			}
			technique = argv[++i];
		}
		else if (arg == "-screenshot_time") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -screenshot_time requiere un valor en segundos.\n";
				print_usage();
				return 1;
			}
			try {
				screenshot_time = std::stod(argv[++i]);
			}
			catch (...) {
				std::cerr << "Error: valor inválido para -screenshot_time.\n";
				print_usage();
				return 1;
			}
		}
		else if (arg == "-screenshot_iter") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -screenshot_iter requiere valor entero.\n";
				print_usage();
				return 1;
			}
			try {
				screenshot_iter = std::stoi(argv[++i]);
			}
			catch (...) {
				std::cerr << "Error: valor inválido para -screenshot_iter.\n";
				print_usage();
				return 1;
			}
		}
		else if (arg == "-debug_technique_s") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -debug_technique_s requiere valor entero.\n";
				print_usage();
				return 1;
			}
			try {
				debug_technique_s = std::stoi(argv[++i]);
				bidirectional_debug_technique = true;
			}
			catch (...) {
				std::cerr << "Error: valor inválido para -debug_technique_s.\n";
				print_usage();
				return 1;
			}
		}
		else if (arg == "-debug_technique_t") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -debug_technique_t requiere valor entero.\n";
				print_usage();
				return 1;
			}
			try {
				debug_technique_t = std::stoi(argv[++i]);
				bidirectional_debug_technique = true;
			}
			catch (...) {
				std::cerr << "Error: valor inválido para -debug_technique_t.\n";
				print_usage();
				return 1;
			}
		}
		else if (arg == "-debug_mis_disabled") {
			debug_mis_disabled = true;
		}
		else if (arg == "-debug_contribution_disabled") {
			debug_contribution_disabled = true;
		}
		else if (arg == "-screenshot_path") {
			if (i + 1 >= argc) {
				std::cerr << "Error: -screenshot_path requiere una ruta.\n";
				print_usage();
				return 1;
			}
			screenshot_path = argv[++i];
		}
		else if (arg == "-h" || arg == "--help") {
			print_usage();
			return 0;
		}
	}
	
	if (screenshot_iter > 0 || screenshot_time > 0) {
		gui_visible = false;
	}

	bool valid_scene = true;

	// Seleccionar la técnica inicial según el parámetro
	if (technique == "bpt") {
		current_technique = Technique::BACKWARD_PATHTRACER;
	}
	else if (technique == "nee") {
		current_technique = Technique::BACKWARD_PATHTRACER_NEE;
	}
	else if (technique == "bdpt") {
		current_technique = Technique::BIDIRECTIONAL_PATHTRACER;
	}

	// Setup GLFW window
	glfwSetErrorCallback(onErrorCallback);
	if (!glfwInit())
	{
		return 1;
	}
	glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
	GLFWwindow* window = glfwCreateWindow(SAMPLE_WIDTH, SAMPLE_HEIGHT, PROJECT_NAME, nullptr, nullptr);

	// Setup Vulkan
	if (!glfwVulkanSupported())
	{
		printf("GLFW: Vulkan Not Supported\n");
		return 1;
	}

	// setup some basic things for the sample, logging file for example
	NVPSystem system(PROJECT_NAME);

	// Search path for shaders and other media
	defaultSearchPaths = {
		NVPSystem::exePath() + PROJECT_RELDIRECTORY,
		NVPSystem::exePath() + PROJECT_RELDIRECTORY "..",
		std::string(PROJECT_NAME),
	};

	// Vulkan required extensions
	assert(glfwVulkanSupported() == 1);
	uint32_t count{ 0 };
	auto     reqExtensions = glfwGetRequiredInstanceExtensions(&count);

	// Requesting Vulkan extensions and layers
	nvvk::ContextCreateInfo contextInfo;
	contextInfo.setVersion(1, 2);                       // Using Vulkan 1.2
	for (uint32_t ext_id = 0; ext_id < count; ext_id++)  // Adding required extensions (surface, win32, linux, ..)
		contextInfo.addInstanceExtension(reqExtensions[ext_id]);
	contextInfo.addInstanceExtension(VK_EXT_DEBUG_UTILS_EXTENSION_NAME, true);  // Allow debug names
	contextInfo.addDeviceExtension(VK_KHR_SWAPCHAIN_EXTENSION_NAME);            // Enabling ability to present rendering

	// #VKRay: Activate the ray tracing extension
	VkPhysicalDeviceAccelerationStructureFeaturesKHR accelFeature{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR };
	contextInfo.addDeviceExtension(VK_KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME, false, &accelFeature);  // To build acceleration structures
	VkPhysicalDeviceRayTracingPipelineFeaturesKHR rtPipelineFeature{ VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR };
	contextInfo.addDeviceExtension(VK_KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME, false, &rtPipelineFeature);  // To use vkCmdTraceRaysKHR
	contextInfo.addDeviceExtension(VK_KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME);  // Required by ray tracing pipeline


	// Creating Vulkan base application
	nvvk::Context vkctx{};
	vkctx.initInstance(contextInfo);
	// Find all compatible devices
	auto compatibleDevices = vkctx.getCompatibleDevices(contextInfo);
	assert(!compatibleDevices.empty());
	// Use a compatible device
	vkctx.initDevice(compatibleDevices[0], contextInfo);

	// Window need to be opened to get the surface on which to draw
	const VkSurfaceKHR surface = vulkanHandler.getVkSurface(vkctx.m_instance, window);
	vkctx.setGCTQueueWithPresent(surface);

	vulkanHandler.setup(vkctx.m_instance, vkctx.m_device, vkctx.m_physicalDevice, vkctx.m_queueGCT.familyIndex);
	vulkanHandler.createSwapchain(surface, SAMPLE_WIDTH, SAMPLE_HEIGHT);
	vulkanHandler.createDepthBuffer();
	vulkanHandler.createRenderPass();
	vulkanHandler.createFrameBuffers();

	// Setup Imgui
	vulkanHandler.initGUI(0);  // Using sub-pass 0

	vulkanHandler.setupGlfwCallbacks(window);
	glfwSetKeyCallback(window, &keyCallback);

	ImGui_ImplGlfw_InitForVulkan(window, true);

	purpleTheme();

	if (scene_path.size() == 0)
		valid_scene = scene_file_dialog_loop(window, &scene_path);

	vkDeviceWaitIdle(vulkanHandler.getDevice());

	//Load Scene
	if (valid_scene) {
		SceneLoader::Scene* scene = new SceneLoader::Scene(scene_path);
		vulkanHandler.loadScene(scene, scene_path);

		camera_default_position = scene->camera_position;
		camera_default_lookat = scene->camera_lookat;

		render_initialization(scene, window);

		vulkanHandler.resetFrame();

		render_loop(window);
	}

	// Cleanup
	vkDeviceWaitIdle(vulkanHandler.getDevice());

	vulkanHandler.destroyResources();
	vulkanHandler.destroy();
	vkctx.deinit();

	glfwDestroyWindow(window);
	glfwTerminate();

	return 0;
}


//GLFW

static void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	if (action != GLFW_PRESS)
		return;

	switch (key)
	{
	case GLFW_KEY_Q:
		glfwSetWindowShouldClose(window, 1);
		break;
	case GLFW_KEY_F1:
		gui_visible = !gui_visible;
		break;
	case GLFW_KEY_F2:
		vulkanHandler.m_createScreenshot = true;
		break;
	case GLFW_KEY_F11:
		fullscreen = !fullscreen;
		if (fullscreen) {
			window_size = vulkanHandler.getSize();
			glfwGetWindowPos(window, &window_posx, &window_posy);
			GLFWmonitor* monitor = glfwGetPrimaryMonitor();
			const GLFWvidmode* mode = glfwGetVideoMode(monitor);
			glfwSetWindowMonitor(window, monitor, 0, 0, mode->width, mode->height, mode->refreshRate);
		}
		else {
			glfwSetWindowMonitor(window, NULL, window_posx, window_posy, window_size.width, window_size.height, 0);
		}
		break;
	case GLFW_KEY_ESCAPE:
		config_menu_visible = !config_menu_visible;
		break;
	case GLFW_KEY_P:
		paused = !paused;
		if (!paused)
		{
			pause_timer_start = std::chrono::high_resolution_clock::now();
		}

		break;
	case GLFW_KEY_R:
		vulkanHandler.resetFrame();
		break;
	case GLFW_KEY_C:
		const auto& view = CameraManip.getMatrix();
		const auto& invView = glm::inverse(view);
		glm::vec3 origin = glm::vec3(invView[3]);

		glm::vec3 forward = -glm::vec3(invView[2]); // third column (z-axis), negative because camera looks -Z
		glm::vec3 lookAt = origin + forward;

		LOGI("Camera Position: (%.3f, %.3f, %.3f)\n", origin.x, origin.y, origin.z);
		LOGI("Camera Lookat: (%.3f, %.3f, %.3f)\n", lookAt.x, lookAt.y, lookAt.z);
		break;
	}
}

static void onErrorCallback(int error, const char* description)
{
	fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

//GUI

static void drawOverlay(std::string& technique_codename, float& render_time, int iterations)
{
	ImGuiWindowFlags window_flags = ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoFocusOnAppearing | ImGuiWindowFlags_NoNav;

	const float PAD = 10.0f;
	const ImGuiViewport* viewport = ImGui::GetMainViewport();
	ImVec2 work_pos = viewport->WorkPos; // Use work area to avoid menu-bar/task-bar, if any!
	ImVec2 work_size = viewport->WorkSize;
	ImVec2 window_pos, window_pos_pivot;
	window_pos.x = work_pos.x + PAD;
	window_pos.y = work_pos.y + PAD;
	window_pos_pivot.x = 0.0f;
	window_pos_pivot.y = 0.0f;
	ImGui::SetNextWindowPos(window_pos, ImGuiCond_Always, window_pos_pivot);
	ImGui::SetNextWindowViewport(viewport->ID);
	window_flags |= ImGuiWindowFlags_NoMove;

	ImGui::SetNextWindowBgAlpha(alpha); // Transparent background
	if (ImGui::Begin("Overlay", NULL, window_flags))
	{
		//Algoritmo
		ImGui::TextColored(yellow, "Algoritmo: ");
		ImGui::SameLine();
		ImGui::TextColored(white, technique_codename.c_str());

		//Estadisticas
		ImGui::TextColored(yellow, "Estadísticas: ");
		ImGui::SameLine();
		if (paused)
			ImGui::TextColored(white, "- FPS   - ms");
		else
			ImGui::TextColored(white, "%.0f FPS   %.3f ms", ImGui::GetIO().Framerate, 1000.0f / ImGui::GetIO().Framerate);

		//Tiempo de renderizado
		ImGui::TextColored(yellow, "Tiempo de ejecución: ");
		ImGui::SameLine();
		ImGui::TextColored(white, "%.3f secs", render_time);

		//Iteraciones
		ImGui::TextColored(yellow, "Iteraciones: ");
		ImGui::SameLine();
		ImGui::TextColored(white, "%d", iterations); //Placeholder

		//Tiempo de renderizado
		ImGui::TextColored(yellow, "Estado: ");
		ImGui::SameLine();
		if (paused)
			ImGui::TextColored(red, "pausado");
		else
			ImGui::TextColored(green, "ejecutando");

		ImGui::NewLine();

		//Informacion
		ImGui::TextColored(white, "ESC: mostrar menu");
		ImGui::TextColored(white, "F1: ocultar interfaz");
		ImGui::TextColored(white, "F2: guardar captura de pantalla");
		ImGui::TextColored(white, "F11: pantalla completa");

		ImGui::TextColored(white, "R: reiniciar");
		ImGui::TextColored(white, "P: pausar");
		ImGui::TextColored(white, "Q: salir");
	}
	ImGui::End();
}

static void drawConfigWindow(float& time_limit, float& time_elapsed, int& iteration_limit) {
	ImGuiH::Panelv2::Begin(ImGuiH::Panel::Side::Right, alpha, nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoMove);

	// Content
	{
		if (ImGui::BeginTabBar("#Tabs", ImGuiTabBarFlags_None))
		{
			if (ImGui::BeginTabItem("Algoritmo"))
			{
				const char* items[] = { "Backward Pathtracer", "Backward Pathtracer (NEE)", "Bidirectional Pathtracer" };
				static int item_current_idx = current_technique; // Here we store our selection data as an index.

				// Pass in the preview value visible before opening the combo (it could technically be different contents or not pulled from items[])
				const char* combo_preview_value = items[item_current_idx];

				if (ImGui::BeginCombo("Algoritmo", combo_preview_value))
				{
					for (int n = 0; n < IM_ARRAYSIZE(items); n++)
					{
						const bool is_selected = (item_current_idx == n);
						if (ImGui::Selectable(items[n], is_selected))
							item_current_idx = n;

						// Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
						if (is_selected)
							ImGui::SetItemDefaultFocus();
					}
					ImGui::EndCombo();
				}

				if (current_technique != (Technique)item_current_idx)
				{
					current_technique = (Technique)item_current_idx;
					vulkanHandler.changeTechnique(current_technique);

					paused = false;
					pause_timer_start = std::chrono::high_resolution_clock::now();
					time_elapsed = 0;
				}

				int new_depth = max_depth;
				if (ImGui::InputInt("Profundida máxima", &new_depth, 1) && new_depth > 0 && new_depth <= MAX_DEPTH) {
					vulkanHandler.m_pcRay.max_depth = max_depth = new_depth;
					vulkanHandler.resetFrame();
				}

				if (current_technique == Technique::BIDIRECTIONAL_PATHTRACER) {
					ImGui::SeparatorText("Bidirectional PathTracer:");

					ImGui::Checkbox("Fijar técnica", &bidirectional_debug_technique);

					if (bidirectional_debug_technique) {
						int new_technique_s = vulkanHandler.m_pcRay.debug_technique_s;
						if (ImGui::InputInt("s (-1 = todos)", &new_technique_s, 1) && new_technique_s >= -1 && new_technique_s <= max_depth) {
							vulkanHandler.m_pcRay.debug_technique_s = new_technique_s;
							vulkanHandler.resetFrame();
						}

						int new_technique_t = vulkanHandler.m_pcRay.debug_technique_t;
						if (ImGui::InputInt("t (-1 = todos)", &new_technique_t, 1) && new_technique_t >= -1 && new_technique_t <= max_depth) {
							vulkanHandler.m_pcRay.debug_technique_t = new_technique_t;
							vulkanHandler.resetFrame();
						}
					}
					else if (vulkanHandler.m_pcRay.debug_technique_s != -1 || vulkanHandler.m_pcRay.debug_technique_s != -1) {
						vulkanHandler.m_pcRay.debug_technique_s = -1;
						vulkanHandler.m_pcRay.debug_technique_t = -1;
						vulkanHandler.resetFrame();
					}

					bool bidirectional_debug_include_mis = vulkanHandler.m_pcRay.debug_multiply_mis == 1;
					if (ImGui::Checkbox("Aplicar MIS", &bidirectional_debug_include_mis)) {
						vulkanHandler.m_pcRay.debug_multiply_mis = bidirectional_debug_include_mis ? 1 : 0;
						vulkanHandler.resetFrame();
					}

					bool bidirectional_debug_include_contribution = vulkanHandler.m_pcRay.debug_multiply_contribution == 1;
					if (ImGui::Checkbox("Aplicar Contribución", &bidirectional_debug_include_contribution)) {
						vulkanHandler.m_pcRay.debug_multiply_contribution = bidirectional_debug_include_contribution ? 1 : 0;
						vulkanHandler.resetFrame();
					}
				}

				ImGui::SeparatorText("Ejecución:");

				float new_time_limit = time_limit;
				if (ImGui::InputFloat("Límite de tiempo (s)", &new_time_limit, 0.0f, 0.0f, "%.3f") && new_time_limit >= 0.0f)
					time_limit = new_time_limit;

				int new_iterations_limit = iteration_limit;
				if (ImGui::InputInt("Límite de iteraciones", &new_iterations_limit) && new_iterations_limit >= 0)
					iteration_limit = new_iterations_limit;

				const char* pause_button_text = paused ? "Reanudar" : "Pausar";
				if (ImGui::Button(pause_button_text))
				{
					paused = !paused;

					if (!paused)
					{
						pause_timer_start = std::chrono::high_resolution_clock::now();
					}
				}
				ImGui::SameLine();
				if (ImGui::Button("Reiniciar"))
				{
					vulkanHandler.resetFrame();
				}

				ImGui::EndTabItem();
			}
			if (ImGui::BeginTabItem("Cámara"))
			{
				ImGui::DragFloat("Apertura", &vulkanHandler.m_cameraAperture, 0.0001, 0.0f, 5.0f, "%.4f"); //camera parameters
				ImGui::DragFloat("Distancia Focal", &vulkanHandler.m_cameraFocalLength, 0.001, 0.1f, 20.f);

				float fov = CameraManip.getFov();
				if (ImGui::DragFloat("Campo de visión", &fov, 0.1, 0.1f, 200.f, "%.1f")) {
					CameraManip.setFov(fov);
				}

				if (ImGui::DragFloat("Radio Antialiasing", &vulkanHandler.m_pcRay.antialiasing_radius, 0.0001, 0.0f, 1.0f, "%.4f")) {
					vulkanHandler.resetFrame();
				}

				if (ImGui::Button("Reiniciar Posición"))
				{
					CameraManip.setLookat(camera_default_position, camera_default_lookat, glm::vec3(0, 1, 0));
				}

				ImGui::DragFloat("Exposición", &vulkanHandler.m_pcPost.exposition, 0.01, -10.0f, 10.f);

				ImGui::EndTabItem();
			}

			ImGui::EndTabBar();
		}
	}

	ImGuiH::Panel::End();
}

//Render

static bool scene_file_dialog_loop(GLFWwindow* window, std::string* scene_path) {
	ImGui::FileBrowser fileDialog = ImGui::FileBrowser(
		ImGuiFileBrowserFlags_ConfirmOnEnter | ImGuiFileBrowserFlags_EditPathString |
		ImGuiFileBrowserFlags_NoTitleBar, ".."
	);
	fileDialog.SetTypeFilters({ ".scn" }); 

	fileDialog.Open();

	while (!glfwWindowShouldClose(window)) {
		glfwPollEvents();
		if (vulkanHandler.isMinimized())
			continue;

		ImGui_ImplGlfw_NewFrame();
		ImGui::NewFrame();

		fileDialog.Display();

		vulkanHandler.prepareFrame();

		auto curFrame = vulkanHandler.getCurFrame();
		const VkCommandBuffer& cmdBuf = vulkanHandler.getCommandBuffers()[curFrame];

		VkCommandBufferBeginInfo beginInfo{ VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
		beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
		vkBeginCommandBuffer(cmdBuf, &beginInfo);

		// Clearing screen
		std::array<VkClearValue, 2> clearValues{};
		clearValues[0].color = { {0, 0, 0, 0} };
		clearValues[1].depthStencil = { 1.0f, 0 };

		// 2nd rendering pass: tone mapper, UI
		{
			VkRenderPassBeginInfo postRenderPassBeginInfo{ VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
			postRenderPassBeginInfo.clearValueCount = 3;
			postRenderPassBeginInfo.pClearValues = clearValues.data();
			postRenderPassBeginInfo.renderPass = vulkanHandler.getRenderPass();
			postRenderPassBeginInfo.framebuffer = vulkanHandler.getFramebuffers()[curFrame];
			postRenderPassBeginInfo.renderArea = { {0, 0}, vulkanHandler.getSize() };

			// Rendering tonemapper
			vkCmdBeginRenderPass(cmdBuf, &postRenderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
			// Rendering UI
			ImGui::Render();
			ImGui_ImplVulkan_RenderDrawData(ImGui::GetDrawData(), cmdBuf);
			vkCmdEndRenderPass(cmdBuf);
		}

		vkEndCommandBuffer(cmdBuf);
		vulkanHandler.submitFrame();

		if (fileDialog.HasSelected())
		{
			std::cout << "Selected filename" << fileDialog.GetSelected().string() << std::endl;
			*scene_path = nvh::findFile(fileDialog.GetSelected().string(), defaultSearchPaths, true);
			fileDialog.ClearSelected();
			return true;
		}
	}
	return false;
}

static void render_initialization(SceneLoader::Scene* scene, GLFWwindow* window) {
	vulkanHandler.setupTechnique(Technique::BACKWARD_PATHTRACER_NEE);
	vulkanHandler.setupTechnique(Technique::BACKWARD_PATHTRACER);
	vulkanHandler.setupTechnique(Technique::BIDIRECTIONAL_PATHTRACER);

	vulkanHandler.changeTechnique(current_technique);
	vulkanHandler.m_pcRay.max_depth = max_depth = scene->maxdepth;

	vulkanHandler.uploadImplicitObjects();
	vulkanHandler.createOffscreenRender();
	vulkanHandler.createDescriptorSetLayout();
	vulkanHandler.createCameraUniformBuffer();
	vulkanHandler.createObjDescriptionBuffer();
	vulkanHandler.createLightBuffer();
	vulkanHandler.createDirectionalLightBuffer();
	vulkanHandler.updateDescriptorSet();

	// #VKRay
	vulkanHandler.initRayTracing();
	vulkanHandler.createBottomLevelAS();
	vulkanHandler.createTopLevelAS();
	vulkanHandler.createRtDescriptorSet();
	vulkanHandler.createRtPipeline();
	vulkanHandler.createRtShaderBindingTable();

	vulkanHandler.createPostDescriptor();
	vulkanHandler.createPostPipeline();
	vulkanHandler.updatePostDescriptorSet();

	// Setup camera
	glfwSetWindowSize(window, scene->resolution_x, scene->resolution_y);
	CameraManip.setLookat(scene->camera_position, scene->camera_lookat, glm::vec3(0, 1, 0));
	CameraManip.setFov(scene->camera_fov);
	CameraManip.setSpeed(5.0f);

	vulkanHandler.m_cameraAperture = 0.f;
	vulkanHandler.m_cameraFocalLength = 1.f;

	vulkanHandler.m_pcRay.light_count = vulkanHandler.m_lights.size();
	vulkanHandler.m_pcRay.directional_light_count = vulkanHandler.m_directional_lights.size();
	vulkanHandler.m_pcRay.debug_technique_s = debug_technique_s;
	vulkanHandler.m_pcRay.debug_technique_t = debug_technique_t;
	vulkanHandler.m_pcRay.antialiasing_radius = scene->antialiasing_radius;

	vulkanHandler.m_pcRay.debug_multiply_mis = !debug_mis_disabled;
	vulkanHandler.m_pcRay.debug_multiply_contribution = !debug_contribution_disabled;

	vulkanHandler.m_pcPost.exposition = 0.f;
}

std::string techniqueToString(Technique t) {
	switch (t) {
	case Technique::BACKWARD_PATHTRACER: return "BPT";
	case Technique::BACKWARD_PATHTRACER_NEE: return "BPTNEE";
	case Technique::BIDIRECTIONAL_PATHTRACER: 
		if (bidirectional_debug_technique)
			return "BDPT(s=" + std::to_string(vulkanHandler.m_pcRay.debug_technique_s) 
					+ ",t=" + std::to_string(vulkanHandler.m_pcRay.debug_technique_t) + ")";
		else
		return "BDPT";
	default: return "Unknown";
	}
}

static void render_loop(GLFWwindow* window) {
	glm::vec4 clearColor = glm::vec4(0, 0, 0, 1.00f);

	time_t start = time(0);

	float time_elapsed = 0;
	float time_limit = 0;
	int iterations = 0;
	int iteration_limit = 0;

	auto startTime = std::chrono::steady_clock::now();

	// Main loop
	while (!glfwWindowShouldClose(window))
	{

		if (vulkanHandler.m_pcRay.frame <= 0) {
			paused = false;
			pause_timer_start = std::chrono::high_resolution_clock::now();
			time_elapsed = 0;
		}
		iterations = vulkanHandler.m_pcRay.frame + 1;

		glfwPollEvents();
		CameraManip.updateAnim();
		if (vulkanHandler.isMinimized())
			continue;

		// Start the Dear ImGui frame
		ImGui_ImplGlfw_NewFrame();
		ImGui::NewFrame();

		// Show UI window.
		if (gui_visible) {
			drawOverlay(vulkanHandler.current_technique->formatted_name, time_elapsed, iterations);

			if (config_menu_visible) {
				drawConfigWindow(time_limit, time_elapsed, iteration_limit);
			}
		}

		if (!paused) {
			auto now = std::chrono::high_resolution_clock::now();
			std::chrono::duration<float> elapsed = now - pause_timer_start;
			time_elapsed += elapsed.count();
			pause_timer_start = now;
			
			if (time_limit > 0.01f && time_elapsed > time_limit)
				paused = true;

			if (iteration_limit > 0 && iterations >= iteration_limit)
				paused = true;
		}

		// Start rendering the scene
		vulkanHandler.prepareFrame();

		// Start command buffer of this frame
		auto curFrame = vulkanHandler.getCurFrame();
		const VkCommandBuffer& cmdBuf = vulkanHandler.getCommandBuffers()[curFrame];

		VkCommandBufferBeginInfo beginInfo{ VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO };
		beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
		vkBeginCommandBuffer(cmdBuf, &beginInfo);

		// Updating camera buffer
		vulkanHandler.updateUniformBuffer(cmdBuf);

		// Clearing screen
		std::array<VkClearValue, 2> clearValues{};
		clearValues[0].color = { {clearColor[0], clearColor[1], clearColor[2], clearColor[3]} };
		clearValues[1].depthStencil = { 1.0f, 0 };

		// Offscreen render pass
		{
			if (!paused)
			{
				vulkanHandler.raytrace(cmdBuf);
			}
		}

		// 2nd rendering pass: tone mapper, UI
		{
			VkRenderPassBeginInfo postRenderPassBeginInfo{ VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
			postRenderPassBeginInfo.clearValueCount = 3;
			postRenderPassBeginInfo.pClearValues = clearValues.data();
			postRenderPassBeginInfo.renderPass = vulkanHandler.getRenderPass();
			postRenderPassBeginInfo.framebuffer = vulkanHandler.getFramebuffers()[curFrame];
			postRenderPassBeginInfo.renderArea = { {0, 0}, vulkanHandler.getSize() };

			// Rendering tonemapper
			vkCmdBeginRenderPass(cmdBuf, &postRenderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
			vulkanHandler.drawPost(cmdBuf);
			// Rendering UI
			ImGui::Render();
			ImGui_ImplVulkan_RenderDrawData(ImGui::GetDrawData(), cmdBuf);
			vkCmdEndRenderPass(cmdBuf);
		}

		// Submit for display
		vkEndCommandBuffer(cmdBuf);
		vulkanHandler.submitFrame();

		auto now = std::chrono::steady_clock::now();
		double elapsedSec = std::chrono::duration<double>(now - startTime).count();
		if ((screenshot_time > 0 && elapsedSec >= screenshot_time) ||
			(screenshot_iter > 0 && (iterations+1) % screenshot_iter == 0)) {
			vulkanHandler.m_createScreenshot = true;
		}

		if (vulkanHandler.m_createScreenshot)
		{
			std::time_t now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());

			std::string s(30, '\0');
			std::size_t len = std::strftime(&s[0], s.size(), "%Y-%m-%d %H.%M.%S", std::localtime(&now));
			s.resize(len);
			std::filesystem::path p(scene_path);
			LOGI(scene_path.c_str());
			std::string filename = p.filename().string() + "_" + techniqueToString(current_technique) + s + "-" + std::to_string(iterations + 1) + ".exr";
			
			const std::filesystem::path outDir = std::filesystem::path(screenshot_path);
			std::error_code ec;
			std::filesystem::create_directories(outDir, ec);

			std::filesystem::path outPath = outDir / filename;

			vulkanHandler.createScreenshot(outPath);
			vulkanHandler.m_createScreenshot = false;
			screenshot_count++;

			std::ofstream logFile("log.txt", std::ios::app);
			if (logFile) {
				logFile << filename << " " << elapsedSec << " " << iterations << "\n";
				logFile.flush();
			}
			else if (!logFile) {
				std::cerr << "No se pudo abrir el archivo de log: log.txt\n";
			}

			if (g_auto_exit > 0 && g_auto_exit <= screenshot_count) {
				vkDeviceWaitIdle(vulkanHandler.getDevice());
				glfwSetWindowShouldClose(window, GLFW_TRUE);
				return;
			}
			startTime = std::chrono::steady_clock::now();
		}
	}
}
