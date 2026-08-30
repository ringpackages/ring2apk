# hello

A Ring Android application built with ring2apk.

## Structure

    hello/
    +-- ring2apk.ring       Build configuration
    +-- ring/               Ring source code (compiled to bytecode at build time)
    |   +-- main.ring       Entry point -- edit this!
    +-- assets/             App assets (images, sounds, data files)
    +-- res/                Android resources (icons, strings, themes)
    +-- src/cpp/            Native C code + Ring VM sources
        +-- main.c          Android entry point (runs Ring bytecode)
        +-- CMakeLists.txt  NDK build script
        +-- ring/           Ring VM source (src/ + include/)

## Build

    ring2apk build

Output: build/hello-debug.apk

### Release build

    ring2apk build --release

### Target specific ABIs

    ring2apk build --target=arm64-v8a

## Run on device

    ring2apk run

## How it works

ring2apk compiles ring/main.ring into bytecode embedded in build/gen/ringappcode.c,
then builds it with the Ring VM into libmain.so. The NativeActivity launches
android_main in main.c, which creates a Ring VM and runs the embedded bytecode.

Ring ? output goes to Android logcat (tag: RingOutput).

## Clean

    ring2apk clean

See ring2apk help for all commands and options.
