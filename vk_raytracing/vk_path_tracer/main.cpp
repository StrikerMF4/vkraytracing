#include <array>
#include <time.h>
#define IMGUI_DEFINE_MATH_OPERATORS
#include "backends/imgui_impl_glfw.h"
#include "backends/imgui_impl_vulkan.h"
#include "imgui.h"
#include <imgui_helper.h>
#include <scene_loader.h>

#include "vulkan_handler.h"
#include "imgui/imgui_camera_widget.h"
#include "nvh/cameramanipulator.hpp"
#include "nvh/fileoperations.hpp"
#include "nvpsystem.hpp"
#include "nvvk/commands_vk.hpp"
#include "nvvk/context_vk.hpp"
#include <time.h>

//////////////////////////////////////////////////////////////////////////
#define UNUSED(x) (void)(x)
//////////////////////////////////////////////////////////////////////////

// Default search path for shaders
std::vector<std::string> defaultSearchPaths;

ImVec4 yellow = ImVec4(1.0f, 0.96f, 0.25f, 1.0f);
ImVec4 white = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);
ImVec4 green = ImVec4(0.33f, 0.91f, 0.29f, 1.0f);
ImVec4 red = ImVec4(0.98f, 0.24f, 0.24f, 1.0f);

//Shared
VulkanHandler vulkanHandler;

bool paused = false;
bool gui_visible = true;
bool menu_visible = false;

// GLFW Callback functions
static void onErrorCallback(int error, const char* description)
{
	fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

static void key_cb(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	if (action == GLFW_PRESS)
	{
		switch (key)
		{
		case GLFW_KEY_Q:
			glfwSetWindowShouldClose(window, 1);
			break;
		case GLFW_KEY_F1:
			gui_visible = !gui_visible;
			break;
		case GLFW_KEY_ESCAPE:
			menu_visible = !menu_visible;
			break;
		case GLFW_KEY_P:
			paused = !paused;
			break;
		case GLFW_KEY_R:
			vulkanHandler.resetFrame();
			break;
		}
	}
}

// Extra UI
void renderUI(VulkanHandler& vulkanHandler)
{
	if (ImGui::CollapsingHeader("Extra widget"))
	{
		ImGuiH::CameraWidget();
		ImGui::RadioButton("Point", &vulkanHandler.m_pcRaster.lightType, 0);
		ImGui::SameLine();
		ImGui::RadioButton("Infinite", &vulkanHandler.m_pcRaster.lightType, 1);

		ImGui::SliderFloat3("Position", &vulkanHandler.m_pcRaster.lightPosition.x, -20.f, 20.f);
		ImGui::SliderFloat("Intensity", &vulkanHandler.m_pcRaster.lightIntensity, 0.f, 150.f);
	}
}

inline static void drawOverlay(std::string& technique_codename, float& render_time)
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

	ImGui::SetNextWindowBgAlpha(0.5f); // Transparent background
	if (ImGui::Begin("Overlay", NULL, window_flags))
	{
		//Algoritmo
		ImGui::TextColored(yellow, "Tecnica: ");
		ImGui::SameLine();
		ImGui::TextColored(white, technique_codename.c_str());

		//Estadisticas
		ImGui::TextColored(yellow, "Stats: ");
		ImGui::SameLine();
		ImGui::TextColored(white, "%.0f FPS   %.3f ms", ImGui::GetIO().Framerate, 1000.0f / ImGui::GetIO().Framerate);

		//Tiempo de renderizado
		ImGui::TextColored(yellow, "Render time: ");
		ImGui::SameLine();
		ImGui::TextColored(white, "%.3f secs", render_time);

		//Tiempo de renderizado
		ImGui::TextColored(yellow, "Render status: ");
		ImGui::SameLine();
		if(paused)
			ImGui::TextColored(red, "paused");
		else
			ImGui::TextColored(green, "running");

		ImGui::NewLine();

		//Informaci�n
		ImGui::TextColored(white, "ESC: mostrar menu");
		//ImGui::SameLine(0.0, 15);
		ImGui::TextColored(white, "F1: ocultar interfaz");

		ImGui::TextColored(white, "R: reiniciar");
		//ImGui::SameLine(0.0, 15);
		ImGui::TextColored(white, "P: pausar");

		ImGui::TextColored(white, "Q: salir");
	}
	ImGui::End();
}

