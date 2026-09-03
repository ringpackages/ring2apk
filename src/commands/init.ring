# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    init command for Ring2APK
    Creates a new Ring Android project
*/

# Execute init command
func cmdInit aArgs
    cProjectName = "myapp"

    # Parse arguments
    for i = 1 to len(aArgs)
        cArg = aArgs[i]
        if left(cArg, 2) != "--"
            cProjectName = cArg
        ok
    next

    # Check for Ring language sources
    cRingRoot = sysGet("RING")
    if len(cRingRoot) = 0 or not dirExists(joinPath([cRingRoot, "language", "src"]))
        fail("RING environment variable not set or Ring sources not found." + nl +
             "Set RING to your Ring installation root (e.g. export RING=/opt/ring)")
    ok

    logInfo("Creating new Ring Android project: " + cProjectName)

    # Check if directory already exists
    if dirExists(cProjectName)
        fail("Directory already exists: " + cProjectName)
    ok

    # Create project structure
    createProjectStructure(cProjectName, cRingRoot)

    logSuccess("Project created successfully!")
    ? ""
    ? "Next steps:"
    ? "  cd " + cProjectName
    ? "  ring2apk build"

# Create the project directory structure
func createProjectStructure cName, cRingRoot
    logStep("1/6", "Creating directories...")

    mkDir(cName)
    mkDir(joinPath([cName, "assets"]))
    mkDir(joinPath([cName, "ring"]))
    mkDir(joinPath([cName, "res", "drawable"]))
    mkDir(joinPath([cName, "res", "mipmap-hdpi"]))
    mkDir(joinPath([cName, "res", "mipmap-mdpi"]))
    mkDir(joinPath([cName, "res", "mipmap-xhdpi"]))
    mkDir(joinPath([cName, "res", "mipmap-xxhdpi"]))
    mkDir(joinPath([cName, "res", "values"]))
    mkDir(joinPath([cName, "src", "java"]))
    mkDir(joinPath([cName, "src", "cpp"]))

    logStep("2/6", "Copying Ring VM sources...")
    copyRingSources(cRingRoot, joinPath([cName, "src", "cpp", "ring"]))

    logStep("3/6", "Creating configuration...")

    oConfig = Ring2ApkConfig
    oConfig[:name] = cName
    oConfig[:packageId] = "com.example." + lower(cName)
    oConfig[:label] = cName
    oConfig[:ringSrcDir] = "ring"
    saveConfig(joinPath([cName, "ring2apk.ring"]), oConfig)

    logStep("4/6", "Creating Ring source and native entry point...")
    createNativeTemplate(cName)
    createMainC(cName)
    createCMakeLists(cName)

    logStep("5/6", "Creating Android resources...")
    createAndroidResources(cName)

    logStep("6/6", "Creating documentation...")
    createProjectReadme(cName)
    createCppReadme(cName)

# Copy Ring VM sources (src/ and include/) from the Ring installation
func copyRingSources cRingRoot, cDestRing
    cLangSrc = joinPath([cRingRoot, "language", "src"])
    cLangInc = joinPath([cRingRoot, "language", "include"])

    if not dirExists(cLangSrc) or not dirExists(cLangInc)
        fail("Ring sources not found at " + joinPath([cRingRoot, "language"]))
    ok

    mkDir(joinPath([cDestRing, "src"]))
    mkDir(joinPath([cDestRing, "include"]))

    aFiles = dir(cLangSrc)
    for aFile in aFiles
        cFileName = aFile[1]
        if aFile[2] = 0 and cFileName != "ring.c" and cFileName != "ringw.c"
            copyFile(joinPath([cLangSrc, cFileName]), joinPath([cDestRing, "src", cFileName]))
        ok
    next

    copyDir(cLangInc, joinPath([cDestRing, "include"]))
    logBuild("Copied Ring VM sources from " + joinPath([cRingRoot, "language"]))

# Create the Ring source entry point (simple hello world)
func createNativeTemplate cName
    write(joinPath([cName, "ring", "main.ring"]), '? "Hello from Ring on Android!"' + nl)

# Create the native C entry point (main.c)
# Runs the embedded Ring bytecode via ringappcode_run()
func createMainC cName
    cMain = `/* ` + cName + ` - Ring Android Native Application */

#include <android_native_app_glue.h>
#include <android/log.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

#include "ring.h"
#include "ringappcode.h"

#define LOG_TAG "RingApp"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static int pfd[2];
static pthread_t thr;

static void *thread_func(void *arg) {
    (void)arg;
    ssize_t rdsz;
    char buf[256];
    while ((rdsz = read(pfd[0], buf, sizeof(buf) - 1)) > 0) {
        buf[rdsz] = 0;
        __android_log_write(ANDROID_LOG_DEBUG, "RingOutput", buf);
    }
    return NULL;
}

static void start_logger(void) {
    setvbuf(stdout, 0, _IOLBF, 0);
    setvbuf(stderr, 0, _IONBF, 0);
    pipe(pfd);
    dup2(pfd[1], 1);
    dup2(pfd[1], 2);
    pthread_create(&thr, 0, thread_func, 0);
}

void android_main(struct android_app *app) {
    (void)app;
    start_logger();
    LOGI("=== Ring App Starting ===");

    RingState *pState = ring_state_new();
    if (!pState) {
        LOGE("Failed to create Ring state");
        return;
    }
    pState->lRun = 1;
    ringappcode_run(pState);
    ring_state_delete(pState);
    LOGI("=== Ring App Finished ===");
}
`
    write(joinPath([cName, "src", "cpp", "main.c"]), cMain)

