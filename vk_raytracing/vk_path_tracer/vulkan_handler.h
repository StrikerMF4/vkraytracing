#pragma once

#include "nvvkhl/appbase_vk.hpp"
#include "nvvk/debug_util_vk.hpp"
#include "nvvk/descriptorsets_vk.hpp"
#include "nvvk/memallocator_dma_vk.hpp"
#include "nvvk/resourceallocator_vk.hpp"
#include "shaders/host_device.h"

// #VKRay
#include "nvvk/raytraceKHR_vk.hpp"
#include <scene_loader.h>

enum TechniqueType
{
	SIMPLE_PATHTRACER = 0,
	SHADOWRAY_PATHTRACER = 1,
	BIDIRECTIONAL_PATHTRACER = 2,
    RASTER = 3
};

class Technique
{
    std::vector<VkRayTracingShaderGroupCreateInfoKHR> m_rtShaderGroups;
    VkPipelineLayout                                  m_rtPipelineLayout;
    VkPipeline                                        m_rtPipeline;

    nvvk::Buffer                    m_rtSBTBuffer;

    VkStridedDeviceAddressRegionKHR m_rgenRegion{};
    VkStridedDeviceAddressRegionKHR m_missRegion{};
    VkStridedDeviceAddressRegionKHR m_hitRegion{};
    VkStridedDeviceAddressRegionKHR m_callRegion{};

public:
    std::string codename;
    std::string formatted_name;
	int default_depth;

	Technique() = default;

    Technique(std::string codename, std::string formatted_name, int default_depth) {
        this->codename = codename;
		this->formatted_name = formatted_name;
		this->default_depth = default_depth;
    };

    void createRtPipeline(VkDevice* m_device, VkDescriptorSetLayout* m_rtDescSetLayout, VkDescriptorSetLayout* m_descSetLayout);

    void createRtShaderBindingTable(VkDevice* m_device, nvvk::ResourceAllocatorDma* m_alloc, nvvk::DebugUtil* m_debug, VkPhysicalDeviceRayTracingPipelinePropertiesKHR* m_rtProperties);

	void raytrace(const VkCommandBuffer& cmdBuf, PushConstantRayTracer* m_pcRay, std::vector<VkDescriptorSet>* descSets, VkExtent2D* m_size);

    void destroyResources(VkDevice* m_device, nvvk::ResourceAllocatorDma* m_alloc);
};

//--------------------------------------------------------------------------------------------------
// Simple rasterizer of OBJ objects
// - Each OBJ loaded are stored in an `ObjModel` and referenced by a `ObjInstance`
// - It is possible to have many `ObjInstance` referencing the same `ObjModel`
// - Rendering is done in an offscreen framebuffer
// - The image of the framebuffer is displayed in post-process in a full-screen quad
//
class VulkanHandler : public nvvkhl::AppBaseVk
{
public:
  void setup(const VkInstance& instance, const VkDevice& device, const VkPhysicalDevice& physicalDevice, uint32_t queueFamily) override;
  void createDescriptorSetLayout();
  void createGraphicsPipeline();
  void loadModel(const std::string& filename, glm::mat4 transform = glm::mat4(1));
  void loadScene(SceneLoader::Scene* scene, std::string scene_path);
  void uploadImplicitObjects();
  void updateDescriptorSet();
  void createUniformBuffer();
  void createObjDescriptionBuffer();
  void createLightBuffer();
  void createTextureImages(const VkCommandBuffer& cmdBuf, const std::vector<std::string>& textures, const std::string base_dir = "media/textures/");
  void updateUniformBuffer(const VkCommandBuffer& cmdBuf);
  void onResize(int /*w*/, int /*h*/) override;
  void destroyResources();
  void rasterize(const VkCommandBuffer& cmdBuff);

  // The OBJ model
  struct ObjModel
  {
    uint32_t     nbIndices{0};
    uint32_t     nbVertices{0};
    nvvk::Buffer vertexBuffer;    // Device buffer of all 'Vertex'
    nvvk::Buffer indexBuffer;     // Device buffer of the indices forming triangles
    nvvk::Buffer matColorBuffer;  // Device buffer of array of 'Wavefront material'
    nvvk::Buffer matIndexBuffer;  // Device buffer of array of 'Wavefront material'
    nvvk::Buffer LightIndexBuffer;  // Device buffer of array of 'Wavefront material'
  };

  struct ObjInstance
  {
    glm::mat4 transform;    // Matrix of the instance
    uint32_t  objIndex{0};  // Model index reference
  };

  PushConstantPost m_pcPost{};

  // Information pushed at each draw call
  PushConstantRaster m_pcRaster{
      {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},  // Identity matrix
      {0.f, 0.9f, 0.f},                                 // light position
      0,                                                 // instance Id
      1.f,                                             // light intensity
      0                                                  // light type
  };

  // Array of objects and instances in the scene
  std::vector<ObjModel>    m_objModel;   // Model on host
  std::vector<nvvk::Buffer> m_scene_buffers;
  std::vector<ObjDesc>     m_objDesc;    // Model description for device access
  std::vector<ObjInstance> m_instances;  // Scene model instances
  std::vector<Light>    m_lights;     // Lights in the scene
  std::vector<ImplicitObj> m_implicitObj; //Implicits objects in the scene
  