inline static void drawConfigWindow(TechniqueType& current_technique, std::chrono::steady_clock::time_point& pause_timer_start, float& time_limit, float& time_elapsed) {	
	ImGuiH::Panelv2::Begin(ImGuiH::Panel::Side::Right, 0.5, "Configuracion", ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_MenuBar | ImGuiWindowFlags_NoMove);

	if (ImGui::BeginMenuBar())
	{
		if (ImGui::BeginMenu("Archivo"))
		{
			//if (ImGui::MenuItem("Close", "Ctrl+W")) { *p_open = false; }
			ImGui::EndMenu();
		}
		ImGui::EndMenuBar();
	}

	// Content
	{
		ImGui::BeginGroup();
		ImGui::BeginChild("Tabs", ImVec2(0, -ImGui::GetFrameHeightWithSpacing())); // Leave room for 1 line below us
		if (ImGui::BeginTabBar("##Tabs", ImGuiTabBarFlags_None))
		{
			if (ImGui::BeginTabItem("Algoritmo"))
			{
				const char* items[] = { "Simple PathTracer", "ShadowRay PathTracer", "Bidirectional PathTracer", "Raster" };
				static int item_current_idx = 0; // Here we store our selection data as an index.

				// Pass in the preview value visible before opening the combo (it could technically be different contents or not pulled from items[])
				const char* combo_preview_value = items[item_current_idx];

				if (ImGui::BeginCombo("Algoritmo: ", combo_preview_value))
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
					if (current_technique != TechniqueType::RASTER)
						vulkanHandler.changeTechnique(current_technique);

					paused = false;
					pause_timer_start = std::chrono::high_resolution_clock::now();
					time_elapsed = 0;
				}

				if (!ImGui::InputFloat("Time to pause", &time_limit, 0.0f, 0.0f, "%.3f") && time_limit > 0.01f && time_elapsed > time_limit)
					paused = true;

				if (ImGui::Button("Pause"))
				{
					paused = !paused;

					if (!paused)
					{
						pause_timer_start = std::chrono::high_resolution_clock::now();
					}
				}
				ImGui::SameLine();
				if (ImGui::Button("Reset"))
				{
					vulkanHandler.resetFrame();
				}
					
				if (!paused) {
					auto now = std::chrono::high_resolution_clock::now();
					std::chrono::duration<float> elapsed = now - pause_timer_start;
					time_elapsed += elapsed.count();
					pause_timer_start = now;
				}

				ImGui::EndTabItem();
			}
			if (ImGui::BeginTabItem("Camara"))
			{
				ImGui::SliderFloat("Aperture", &vulkanHandler.m_pcRay.camAperture, 0.001f, 0.5f); //camera parameters
				ImGui::SliderFloat("Focus distance", &vulkanHandler.m_pcRay.focusDist, 0.1f, 20.f);

				ImGui::EndTabItem();
			}
			if (ImGui::BeginTabItem("Legacy"))
			{
				renderUI(vulkanHandler);

				ImGui::EndTabItem();
			}
			ImGui::EndTabBar();
		}
		ImGui::EndChild();
		ImGui::EndGroup();
	}

	//ImGui::Checkbox("Ambient Ligth", &vulkanHandler.m_pcRay.ambientLigth); //enable ambient ligth

	ImGuiH::Panel::End();
}


