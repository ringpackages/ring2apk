# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    Environment detection and setup for Ring2APK
    Detects Android SDK, NDK, Java, and build tools
*/

# Detect Android SDK location
func detectAndroidSdk
    # Check environment variable first
    cSdk = sysGet("ANDROID_SDK_ROOT")
    if len(cSdk) > 0 and dirExists(cSdk)
        return cSdk
    ok

    cSdk = sysGet("ANDROID_HOME")
    if len(cSdk) > 0 and dirExists(cSdk)
        return cSdk
    ok

    # Check common locations
    aLocations = []

    if isWindows()
        cUser = sysGet("USERPROFILE")
        aLocations = [
            cUser + "\AppData\Local\Android\Sdk",
            cUser + "\Android\Sdk",
            "C:\Android\Sdk",
            cUser + "\android-sdk"
        ]
    else
        cHome = sysGet("HOME")
        aLocations = [
            cHome + "/Android/Sdk",
            cHome + "/android-sdk",
            "/opt/android-sdk",
            "/usr/local/android-sdk",
            cHome + "/Library/Android/sdk"
        ]
    ok

    for cPath in aLocations
        if dirExists(cPath)
            return cPath
        ok
    next

    return ""

# Detect Android NDK location
func detectAndroidNdk cSdkPath
    # Check environment variable first
    cNdk = sysGet("ANDROID_NDK_ROOT")
    if len(cNdk) > 0 and dirExists(cNdk)
        return cNdk
    ok

    cNdk = sysGet("NDK_HOME")
    if len(cNdk) > 0 and dirExists(cNdk)
        return cNdk
    ok

    # Check within SDK
    if len(cSdkPath) > 0
        cNdkDir = cSdkPath + pathSeparator() + "ndk"
        if dirExists(cNdkDir)
            # Find latest NDK version
            aFiles = dir(cNdkDir)
            cLatest = ""
            for aFile in aFiles
                if aFile[2] = 1  # Is directory
                    if compareVersions(aFile[1], cLatest) > 0
                        cLatest = aFile[1]
                    ok
                ok
            next
            if len(cLatest) > 0
                return cNdkDir + pathSeparator() + cLatest
            ok
        ok
    ok

    return ""

# Detect Java/JDK location
func detectJavaHome
    cJava = sysGet("JAVA_HOME")
    if len(cJava) > 0 and dirExists(cJava)
        return cJava
    ok

    # Check common locations
    aLocations = []

    if isWindows()
        aLocations = [
            "C:\Program Files\Java\jdk-17",
            "C:\Program Files\Java\jdk-21",
            "C:\Program Files\Zulu\zulu-17",
            "C:\Program Files\Zulu\zulu-21",
            sysGet("USERPROFILE") + "\open-jdk"
        ]
    else
        cHome = sysGet("HOME")
        aLocations = [
            cHome + "/open-jdk",
            "/usr/lib/jvm/java-17-openjdk",
            "/usr/lib/jvm/java-21-openjdk",
            "/usr/lib/jvm/default-java",
            "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home",
            "/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home"
        ]
    ok

    for cPath in aLocations
        if dirExists(cPath)
            return cPath
        ok
    next

    return ""

# Find build tools path
func findBuildTools cSdkPath
    cBuildToolsDir = cSdkPath + pathSeparator() + "build-tools"
    if not dirExists(cBuildToolsDir)
        return ""
    ok

    # Find latest version (numeric component comparison)
    aFiles = dir(cBuildToolsDir)
    cLatest = ""
    for aFile in aFiles
        if aFile[2] = 1  # Is directory
            if compareVersions(aFile[1], cLatest) > 0
                cLatest = aFile[1]
            ok
        ok
    next

    if len(cLatest) > 0
        return cBuildToolsDir + pathSeparator() + cLatest
    ok

    return ""

# Compare dotted version strings numerically ("35.0.1" > "30.0.3")
func compareVersions cV1, cV2
    if len(cV2) = 0
        return 1
    ok

    a1 = split(cV1, ".")
    a2 = split(cV2, ".")
    nMax = len(a1)
    if len(a2) > nMax
        nMax = len(a2)
    ok

    for i = 1 to nMax
        n1 = 0
        n2 = 0
        if i <= len(a1)
            n1 = number(a1[i])
        ok
        if i <= len(a2)
            n2 = number(a2[i])
        ok
        if n1 > n2
            return 1
        but n1 < n2
            return -1
        ok
    next

    return 0

# Find platform path
func findPlatform cSdkPath, nApiLevel
    cPlatformsDir = cSdkPath + pathSeparator() + "platforms"
    cPlatformPath = cPlatformsDir + pathSeparator() + "android-" + nApiLevel

    if dirExists(cPlatformPath)
        return cPlatformPath
    ok

    return ""

# Get path to a build tool
func getBuildTool cSdkPath, cToolName
    cBuildTools = findBuildTools(cSdkPath)
    if len(cBuildTools) = 0
        return ""
    ok

    cExt = ""
    if isWindows()
        cExt = ".exe"
    ok

    cToolPath = cBuildTools + pathSeparator() + cToolName + cExt
    if fExists(cToolPath)
        return cToolPath
    ok

    # Some tools might be .bat on Windows
    if isWindows()
        cToolPath = cBuildTools + pathSeparator() + cToolName + ".bat"
        if fExists(cToolPath)
            return cToolPath
        ok
    ok

    return ""

