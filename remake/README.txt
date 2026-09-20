SPIDEY REMAKE (PC / Windows x64 / 2010-era target)
==================================================
Non-commercial learning project. See ../REMAKE_PLAN.txt (full locked plan).

CURRENT MILESTONE: M0 (scaffold stub, zero dependencies)

DIRECTORY LAYOUT
  remake/CMakeLists.txt   Standalone CMake project (VS2022 x64 + vcpkg)
  remake/vcpkg.json       Dependency manifest (grows per milestone)
  remake/src/main.cpp     Entry point stub (M0: banner only, no deps)
  remake/core/            (M3) HAL interfaces + float math lib
  remake/render/          (M1/M4) D3D11 renderer + HLSL shaders
  remake/audio/           (M7) miniaudio backend
  remake/input/           (M1) SDL3 backend
  remake/tools/           (M2) pkr_dump, model_viewer, ...
  remake/work/            GIT-IGNORED scratch: game files + outputs. NEVER commit.

BUILD (Windows, Visual Studio 2022)
  1. Install VS2022 (Desktop C++), CMake 3.20+, vcpkg.
  2. cd remake
  3. cmake -B out -DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake
  4. cmake --build out --config Release
  5. out\Release\spidey_remake.exe

RULES
  - Never commit game assets or remake/work/ contents.
  - Never include old x86-only headers with hardcoded addresses.
  - Old matching-decomp build must keep working (CI green).
