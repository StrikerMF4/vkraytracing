#*****************************************************************************
# Copyright 2020 NVIDIA Corporation. All rights reserved.
#*****************************************************************************

cmake_minimum_required(VERSION 3.9.6 FATAL_ERROR)

#--------------------------------------------------------------------------------------------------
# Project setting
get_filename_component(PROJNAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
set(PROJNAME ${PROJNAME})
project(${PROJNAME} LANGUAGES C CXX)
message(STATUS "-------------------------------")
message(STATUS "Processing Project ${PROJNAME}:")


#--------------------------------------------------------------------------------------------------
# C++ target and defines
set(CMAKE_CXX_STANDARD 17)
add_executable(${PROJNAME})
_add_project_definitions(${PROJNAME})


#--------------------------------------------------------------------------------------------------
# Source files for this project
#
file(GLOB SOURCE_FILES *.cpp *.hpp *.inl *.h *.c)
file(GLOB EXTRA_COMMON ${TUTO_KHR_DIR}/common/*.*)
list(APPEND COMMON_SOURCE_FILES ${EXTRA_COMMON})
include_directories(${TUTO_KHR_DIR}/common)


#--------------------------------------------------------------------------------------------------
# Delete outdated .spv files if the source GLSL files change
#
set(SPV_OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/spv")

# Get all GLSL source files
file(GLOB GLSL_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.frag" 
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.vert"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.comp"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.geom"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.tesc"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.tese"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.rgen"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.rmiss"
                        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/*.rhit")

# Check if SPV output directory exists
if(EXISTS ${SPV_OUTPUT_DIR})
    file(GLOB SPV_FILES "${SPV_OUTPUT_DIR}/*.spv")
    list(LENGTH SPV_FILES SPV_COUNT)

    if(SPV_COUNT GREATER 0)
        add_custom_command(
            TARGET ${PROJNAME} PRE_BUILD
            COMMAND ${CMAKE_COMMAND} -E rm -f ${SPV_FILES}
            COMMENT "Deleting outdated .spv files"
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            DEPENDS ${GLSL_SOURCES}  # Only delete if GLSL files change
        )
    endif()
endif()

#--------------------------------------------------------------------------------------------------
# GLSL to SPIR-V custom build
compile_glsl_directory(
	SRC "${CMAKE_CURRENT_SOURCE_DIR}/shaders" 
	DST "${CMAKE_CURRENT_SOURCE_DIR}/spv" 
	VULKAN_TARGET "vulkan1.2"
	DEPENDENCY ${VULKAN_BUILD_DEPENDENCIES}
	)


#--------------------------------------------------------------------------------------------------
# Sources
target_sources(${PROJNAME} PUBLIC ${SOURCE_FILES} ${HEADER_FILES})
target_sources(${PROJNAME} PUBLIC ${COMMON_SOURCE_FILES})
target_sources(${PROJNAME} PUBLIC ${PACKAGE_SOURCE_FILES})
target_sources(${PROJNAME} PUBLIC ${GLSL_SOURCES} ${GLSL_HEADERS})


#--------------------------------------------------------------------------------------------------
# Sub-folders in Visual Studio
#
source_group("Common"       FILES ${COMMON_SOURCE_FILES} ${PACKAGE_SOURCE_FILES})
source_group("Sources"      FILES ${SOURCE_FILES})
source_group("Headers"      FILES ${HEADER_FILES})
source_group("Shader Sources"  FILES ${GLSL_SOURCES})
source_group("Shader Headers"  FILES ${GLSL_HEADERS})


#--------------------------------------------------------------------------------------------------
# Linkage
#
target_link_libraries(${PROJNAME} ${PLATFORM_LIBRARIES} nvpro_core)

foreach(DEBUGLIB ${LIBRARIES_DEBUG})
  target_link_libraries(${PROJNAME} debug ${DEBUGLIB})
endforeach(DEBUGLIB)

foreach(RELEASELIB ${LIBRARIES_OPTIMIZED})
  target_link_libraries(${PROJNAME} optimized ${RELEASELIB})
endforeach(RELEASELIB)

#--------------------------------------------------------------------------------------------------
# copies binaries that need to be put next to the exe files (ZLib, etc.)
#
_finalize_target( ${PROJNAME} )


install(FILES ${SPV_OUTPUT} CONFIGURATIONS Release DESTINATION "bin_${ARCH}/${PROJNAME}/spv")
install(FILES ${SPV_OUTPUT} CONFIGURATIONS Debug DESTINATION "bin_${ARCH}_debug/${PROJNAME}/spv")