# Create CMakeLists.txt for the NDK build
func createCMakeLists cName
    cContent = `cmake_minimum_required(VERSION 3.22)
project(` + cName + ` C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Workaround for large file support on some Android ABIs
if((ANDROID_ABI STREQUAL "armeabi-v7a" OR ANDROID_ABI STREQUAL "x86") AND ANDROID_PLATFORM_LEVEL LESS 24)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -U_FILE_OFFSET_BITS")
endif()

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
# Main Application (Ring VM + embedded bytecode)
# ============================================================================
add_library(main SHARED
    main.c
    ${CMAKE_SOURCE_DIR}/../../build/gen/ringappcode.c
)

target_include_directories(main PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/../../build/gen
    ${RING_DIR}/include
    ${NATIVE_APP_GLUE_DIR}
)

target_link_libraries(main PRIVATE
    ring
    -Wl,--whole-archive
    native_app_glue
    -Wl,--no-whole-archive
    android
    log
)
`
    write(joinPath([cName, "src", "cpp", "CMakeLists.txt"]), cContent)

# Create Android resource files
func createAndroidResources cName
    # strings.xml
    cStrings = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">` + cName + `</string>
</resources>
`
    write(joinPath([cName, "res", "values", "strings.xml"]), cStrings)

    # colors.xml
    cColors = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="colorPrimary">#6200EE</color>
    <color name="colorPrimaryDark">#3700B3</color>
    <color name="colorAccent">#03DAC5</color>
</resources>
`
    write(joinPath([cName, "res", "values", "colors.xml"]), cColors)

    # styles.xml
    cStyles = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="@android:style/Theme.NoTitleBar.Fullscreen">
    </style>
</resources>
`
    write(joinPath([cName, "res", "values", "styles.xml"]), cStyles)

# Create the top-level project README
func createProjectReadme cName
    cReadme = "# " + cName + nl + nl +
        "A Ring Android application built with ring2apk." + nl + nl +
        "## Structure" + nl + nl +
        "    " + cName + "/" + nl +
        "    +-- ring2apk.ring       Build configuration" + nl +
        "    +-- ring/               Ring source code (compiled to bytecode at build time)" + nl +
        "    |   +-- main.ring       Entry point -- edit this!" + nl +
        "    +-- assets/             App assets (images, sounds, data files)" + nl +
        "    +-- res/                Android resources (icons, strings, themes)" + nl +
        "    +-- src/cpp/            Native C code + Ring VM sources" + nl +
        "        +-- main.c          Android entry point (runs Ring bytecode)" + nl +
        "        +-- CMakeLists.txt  NDK build script" + nl +
        "        +-- ring/           Ring VM source (src/ + include/)" + nl + nl +
        "## Build" + nl + nl +
        "    ring2apk build" + nl + nl +
        "Output: build/" + cName + "-debug.apk" + nl + nl +
        "### Release build" + nl + nl +
        "    ring2apk build --release" + nl + nl +
        "### Target specific ABIs" + nl + nl +
        "    ring2apk build --target=arm64-v8a" + nl + nl +
        "## Run on device" + nl + nl +
        "    ring2apk run" + nl + nl +
        "## How it works" + nl + nl +
        "ring2apk compiles ring/main.ring into bytecode embedded in build/gen/ringappcode.c," + nl +
        "then builds it with the Ring VM into libmain.so. The NativeActivity launches" + nl +
        "android_main in main.c, which creates a Ring VM and runs the embedded bytecode." + nl + nl +
        "Ring ? output goes to Android logcat (tag: RingOutput)." + nl + nl +
        "## Clean" + nl + nl +
        "    ring2apk clean" + nl + nl +
        "See ring2apk help for all commands and options." + nl
    write(joinPath([cName, "README.md"]), cReadme)

# Create the src/cpp README
func createCppReadme cName
    cReadme = "# Native sources for " + cName + nl + nl +
        "This directory is built by the NDK (CMake + Ninja) when you run ring2apk build." + nl + nl +
        "## Files" + nl + nl +
        "- main.c -- Android entry point. Defines android_main, creates a Ring VM" + nl +
        "  state, and runs the embedded bytecode via ringappcode_run()." + nl +
        "- CMakeLists.txt -- NDK build script. Builds the Ring VM (ring/) as a static" + nl +
        "  library, links it with main.c and the generated bytecode to produce libmain.so." + nl +
        "- ring/ -- Ring VM source code (src/*.c + include/*.h), copied from your" + nl +
        "  Ring installation at init time." + nl + nl +
        "Generated at build time (not committed):" + nl +
        "- build/gen/ringappcode.c / ringappcode.h -- Generated from ring/main.ring." + nl +
        "  Contains the hex-embedded Ring bytecode. Regenerated on every build." + nl + nl +
        "## Customizing" + nl + nl +
        "- Edit ../ring/main.ring to change your Ring app logic." + nl +
        "- The library name must match android.app.lib_name in the manifest (default: main)." + nl
    write(joinPath([cName, "src", "cpp", "README.md"]), cReadme)
