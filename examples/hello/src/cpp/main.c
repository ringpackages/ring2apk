/* hello - Ring Android Native Application */

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
