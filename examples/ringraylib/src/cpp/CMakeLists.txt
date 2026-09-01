cmake_minimum_required(VERSION 3.22)
project(ringraylib C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Workaround for large file support on some Android ABIs
if((ANDROID_ABI STREQUAL "armeabi-v7a" OR ANDROID_ABI STREQUAL "x86") AND ANDROID_PLATFORM_LEVEL LESS 24)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -U_FILE_OFFSET_BITS")
endif()

# ============================================================================
# Raylib (build from source)
# ============================================================================
set(RAYLIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/raylib")
set(RAYGUI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/raygui")
if(NOT EXISTS "${RAYLIB_DIR}/CMakeLists.txt" OR NOT EXISTS "${RAYGUI_DIR}/src/raygui.h")
    message(FATAL_ERROR "RayLib and RayGUI not found!")
endif()

# Raylib build options for Android
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_GAMES OFF CACHE BOOL "" FORCE)
set(PLATFORM "Android" CACHE STRING "" FORCE)
set(OPENGL_VERSION "ES 2.0" CACHE STRING "" FORCE)

add_subdirectory(${RAYLIB_DIR} raylib-build)

# ============================================================================
# Ring Language (build from source)
# ============================================================================
set(RING_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ring")
if(NOT EXISTS "${RING_DIR}/src")
    message(FATAL_ERROR "Ring sources not found! Expected at ${RING_DIR}/src")
endif()

file(GLOB RING_SOURCES ${RING_DIR}/src/*.c)

add_library(ring STATIC ${RING_SOURCES})
target_include_directories(ring PUBLIC "${RING_DIR}/include")
target_link_libraries(ring PUBLIC android log)

# ============================================================================
# Native App Glue (provides ANativeActivity_onCreate)
# ============================================================================
set(NATIVE_APP_GLUE_DIR "${ANDROID_NDK}/sources/android/native_app_glue")
add_library(native_app_glue STATIC
    ${NATIVE_APP_GLUE_DIR}/android_native_app_glue.c
)
target_include_directories(native_app_glue PUBLIC ${NATIVE_APP_GLUE_DIR})

# ============================================================================
# Ring Raylib Extension + Main Application
# ============================================================================
add_library(main SHARED
    main.c
    ${CMAKE_SOURCE_DIR}/../../build/gen/ringappcode.c
    ring_raylib.c
)

target_include_directories(main PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/../../build/gen
    ${RING_DIR}/include
    ${RAYLIB_DIR}/src
    ${RAYGUI_DIR}/src
    ${NATIVE_APP_GLUE_DIR}
)

target_link_libraries(main PRIVATE
    ring
    raylib
    -Wl,--whole-archive
    native_app_glue
    -Wl,--no-whole-archive
    android
    log
    EGL
    GLESv2
    OpenSLES
)