  //implicit objects arrays/buffers
  std::vector<unsigned int> m_implicitObj_materials_idx;
  std::vector<unsigned int> m_implicitObj_light_idx;
  std::vector<objl::Material> m_implicitObj_materials;
  std::vector<Sphere> m_spheres;
  nvvk::Buffer m_implicitObjBuffer;
  nvvk::Buffer m_implicitObj_AABBBuffer;
  nvvk::Buffer m_implicitObj_MatBuffer;
  nvvk::Buffer m_implicitObj_MatIndexBuffer;
  nvvk::Buffer m_implicitObj_LightIndexBuffer;
  nvvk::Buffer m_spheresBuffer;

  // Graphic pipeline
  VkPipelineLayout            m_pipelineLayout;
  VkPipeline                  m_graphicsPipeline;
  nvvk::DescriptorSetBindings m_descSetLayoutBind;
  VkDescriptorPool            m_descPool;
  VkDescriptorSetLayout       m_descSetLayout;
  VkDescriptorSet             m_descSet;

  nvvk::Buffer m_bGlobals;  // Device-Host of the camera matrices
  nvvk::Buffer m_bObjDesc;  // Device buffer of the OBJ descriptions
  nvvk::Buffer m_bLights;  // Device buffer of the lights descriptions

  std::vector<nvvk::Texture> m_textures;  // vector of all textures of the scene


  nvvk::ResourceAllocatorDma m_alloc;  // Allocator for buffer, images, acceleration structures
  nvvk::DebugUtil            m_debug;  // Utility to name objects


  // #Post - Draw the rendered image on a quad using a tonemapper
  void createOffscreenRender();
  void createPostPipeline();
  void createPostDescriptor();
  void updatePostDescriptorSet();
  void drawPost(VkCommandBuffer cmdBuf);

  nvvk::DescriptorSetBindings m_postDescSetLayoutBind;
  VkDescriptorPool            m_postDescPool{VK_NULL_HANDLE};
  VkDescriptorSetLayout       m_postDescSetLayout{VK_NULL_HANDLE};
  VkDescriptorSet             m_postDescSet{VK_NULL_HANDLE};
  VkPipeline                  m_postPipeline{VK_NULL_HANDLE};
  VkPipelineLayout            m_postPipelineLayout{VK_NULL_HANDLE};
  VkRenderPass                m_offscreenRenderPass{VK_NULL_HANDLE};
  VkFramebuffer               m_offscreenFramebuffer{VK_NULL_HANDLE};
  nvvk::Texture               m_offscreenColor;
  nvvk::Texture               m_offscreenAuxColor;
  nvvk::Texture               m_offscreenDepth;
  VkFormat                    m_offscreenColorFormat{ VK_FORMAT_R16G16B16A16_SFLOAT }; //To-Do: ver si al cambiar a 16 bits es mas eficiente, al menos en memoria lo sería
  VkFormat                    m_offscreenAuxColorFormat{ VK_FORMAT_R32_SFLOAT };
  VkFormat                    m_offscreenDepthFormat{VK_FORMAT_X8_D24_UNORM_PACK32};

  // #VKRay
  void initRayTracing();
  auto objectToVkGeometryKHR(const ObjModel& model);
  auto implicitObjToVkGeometryKHR();
  void createBottomLevelAS();
  void createTopLevelAS();
  void createRtDescriptorSet();
  void updateRtDescriptorSet();
  void createRtPipeline();
  void createRtShaderBindingTable();
  void raytrace(const VkCommandBuffer& cmdBuf, const glm::vec4& clearColor);
  void resetFrame();
  void updateFrame();

  void onKeyboard(int key, int /*scancode*/, int action, int mods);


  VkPhysicalDeviceRayTracingPipelinePropertiesKHR m_rtProperties{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR};
  nvvk::RaytracingBuilderKHR                        m_rtBuilder;
  nvvk::DescriptorSetBindings                       m_rtDescSetLayoutBind;
  VkDescriptorPool                                  m_rtDescPool;
  VkDescriptorSetLayout                             m_rtDescSetLayout;
  VkDescriptorSet                                   m_rtDescSet;

  // Push constant for ray tracer
  PushConstantRayTracer m_pcRay{};

  // Techniques
  std::unordered_map<TechniqueType, Technique*> m_techniques;
  Technique* current_technique;

  void setupTechnique(TechniqueType type) {
      switch (type) {
	  case SHADOWRAY_PATHTRACER:
          m_techniques[SHADOWRAY_PATHTRACER] = new Technique("shadowray_pathtracer", "Shadowray Pathtracer", 10);
		  break;
	  case SIMPLE_PATHTRACER:
		  m_techniques[SIMPLE_PATHTRACER] = new Technique("simple_pathtracer", "Simple Pathtracer", 10);
		  break;
	  case BIDIRECTIONAL_PATHTRACER:
		  m_techniques[BIDIRECTIONAL_PATHTRACER] = new Technique("bidirectional_pathtracer", "Bidirectional Pathtracer", 4);
		  break;
      }
  }

  void changeTechnique(TechniqueType type) {
      current_technique = m_techniques[type];

      m_pcPost.bidirectional_correction = type == BIDIRECTIONAL_PATHTRACER;

      resetFrame();
  }


};