# Get path to platform tools
func getPlatformTool cSdkPath, cToolName
    cPlatformTools = cSdkPath + pathSeparator() + "platform-tools"

    cExt = ""
    if isWindows()
        cExt = ".exe"
    ok

    cToolPath = cPlatformTools + pathSeparator() + cToolName + cExt
    if fExists(cToolPath)
        return cToolPath
    ok

    return ""

# Get CMake from SDK
func getCMake cSdkPath
    cCMakeDir = cSdkPath + pathSeparator() + "cmake"
    if not dirExists(cCMakeDir)
        return ""
    ok

    # Find latest version
    aFiles = dir(cCMakeDir)
    cLatest = ""
    for aFile in aFiles
        if aFile[2] = 1
            if compareVersions(aFile[1], cLatest) > 0
                cLatest = aFile[1]
            ok
        ok
    next

    if len(cLatest) > 0
        cExt = ""
        if isWindows()
            cExt = ".exe"
        ok
        cCMakePath = cCMakeDir + pathSeparator() + cLatest + pathSeparator() + "bin" + pathSeparator() + "cmake" + cExt
        if fExists(cCMakePath)
            return cCMakePath
        ok
    ok

    # Fallback to system cmake
    if commandExists("cmake")
        return "cmake"
    ok

    return ""

# Detect the Ring Compiler/VM binary (used to embed bytecode via ring -go -norun)
func detectRingBinary
    cExt = ""
    if isWindows()
        cExt = ".exe"
    ok

    # RING environment variable points at the Ring install root
    cRingRoot = sysGet("RING")
    if len(cRingRoot) > 0
        cBin = cRingRoot + pathSeparator() + "bin" + pathSeparator() + "ring" + cExt
        if fExists(cBin)
            return cBin
        ok
    ok

    # Fall back to PATH
    if commandExists("ring")
        return "ring"
    ok

    return ""

# Validate environment and return Environment object
func detectEnvironment
    oEnv = new Environment

    # Detect SDK
    oEnv.sdkPath = detectAndroidSdk()
    if len(oEnv.sdkPath) > 0
        oEnv.hasSdk = true

        # Detect tools within SDK
        oEnv.ndkPath = detectAndroidNdk(oEnv.sdkPath)
        oEnv.hasNdk = len(oEnv.ndkPath) > 0

        oEnv.buildToolsPath = findBuildTools(oEnv.sdkPath)
        oEnv.hasBuildTools = len(oEnv.buildToolsPath) > 0

        # Get tool paths
        oEnv.aapt2 = getBuildTool(oEnv.sdkPath, "aapt2")
        oEnv.d8 = getBuildTool(oEnv.sdkPath, "d8")
        oEnv.zipalign = getBuildTool(oEnv.sdkPath, "zipalign")
        oEnv.apksigner = getBuildTool(oEnv.sdkPath, "apksigner")
        oEnv.adb = getPlatformTool(oEnv.sdkPath, "adb")
        oEnv.cmake = getCMake(oEnv.sdkPath)
    ok

    # Detect Java
    oEnv.javaHome = detectJavaHome()
    oEnv.hasJava = len(oEnv.javaHome) > 0

    # Detect Ring Compiler/VM (for embedding bytecode)
    oEnv.ringBinary = detectRingBinary()
    oEnv.ringRoot = sysGet("RING")

    return oEnv

# Print environment status
func printEnvironment oEnv
    ? FG_CYAN + "Environment Status:" + COLOR_RESET

    # SDK
    if oEnv.hasSdk
        ? FG_GREEN + "  [OK] " + COLOR_RESET + "Android SDK: " + oEnv.sdkPath
    else
        ? FG_RED + "  [X]  " + COLOR_RESET + "Android SDK: Not found"
    ok

    # NDK
    if oEnv.hasNdk
        ? FG_GREEN + "  [OK] " + COLOR_RESET + "Android NDK: " + oEnv.ndkPath
    else
        ? FG_RED + "  [X]  " + COLOR_RESET + "Android NDK: Not found"
    ok

    # Build Tools
    if oEnv.hasBuildTools
        ? FG_GREEN + "  [OK] " + COLOR_RESET + "Build Tools: " + oEnv.buildToolsPath
    else
        ? FG_RED + "  [X]  " + COLOR_RESET + "Build Tools: Not found"
    ok

    # CMake
    if len(oEnv.cmake) > 0
        ? FG_GREEN + "  [OK] " + COLOR_RESET + "CMake:       " + oEnv.cmake
    else
        ? FG_RED + "  [X]  " + COLOR_RESET + "CMake:       Not found"
    ok


# Check if environment is ready for building
func isEnvironmentReady oEnv
    return oEnv.hasSdk and oEnv.hasNdk and oEnv.hasBuildTools and
           oEnv.hasJava and len(oEnv.cmake) > 0

/*
    Environment class
*/
class Environment
    # Paths
    sdkPath = "" ndkPath = "" javaHome = "" buildToolsPath = "" ringRoot = ""

    # Tool paths
    aapt2 = "" d8 = "" zipalign = "" apksigner = "" adb = "" cmake = "" ringBinary = ""

    # Status flags
    hasSdk = false hasNdk = false hasJava = false hasBuildTools = false
