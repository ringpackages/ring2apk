# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    Ring2APK core - loads, globals, dispatch.
*/

# Load the Ring Standard Library
load "stdlibcore.ring"

# Load shared utilities
load "utils/colors.ring"
load "utils/shell.ring"
load "utils/shared.ring"

# Load the Ring2APK modules
load "config.ring"
load "environment.ring"

# Load the Ring2APK commands
load "commands/init.ring"
load "commands/build.ring"
load "commands/run.ring"
load "commands/sign.ring"
load "commands/clean.ring"

# Ring2APK version
$RING2APK_VERSION = "1.0.0"

# Ring2APK verbose flag
$RING2APK_VERBOSE = false

func main
    args = AppArguments()
    nMax = len(args)
    command = ""
    cmdArgs = []
    for i = 1 to nMax
        if args[i] = "--verbose"
            setVerbose(true)
        ok
        if i = 1
            command = lower(args[i])
        else
            cmdArgs + args[i]
        ok
    next

    if nMax = 0
        showHelp()
        return
    ok

    switch command
    on "init"
        cmdInit(cmdArgs)
    on "build"
        cmdBuild(cmdArgs)
    on "run"
        cmdRun(cmdArgs)
    on "sign"
        cmdSign(cmdArgs)
    on "clean"
        cmdClean(cmdArgs)
    on "create-keystore"
        cmdCreateKeystore(cmdArgs)
    on "help"
        showHelp()
    on "--help"
        showHelp()
    on "-h"
        showHelp()
    on "version"
        showVersion()
    on "--version"
        showVersion()
    on "-v"
        showVersion()
    other
        fail("Unknown command: " + command + " — try 'ring2apk help'")
    off

func showHelp
    ? COLOR_BOLD + "Ring2APK" + COLOR_RESET + " - Build Android APKs from Ring applications"
    ? ""
    ? FG_CYAN + "USAGE:" + COLOR_RESET
    ? "    ring2apk <COMMAND> [OPTIONS]"
    ? ""
    ? FG_CYAN + "COMMANDS:" + COLOR_RESET
    ? "    " + FG_GREEN + "init" + COLOR_RESET + "            Create a new Ring Android project"
    ? "    " + FG_GREEN + "build" + COLOR_RESET + "           Build the APK"
    ? "    " + FG_GREEN + "run" + COLOR_RESET + "             Build, install, and run on device"
    ? "    " + FG_GREEN + "sign" + COLOR_RESET + "            Sign the APK for release"
    ? "    " + FG_GREEN + "clean" + COLOR_RESET + "           Remove build artifacts"
    ? "    " + FG_GREEN + "create-keystore" + COLOR_RESET + " Create a release keystore"
    ? "    " + FG_GREEN + "help" + COLOR_RESET + "            Show this help message"
    ? "    " + FG_GREEN + "version" + COLOR_RESET + "         Show version information"
    ? ""
    ? FG_CYAN + "OPTIONS:" + COLOR_RESET
    ? "    --release           Build release APK (default: debug)"
    ? "    --rebuild           Force a full rebuild (default: reuse existing APK)"
    ? "    --target=<ABI>      Target ABI(s): arm64-v8a,armeabi-v7a,x86,x86_64"
    ? "    --device=<SERIAL>   Target device serial number"
    ? "    --verbose           Print every shell command before running it"
    ? ""
    ? FG_CYAN + "EXAMPLES:" + COLOR_RESET
    ? "    ring2apk init mygame"
    ? "    ring2apk build --release --target=arm64-v8a"
    ? "    ring2apk run"

func showVersion
    ? "Ring2APK " + $RING2APK_VERSION
