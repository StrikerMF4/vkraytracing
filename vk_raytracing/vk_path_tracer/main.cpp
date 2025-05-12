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
TechniqueType current_technique = TechniqueType::SIMPLE_PATHTRACER;

VkExtent2D window_size{};
int window_posx, window_posy;

bool paused = false;
bool fullscreen = false;
bool gui_visible = true;
bool config_menu_visible = false;
bool change_scene = false;

int max_depth = MAX_DEPTH / 2;
bool bidirectional_debug_technique = false;
int bidirectional_debug_technique_s = -1, bidirectional_debug_technique_t = -1;
auto pause_timer_start = std::chrono::high_resolution_clock::now();

// GLFW Callback functions
static void onErrorCallback(int error, const char* description);
static void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);

// GUI
static void drawOverlay(std::string& technique_codename, float& render_time, int iterations);
static void drawConfigWindow(float& time_limit, float& time_elapsed, int& iteration_limit);

// Render
bool scene_file_dialog_loop(GLFWwindow* window, std::string* scene_path);
void render_initialization(SceneLoader::Scene* scene, GLFWwindow* window);
void render_loop(GLFWwindow* window);

//--------------------------------------------------------------------------------------------------
// Application Entry
//
int main(int argc, char** argv)
{
	UNUSED(argc);

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

	// Add extensions for atomic image manipulation (used in the bidirectional renderer)
	VkPhysicalDeviceShaderAtomicFloatFeaturesEXT floatFeatures;
	floatFeatures.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_ATOMIC_FLOAT_FEATURES_EXT;
	floatFeatures.shaderImageFloat32AtomicAdd = true; //atomic operations on images
	//floatFeatures.shaderImageFloat32Atomics = true;
	//To-Do: Revisar si sparseImage es más útil o eficiente en el caso de bidirectional, ya que no todos los pixeles tendrán información
	//floatFeatures.sparseImageFloat32Atomics = true;
	//floatFeatures.sparseImageFloat32AtomicAdd = true;
	contextInfo.addDeviceExtension(VK_EXT_SHADER_ATOMIC_FLOAT_EXTENSION_NAME, false, &floatFeatures);

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

	std::string scene_path;
	bool valid_scene = scene_file_dialog_loop(window, &scene_path);

	vkDeviceWaitIdle(vulkanHandler.getDevice());

	//Load Scene
	if (valid_scene) {
		SceneLoader::Scene* scene = new SceneLoader::Scene(scene_path);
		vulkanHandler.loadScene(scene, scene_path);

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
	case GLFW_KEY_F3:
		change_scene = true;
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
				const char* items[] = { "Simple PathTracer", "ShadowRay PathTracer", "Bidirectional PathTracer" };
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

				if (current_technique != (TechniqueType)item_current_idx)
				{
					current_technique = (TechniqueType)item_current_idx;
					vulkanHandler.changeTechnique(current_technique);
					vulkanHandler.m_pcRay.max_depth = max_depth = vulkanHandler.current_technique->default_depth;

					paused = false;
					pause_timer_start = std::chrono::high_resolution_clock::now();
					time_elapsed = 0;
				}

				int new_depth = max_depth;
				if (ImGui::InputInt("Profundida máxima", &new_depth, 1) && new_depth > 0 && new_depth <= MAX_DEPTH) {
					vulkanHandler.m_pcRay.max_depth = max_depth = new_depth;
					vulkanHandler.resetFrame();
				}

				if (current_technique == TechniqueType::BIDIRECTIONAL_PATHTRACER) {
					ImGui::Checkbox("Debug Technique", &bidirectional_debug_technique);

					if (bidirectional_debug_technique) {
						int new_technique_s = bidirectional_debug_technique_s;
						int new_technique_t = bidirectional_debug_technique_t;

						if (ImGui::InputInt("Debug Technique S", &new_technique_s, 1) && new_technique_s >= 0 && new_technique_s <= max_depth) {
							vulkanHandler.m_pcRay.debug_technique_s = bidirectional_debug_technique_s = new_technique_s;
							vulkanHandler.resetFrame();
						}
						if (ImGui::InputInt("Debug Technique T", &new_technique_t, 1) && new_technique_t >= 0 && new_technique_t <= max_depth) {
							vulkanHandler.m_pcRay.debug_technique_t = bidirectional_debug_technique_t = new_technique_t;
							vulkanHandler.resetFrame();
						}
					}
					else if (bidirectional_debug_technique_s != -1 || bidirectional_debug_technique_t != -1) {
						bidirectional_debug_technique_s = vulkanHandler.m_pcRay.debug_technique_s = -1;
						bidirectional_debug_technique_t = vulkanHandler.m_pcRay.debug_technique_t = -1;
						vulkanHandler.resetFrame();
					}
				}

				float new_time_limit = time_limit;
				if (ImGui::InputFloat("Límite de tiempo", &new_time_limit, 0.0f, 0.0f, "%.3f") && new_time_limit >= 0.0f)
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
	vulkanHandler.setupTechnique(TechniqueType::SHADOWRAY_PATHTRACER);
	vulkanHandler.setupTechnique(TechniqueType::SIMPLE_PATHTRACER);
	vulkanHandler.setupTechnique(TechniqueType::BIDIRECTIONAL_PATHTRACER);

	vulkanHandler.changeTechnique(current_technique);
	vulkanHandler.m_pcRay.max_depth = max_depth = vulkanHandler.current_technique->default_depth;

	vulkanHandler.uploadImplicitObjects();
	vulkanHandler.createOffscreenRender();
	vulkanHandler.createDescriptorSetLayout();
	vulkanHandler.createCameraUniformBuffer();
	vulkanHandler.createObjDescriptionBuffer();
	vulkanHandler.createLightBuffer();
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

	vulkanHandler.m_cameraAperture = 0.f;
	vulkanHandler.m_cameraFocalLength = 1.f;
	vulkanHandler.m_pcRay.light_count = vulkanHandler.m_lights.size();
	vulkanHandler.m_pcRay.debug_technique_s = -1;
	vulkanHandler.m_pcRay.debug_technique_t = -1;
}

static void render_loop(GLFWwindow* window) {
	glm::vec4 clearColor = glm::vec4(0, 0, 0, 1.00f);

	time_t start = time(0);

	float time_elapsed = 0;
	float time_limit = 0;
	int iterations = 0;
	int iteration_limit = 0;

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

		if (vulkanHandler.m_createScreenshot)
		{
			std::time_t now = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());

			std::string s(30, '\0');
			std::size_t len = std::strftime(&s[0], s.size(), "%Y-%m-%d %H.%M.%S", std::localtime(&now));
			s.resize(len);
			std::string filename = "screenshot " + s + ".png";

			vulkanHandler.createScreenshot(filename);

			vulkanHandler.m_createScreenshot = false;
		}

		// Submit for display
		vkEndCommandBuffer(cmdBuf);
		vulkanHandler.submitFrame();
	}
}


