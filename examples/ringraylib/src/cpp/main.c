/*
    Ring Raylib for Android - Main Entry Point
*/

#include <android/asset_manager.h>
#include <android/log.h>
#include <android_native_app_glue.h>
#include <jni.h>
#include <raylib.h>

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "ring.h"
#include "ringappcode.h"

extern struct android_app *GetAndroidApp(void);
extern void ringlib_init(RingState *pRingState);

#define LOG_TAG "RingRaylib"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)


static int pfd[2];
static pthread_t thr;

static void *thread_func(void *arg) {
    (void)arg;
    char buf[256];
    ssize_t rdsz;
    while ((rdsz = read(pfd[0], buf, sizeof(buf) - 1)) > 0) {
        buf[rdsz] = 0;
        __android_log_write(ANDROID_LOG_DEBUG, "RingOutput", buf);
    }
    return NULL;
}

void ring_vm_extension(RingState *pRingState) {
#if RING_VM_LISTFUNCS
    ring_vm_list_loadfunctions(pRingState);
#endif
#if RING_VM_MATH
    ring_vm_math_loadfunctions(pRingState);
#endif
#if RING_VM_FILE
    ring_vm_file_loadfunctions(pRingState);
#endif
#if RING_VM_OS
    ring_vm_os_loadfunctions(pRingState);
#endif
#if RING_VM_DLL
    ring_vm_dll_loadfunctions(pRingState);
#endif
#if RING_VM_REFMETA
    ring_vm_refmeta_loadfunctions(pRingState);
#endif
#if RING_VM_INFO
    ring_vm_info_loadfunctions(pRingState);
#endif
    ringlib_init(pRingState);
}

static void start_logger(void) {
    setvbuf(stdout, 0, _IOLBF, 0);
    setvbuf(stderr, 0, _IONBF, 0);
    pipe(pfd);
    dup2(pfd[1], 1);
    dup2(pfd[1], 2);
    pthread_create(&thr, 0, thread_func, 0);
}

static char *read_asset(AAssetManager *mgr, const char *filename,
                        size_t *out_size) {
    AAsset *asset = AAssetManager_open(mgr, filename, AASSET_MODE_BUFFER);
    if (!asset) {
        LOGE("Cannot open asset: %s", filename);
        return NULL;
    }

    off_t length = AAsset_getLength(asset);
    char *content = (char *)malloc(length + 1);
    if (!content) {
        AAsset_close(asset);
        return NULL;
    }

    AAsset_read(asset, content, length);
    content[length] = '\0';
    AAsset_close(asset);

    if (out_size)
        *out_size = length;
    return content;
}

static const char *get_internal_path(void) {
    struct android_app *app = GetAndroidApp();
    if (app && app->activity && app->activity->internalDataPath) {
        return app->activity->internalDataPath;
    }
    return "/data/local/tmp";
}

static AAssetManager *get_asset_manager(void) {
    struct android_app *app = GetAndroidApp();
    if (app && app->activity) {
        return app->activity->assetManager;
    }
    return NULL;
}

static int write_file(const char *path, const char *data, size_t size) {
    FILE *out = fopen(path, "wb");
    if (!out) {
        LOGE("Cannot write to: %s", path);
        return 0;
    }
    fwrite(data, 1, size, out);
    fclose(out);
    return 1;
}

static int extract_asset(AAssetManager *mgr, const char *assetPath,
                         const char *destPath) {
    size_t size;
    char *content = read_asset(mgr, assetPath, &size);
    if (!content)
        return 0;
    int ok = write_file(destPath, content, size);
    free(content);
    if (ok)
        LOGI("Extracted: %s -> %s", assetPath, destPath);
    return ok;
}

static void extract_dir(AAssetManager *mgr, const char *assetDir,
                        const char *destDir) {
    AAssetDir *dir = AAssetManager_openDir(mgr, assetDir);
    if (!dir)
        return;

    const char *filename;
    while ((filename = AAssetDir_getNextFileName(dir)) != NULL) {
        char assetPath[512];
        char destPath[512];

        if (assetDir[0])
            snprintf(assetPath, sizeof(assetPath), "%s/%s", assetDir, filename);
        else
            snprintf(assetPath, sizeof(assetPath), "%s", filename);
        snprintf(destPath, sizeof(destPath), "%s/%s", destDir, filename);

        // Try as file first; if it fails, treat as directory and recurse
        AAsset *asset = AAssetManager_open(mgr, assetPath, AASSET_MODE_STREAMING);
        if (asset) {
            AAsset_close(asset);
            extract_asset(mgr, assetPath, destPath);
        } else {
            mkdir(destPath, 0755);
            extract_dir(mgr, assetPath, destPath);
        }
    }
    AAssetDir_close(dir);
}

static void extract_assets(void) {
    AAssetManager *mgr = get_asset_manager();
    if (!mgr) {
        LOGE("Cannot get asset manager");
        return;
    }
    extract_dir(mgr, "", get_internal_path());
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;

    LOGI("=== Ring Raylib Starting ===");
    start_logger();
    extract_assets();

    const char *basePath = get_internal_path();
    chdir(basePath);
    LOGI("Working directory: %s", basePath);

    RingState *pState = ring_state_new();
    if (!pState) {
        LOGE("Failed to create Ring state");
        return 1;
    }

    pState->lRun = 1;
    LOGI("Running embedded Ring bytecode...");
    ringappcode_run(pState);

    if (pState->pVM)
        LOGI("Ring VM exists, script executed");
    else
        LOGE("Ring VM is NULL - bytecode error!");

    ring_state_delete(pState);
    LOGI("=== Ring Raylib Finished ===");
    return 0;
}
