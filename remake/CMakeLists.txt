cmake_minimum_required(VERSION 3.20)

# Spidey Remake - PC (Windows x64) - M0 scaffold
# Standalone project: configure from remake/ with the vcpkg toolchain file.
project(spidey_remake LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT WIN32)
  message(WARNING "Primary target is Windows x64; other platforms are best-effort.")
endif()

# M0: zero-dependency stub. M1 adds: find_package(SDL3 CONFIG REQUIRED) etc.
add_executable(spidey_remake
  src/main.cpp
)

target_compile_definitions(spidey_remake PRIVATE
  SPIDEY_REMAKE=1
  SPIDEY_REMAKE_MILESTONE="M0"
)

if(MSVC)
  target_compile_options(spidey_remake PRIVATE /W4 /permissive-)
endif()

# Future milestones (uncomment as implemented):
# --- M1: window + D3D11 + ImGui ---
# find_package(SDL3 CONFIG REQUIRED)
# target_link_libraries(spidey_remake PRIVATE SDL3::SDL3 d3d11.lib dxgi.lib d3dcompiler.lib)
# --- M2: tools ---
# add_subdirectory(tools)