//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
static int const SAMPLE_WIDTH = 1280;
static int const SAMPLE_HEIGHT = 720;


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

	// Load Scene
	//const std::string scene_path = nvh::findFile("media/scenes/test.scn", defaultSearchPaths, true);

	//Escenas Walter
	//const std::string scene_path = nvh::findFile("media/scenes/RoughnessTests/PatronConductor.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/RoughnessTests/PatronDielectrico.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/RoughnessTests/WalterGlass.scn", defaultSearchPaths, true);

	//Bidirectional
	//const std::string scene_path = nvh::findFile("media/scenes/Bidirectional/veach_lamps.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/Bidirectional/veach_lamps_alt.scn", defaultSearchPaths, true);

	//otras
	//const std::string scene_path = nvh::findFile("media/scenes/cornellbox_original.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/cornellbox_sphere.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/cornellbox_sphere_antiguo.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/cornellbox_water.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/cornellbox_mirror.scn", defaultSearchPaths, true);
	//const std::string scene_path = nvh::findFile("media/scenes/cornellbox_bubble.scn", defaultSearchPaths, true);


	//Externas
	//const std::string scene_path = nvh::findFile("media/scenes/Externas/bedroom.scn", defaultSearchPaths, true);
	/*const std::string scene_path = nvh::findFile("media/scenes/Externas/spaceship.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/diningroom.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/staircase.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/test_veach.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/hyperion_distant_light.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/hyperion_rect_lights.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/tropical_island.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/hyperion_sphere_light.scn", defaultSearchPaths, true);
	const std::string scene_path = nvh::findFile("media/scenes/Externas/renderman_teapot_all.scn", defaultSearchPaths, true);*/
	
	SceneLoader::Scene scene(scene_path);

	// Setup camera
	glfwSetWindowSize(window, scene.resolution_x, scene.resolution_y);
	CameraManip.setLookat(scene.camera_position, scene.camera_lookat, glm::vec3(0, 1, 0));
	CameraManip.setFov(scene.camera_fov);

	vulkanHandler.loadScene(&scene, scene_path);

	// Creation of the example-----------------------------------------------------------------------------------------------------------------

	//TO-DO: borrar esto, dejar solo escenas en formato escena
	{  //Minecraft floor
		/*vulkanHandler.loadModel(nvh::findFile("media/scenes/CornellBox-Sphere.obj", defaultSearchPaths, true));
		vulkanHandler.loadModel(nvh::findFile("media/scenes/vokselia_spawn.obj", defaultSearchPaths, true),
						 glm::scale(glm::translate(glm::mat4(1.0f), vec3(0, 0.1, 0.1)), vec3(0.5)));*/
	}

	{  //cornell dragon
		/*vulkanHandler.loadModel(nvh::findFile("media/scenes/CornellBox-Empty-CO.obj", defaultSearchPaths, true));
		vulkanHandler.loadModel(nvh::findFile("media/scenes/dragon.obj", defaultSearchPaths, true),
						  glm::translate(
						  glm::rotate(
						  glm::scale(glm::mat4(1.0f), vec3(1.5,1.5,1.5)), (float)1.5, vec3(0, 1, 0)),vec3(0, 0.5, 0)));*/
	}

	//Lego
	{
		//vulkanHandler.loadModel(nvh::findFile("media/scenes/lego.obj", defaultSearchPaths, true));
	}

	{ //cornell bunny
		/*vulkanHandler.loadModel(nvh::findFile("media/scenes/CornellBox-Mirror.obj", defaultSearchPaths, true));
		vulkanHandler.loadModel(nvh::findFile("media/scenes/bunny.obj", defaultSearchPaths, true));*/
	}

	{  //cornell lucy
		/*vulkanHandler.loadModel(nvh::findFile("media/scenes/CornellBox-Empty-CO.obj", defaultSearchPaths, true));
	  vulkanHandler.loadModel(nvh::findFile("media/scenes/lucy.obj", defaultSearchPaths, true),
						glm::scale(glm::rotate(glm::mat4(1.0f), (float)1.5, vec3(0, 1, 0)), vec3(0.0023)));*/
	}

	//Sponza
	//vulkanHandler.loadModel(nvh::findFile("media/scenes/sponza.obj", defaultSearchPaths, true));

	//-----------------------------------------------------------------------------------------------------------------------------------------

	vulkanHandler.setupTechnique(TechniqueType::SHADOWRAY_PATHTRACER);
	vulkanHandler.setupTechnique(TechniqueType::SIMPLE_PATHTRACER); 
	vulkanHandler.setupTechnique(TechniqueType::BIDIRECTIONAL_PATHTRACER);

	TechniqueType current_technique = TechniqueType::BIDIRECTIONAL_PATHTRACER;
	vulkanHandler.changeTechnique(current_technique);

	vulkanHandler.uploadImplicitObjects();
	vulkanHandler.createOffscreenRender();
	vulkanHandler.createDescriptorSetLayout();
	vulkanHandler.createGraphicsPipeline();
	vulkanHandler.createUniformBuffer();
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


	glm::vec4 clearColor = glm::vec4(0, 0, 0, 1.00f);
	bool      useRaytracer = true;

	vulkanHandler.m_pcRay.camAperture = 0.f;
	vulkanHandler.m_pcRay.focusDist = 3.f;
	vulkanHandler.m_pcRay.shininess = 0.f;
	vulkanHandler.m_pcRay.fuzziness = 0.f;
	vulkanHandler.m_pcRay.light_count = vulkanHandler.m_lights.size();

	vulkanHandler.setupGlfwCallbacks(window);
	glfwSetKeyCallback(window, &key_cb);
	ImGui_ImplGlfw_InitForVulkan(window, true);

	time_t start = time(0);

	float time_elapsed = 0;
	float time_limit = 0;
	auto pause_timer_start = std::chrono::high_resolution_clock::now();

	// Main loop
	while (!glfwWindowShouldClose(window))
	{
		if (vulkanHandler.m_pcRay.frame <= 0) {
			paused = false;
			pause_timer_start = std::chrono::high_resolution_clock::now();
			time_elapsed = 0;
		}

		glfwPollEvents();
		if (vulkanHandler.isMinimized())
			continue;

		// Start the Dear ImGui frame
		ImGui_ImplGlfw_NewFrame();
		ImGui::NewFrame();

		// Show UI window.
		if (gui_visible) {
			drawOverlay(vulkanHandler.current_technique->formatted_name, time_elapsed);

			if (menu_visible) {
				drawConfigWindow(current_technique, pause_timer_start, time_limit, time_elapsed);
			}
		}

		// Start rendering the scene
		vulkanHandler.prepareFrame();

		// Start command buffer of this frame
		auto                   curFrame = vulkanHandler.getCurFrame();
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
			VkRenderPassBeginInfo offscreenRenderPassBeginInfo{ VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
			offscreenRenderPassBeginInfo.clearValueCount = 2;
			offscreenRenderPassBeginInfo.pClearValues = clearValues.data();
			offscreenRenderPassBeginInfo.renderPass = vulkanHandler.m_offscreenRenderPass;
			offscreenRenderPassBeginInfo.framebuffer = vulkanHandler.m_offscreenFramebuffer;
			offscreenRenderPassBeginInfo.renderArea = { {0, 0}, vulkanHandler.getSize() };

			// Rendering Scene (reuse last frame if program is paused)

			if (!paused)
			{
				if (current_technique != TechniqueType::RASTER)
				{
					vulkanHandler.raytrace(cmdBuf, clearColor);
				}
				else
				{
					vkCmdBeginRenderPass(cmdBuf, &offscreenRenderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);
					vulkanHandler.rasterize(cmdBuf);
					vkCmdEndRenderPass(cmdBuf);
				}
			}
			else {
				vulkanHandler.updateFrame();
			}
		}

		// 2nd rendering pass: tone mapper, UI
		{
			VkRenderPassBeginInfo postRenderPassBeginInfo{ VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO };
			postRenderPassBeginInfo.clearValueCount = 2;
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
