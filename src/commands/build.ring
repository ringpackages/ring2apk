# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    build command for Ring2APK
    Compiles Ring app and creates APK without Gradle
*/

# Execute build command
func cmdBuild aArgs
    lRelease = false
    lRebuild = false
    aTargets = []

    # Parse arguments
    for cArg in aArgs
        if cArg = "--release"
            lRelease = true
        but left(cArg, 9) = "--target="
            cTargetList = subStr(cArg, 10)
            aTargets = split(cTargetList, ",")
        but cArg = "--rebuild" or cArg = "--force"
            lRebuild = true
        ok
    next

    if lRelease
        logInfo("Building release APK...")
    else
        logInfo("Building debug APK...")
    ok

    # Load config FIRST so config errors are reported even without an SDK
    oConfig = loadConfig("ring2apk.ring")
    if isNull(oConfig)
        fail("Configuration could not be loaded")
    ok

    # Apply CLI --target before validation so invalid ABIs are rejected too
    if len(aTargets) > 0
        oConfig[:targets] = aTargets
    ok
    aErrors = validateConfig(oConfig)
    if len(aErrors) > 0
        logError("Configuration errors:")
        for cErr in aErrors
            ? "  - " + cErr
        next
        shutdown(1)
    ok

    # Check environment
    oEnv = detectEnvironment()
    if not isEnvironmentReady(oEnv)
        logError("Build environment not ready!")
        printEnvironment(oEnv)
        ? "Install Android SDK/NDK and set ANDROID_SDK_ROOT."
        shutdown(1)
    ok

    # Embedding needs the ring Compiler/VM; fail early, not at step 4
    if len(oConfig[:ringSrcDir]) > 0 and len(oEnv.ringBinary) = 0
        logError("ringSrcDir is set but the ring binary was not found")
        ? "Set the RING environment variable or add ring to PATH."
        shutdown(1)
    ok

    # Set debug/release mode
    oConfig[:debuggable] = not lRelease

    # Skip the build when the APK exists and sources haven't changed
    cSuffix = "debug"
    if lRelease
        cSuffix = "release"
    ok
    cBuiltApk = oConfig[:outputDir] + "/" + oConfig[:name] + "-" + cSuffix + ".apk"
    cHashFile = ".ring2apk.hash"
    cCurrentHash = computeSourcesHash(oConfig)
    if not lRebuild and fExists(cBuiltApk) and fExists(cHashFile)
        cStoredHash = trim(read(cHashFile))
        if cCurrentHash = cStoredHash
            logInfo("APK already built: " + cBuiltApk)
            logInfo("Run 'ring2apk build --rebuild' to force a full rebuild")
            return
        ok
    ok

    # Execute build pipeline
    oBuild = new BuildContext
    oBuild.config = oConfig
    oBuild.env = oEnv
    oBuild.isRebuild = lRebuild
    oBuild.isRelease = lRelease

    if not executeBuild(oBuild)
        fail("Build failed")
    ok

    # Store hash of sources for incremental builds
    write(cHashFile, cCurrentHash)

# Compute a combined hash of all source files that affect the APK.
# Used to detect source changes for incremental builds.
# Includes: Ring sources, assets, Java, C/C++ sources, resources, manifest.
func computeSourcesHash oConfig
    aFiles = []

    # Ring sources
    if len(oConfig[:ringSrcDir]) > 0 and dirExists(oConfig[:ringSrcDir])
        for cFile in listAllFilesEx(oConfig[:ringSrcDir], ".ring")
            aFiles + cFile
        next
    ok

    # Assets
    if len(oConfig[:assetsDir]) > 0 and dirExists(oConfig[:assetsDir])
        for cFile in listAllFilesEx(oConfig[:assetsDir], "")
            aFiles + cFile
        next
    ok

    # Java sources
    cJavaDir = oConfig[:srcDir] + "/java"
    if dirExists(cJavaDir)
        for cFile in listAllFilesEx(cJavaDir, ".java")
            aFiles + cFile
        next
    ok

    # C/C++ sources (excluding vendored Ring VM)
    cCppDir = oConfig[:srcDir] + "/cpp"
    if dirExists(cCppDir)
        for cFile in listAllFilesEx(cCppDir, "")
            if substr(lower(cFile), "/ring/") = 0
                aFiles + cFile
            ok
        next
    ok

    # Resources
    if len(oConfig[:resDir]) > 0 and dirExists(oConfig[:resDir])
        for cFile in listAllFilesEx(oConfig[:resDir], "")
            aFiles + cFile
        next
    ok

    # Manifest
    if fExists("AndroidManifest.xml")
        aFiles + "AndroidManifest.xml"
    ok

    if len(aFiles) = 0
        return ""
    ok

    aFiles = sort(aFiles)

    cCombined = ""
    for cFile in aFiles
        cCombined += lower(cFile) + ":" + murmur3Hash(read(cFile), 0) + nl
    next

    return "" + murmur3Hash(cCombined, 0)

# Main build pipeline
func executeBuild oBuild
    nStart = uptime()

    # Step 1: Prepare build directories
    logStep("1/8", "Preparing build directories...")
    if not prepareBuildDirs(oBuild)
        return false
    ok

    # Step 2: Copy assets (images, data files)
    logStep("2/8", "Copying assets...")
    if not copyAssets(oBuild)
        return false
    ok

    # Step 3: Compile resources with aapt2
    logStep("3/8", "Compiling resources...")
    if not compileResources(oBuild)
        return false
    ok

    # Step 4: Embed Ring bytecode (ring -go -norun) when ringSrcDir is set
    logStep("4/8", "Embedding Ring bytecode...")
    if not embedRingCode(oBuild)
        return false
    ok

    # Step 5: Build native libraries with NDK
    logStep("5/8", "Building native libraries...")
    if not buildNativeLibs(oBuild)
        return false
    ok

    # Step 6: Compile Java code (if any)
    logStep("6/8", "Compiling Java code...")
    if not compileJava(oBuild)
        return false
    ok

    # Step 7: Create APK
    logStep("7/8", "Creating APK...")
    if not createApk(oBuild)
        return false
    ok

    # Step 8: Sign APK
    logStep("8/8", "Signing APK...")
    if not signApk(oBuild)
        return false
    ok

    nEnd = uptime()
    nSeconds = floor((nEnd - nStart) / 100000 + 0.5) / 100

    logSuccess("Build completed in " + nSeconds + " seconds!")
    ? "Output: " + oBuild.outputApk
    return true

# Prepare build directories
func prepareBuildDirs oBuild
    cBuildDir = oBuild.config[:outputDir]

    # unchanged C/C++ sources compile incrementally. Only the APK
    # staging dirs (apk, res-compiled, obj, dex) are rebuilt each time.
    if oBuild.isRebuild
        rmrf(cBuildDir)
    ok

    mkDir(cBuildDir)
    mkDir(cBuildDir + "/apk")
    mkDir(cBuildDir + "/apk/lib")
    mkDir(cBuildDir + "/apk/assets")
    mkDir(cBuildDir + "/res-compiled")
    mkDir(cBuildDir + "/gen")
    mkDir(cBuildDir + "/obj")
    mkDir(cBuildDir + "/dex")

    # Create lib directories for each ABI
    for cAbi in oBuild.config[:targets]
        mkDir(cBuildDir + "/apk/lib/" + cAbi)
    next

    oBuild.buildDir = cBuildDir
    return true

# Copy assets to build directory
func copyAssets oBuild
    cSrcAssets = oBuild.config[:assetsDir]
    cDestAssets = oBuild.buildDir + "/apk/assets"

    if dirExists(cSrcAssets)
        copyDir(cSrcAssets, cDestAssets)
        logBuild("Copied assets from " + cSrcAssets)
    ok

    return true


# Embed Ring bytecode
func embedRingCode oBuild
    cRingSrc = oBuild.config[:ringSrcDir]
    # Optional feature: skip unless a Ring source directory is configured
    if len(cRingSrc) = 0
        return true
    ok
    if not dirExists(cRingSrc)
        logWarning("ringSrcDir not found, skipping bytecode embedding: " + cRingSrc)
        return true
    ok

    cEntry = oBuild.config[:entryPoint]
    if not fExists(cRingSrc + "/" + cEntry)
        logError("Entry point not found: " + cRingSrc + "/" + cEntry)
        return false
    ok

    cRing = oBuild.env.ringBinary
    if len(cRing) = 0
        logError("ring binary not found (set the RING environment variable or add ring to PATH)")
        return false
    ok

    # Stage the Ring sources in the build directory so ring's generated
    # .ringo never touches the project source tree
    cStage = oBuild.buildDir + "/ring-src"
    rmrf(cStage)
    mkDir(cStage)
    copyDir(cRingSrc, cStage)

    cOldDir = currentDir()
    chdir(cStage)
    cLogFile = tempName() + ".txt"
    cCmd = '"' + cRing + '" -go -norun "' + cEntry + '" > "' + cLogFile + '" 2>&1'
    logCommand(cCmd)
    nResult = system(cCmd)
    chdir(cOldDir)

    if nResult != 0
        logError("ring -go -norun failed for " + cEntry)
        if fExists(cLogFile)
            ? read(cLogFile)
            remove(cLogFile)
        ok
        return false
    ok
    if fExists(cLogFile)
        remove(cLogFile)
    ok

    # ring -go -norun writes <entry>.ringo (same basename, .ringo extension)
    cRingoFile = cStage + "/" + subStr(cEntry, 1, len(cEntry) - 5) + ".ringo"
    if not fExists(cRingoFile)
        logError("ring -go -norun did not produce .ringo file")
        return false
    ok

    # Generate ringappcode.c (hex-embedded bytecode) and ringappcode.h
    cRingoData = read(cRingoFile)
    cHex = str2hexCStyle(cRingoData)
    nSize = len(cRingoData)

    cGenDir = oBuild.buildDir + "/gen"
    mkDir(cGenDir)

    cCode = "#include " + '"ringappcode.h"' + nl + nl +
        "#include " + '"ring.h"' + nl + nl +
        "static const unsigned char g_bytecode[] = {" + nl +
        "  " + cHex + ", 0x00" + nl +
        "};" + nl + nl +
        "void ringappcode_run(RingState *pRingState) {" + nl +
        "  ring_state_runobjectstring(pRingState, (char *)g_bytecode, " + nSize + ", " + '"embedded.ringo"' + ");" + nl +
        "}" + nl
    write(cGenDir + "/ringappcode.c", cCode)

    cHeader = "#ifndef RINGAPPCODE_H" + nl +
        "#define RINGAPPCODE_H" + nl + nl +
        "#include " + '"ring.h"' + nl + nl +
        "void ringappcode_run(RingState *pRingState);" + nl + nl +
        "#endif" + nl
    write(cGenDir + "/ringappcode.h", cHeader)

    logBuild("Embedded Ring bytecode (" + nSize + " bytes) -> " + cGenDir + "/ringappcode.c")
    return true
# Compile resources with aapt2
func compileResources oBuild
    cAapt2 = oBuild.env.aapt2
    if len(cAapt2) = 0
        logError("aapt2 not found!")
        return false
    ok

    cResDir = oBuild.config[:resDir]
    cCompiledDir = oBuild.buildDir + "/res-compiled"

    if not dirExists(cResDir)
        logWarning("No res directory found, skipping resource compilation")
        return true
    ok

    # Compile each resource file
    aResFiles = listAllFilesEx(cResDir, "")
    for cFile in aResFiles
        cCmd = '"' + cAapt2 + '" compile "' + cFile + '" -o "' + cCompiledDir + '"'
        if shellExec(cCmd) != 0
            logError("Failed to compile resource: " + cFile)
            return false
        ok
    next

    logBuild("Compiled " + len(aResFiles) + " resource files")
    return true

# Build native libraries using NDK
func buildNativeLibs oBuild
    # Compile src/cpp (Ring VM + raylib/sokol etc.) with NDK/CMake when the
    # project ships a CMake project; otherwise package no native library.
    cCppDir = oBuild.config[:srcDir] + "/cpp"
    if fExists(cCppDir + "/CMakeLists.txt")
        return buildNativeFromSource(oBuild, cCppDir)
    ok

    # No CMake project: nothing to build. Without a native library the
    # NativeActivity app cannot launch, so say so loudly.
    logWarning("No src/cpp/CMakeLists.txt - no native library will be packaged")
    return true

# Build native libraries from src/cpp using the NDK toolchain + CMake
func buildNativeFromSource oBuild, cCppDir
    # Re-copy Ring VM sources if they were deleted or never copied
    cRingDir = cCppDir + "/ring"
    if not dirExists(cRingDir + "/src")
        cRingRoot = oBuild.env.ringRoot
        if len(cRingRoot) = 0 or not dirExists(cRingRoot + "/language/src")
            logError("Ring sources missing from src/cpp/ring and RING env not set — can't build native libs")
            return false
        ok
        logInfo("Ring VM sources missing, copying from " + cRingRoot + "/language...")
        copyRingSources(cRingRoot, cRingDir)
    ok

    cNdkPath = oBuild.env.ndkPath
    if len(cNdkPath) = 0
        logError("NDK not found!")
        return false
    ok

    cToolchain = cNdkPath + "/build/cmake/android.toolchain.cmake"
    if not fExists(cToolchain)
        logError("NDK toolchain not found: " + cToolchain)
        return false
    ok

    cCMake = oBuild.env.cmake
    if len(cCMake) = 0
        logError("CMake not found (install CMake and ensure it's on PATH)")
        return false
    ok

    cLibName = getNativeLibName()
    nMinSdk = oBuild.config[:minSdk]
    nJobs = nofProcessors()

    for cAbi in oBuild.config[:targets]
        cBuildType = "Debug"
        if oBuild.isRelease
            cBuildType = "Release"
        ok
        cNativeDir = oBuild.buildDir + "/native/" + cAbi
        # CMake caches CMAKE_BUILD_TYPE; wipe stale configs when build type changes
        # so debug/release switches actually reconfigure instead of keeping old flags
        cCacheFile = cNativeDir + "/CMakeCache.txt"
        if fExists(cCacheFile)
            cCachedType = ""
            for cLine in str2List(read(cCacheFile))
                if left(cLine, 17) = "CMAKE_BUILD_TYPE:"
                    cCachedType = trim(subStr(cLine, 18))
                    exit
                ok
            next
            if cCachedType != cBuildType
                rmrf(cNativeDir)
            ok
        ok
        mkDir(cNativeDir)

        logBuild("Configuring " + cAbi + " (NDK " + cNdkPath + ")...")

        cCmd = '"' + cCMake + '" -S "' + cCppDir + '" -B "' + cNativeDir + '" ' +
               '-G Ninja ' +
               '-DCMAKE_TOOLCHAIN_FILE="' + cToolchain + '" ' +
               '-DANDROID_ABI=' + cAbi + ' ' +
               '-DANDROID_PLATFORM=android-' + nMinSdk + ' ' +
               '-DANDROID_STL=c++_static ' +
               '-DCMAKE_BUILD_TYPE=' + cBuildType + ' ' +
               '-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"'
        if shellExec(cCmd) != 0
            logError("CMake configuration failed for " + cAbi)
            return false
        ok

        logBuild("Compiling " + cAbi + "...")

        cCmd = '"' + cCMake + '" --build "' + cNativeDir + '" --target "' + cLibName + '" -j ' + nJobs
        if shellExec(cCmd) != 0
            logError("Native build failed for " + cAbi)
            return false
        ok

        cSo = cNativeDir + "/lib" + cLibName + ".so"
        if not fExists(cSo)
            logError("Expected library not produced: " + cSo)
            return false
        ok

        cDest = oBuild.buildDir + "/apk/lib/" + cAbi
        mkDir(cDest)
        copyFile(cSo, cDest + "/lib" + cLibName + ".so")
        logBuild("Packaged lib" + cLibName + ".so for " + cAbi)
    next

    return true

# Read the native library name from AndroidManifest.xml
# (meta-data android.app.lib_name, default "main")
func getNativeLibName
    cManifestPath = "AndroidManifest.xml"
    cLibName = "main"

    if not fExists(cManifestPath)
        return cLibName
    ok

    cContent = read(cManifestPath)
    nPos = subStr(cContent, "android.app.lib_name")
    if nPos = 0
        return cLibName
    ok

    cTail = subStr(cContent, nPos)
    nValPos = subStr(cTail, 'android:value="')
    if nValPos = 0
        return cLibName
    ok

    nStart = nValPos + len('android:value="')
    cValue = subStr(cTail, nStart)

    nEnd = subStr(cValue, '"')
    if nEnd > 0
        cLibName = subStr(cValue, 1, nEnd - 1)
    else
        cLibName = cValue
    ok

    if len(cLibName) = 0
        cLibName = "main"
    ok

    return cLibName

# Compile Java code (javac) and dex it (d8) into the APK
func compileJava oBuild
    cJavaSrc = "src/java"
    aJavaFiles = listAllFilesEx(cJavaSrc, ".java")
    if len(aJavaFiles) = 0
        return true  # No Java code to compile
    ok

    cJavaHome = oBuild.env.javaHome
    cJavac = cJavaHome + pathSeparator() + "bin" + pathSeparator() + "javac"
    if isWindows()
        cJavac += ".exe"
    ok
    if not fExists(cJavac)
        logError("javac not found but Java sources exist in " + cJavaSrc)
        return false
    ok
    if len(oBuild.env.d8) = 0
        logError("d8 not found but Java sources exist in " + cJavaSrc)
        return false
    ok

    cAndroidJar = findPlatform(oBuild.env.sdkPath, oBuild.config[:compileSdk]) + "/android.jar"
    if not fExists(cAndroidJar)
        logError("android.jar not found for API " + oBuild.config[:compileSdk])
        return false
    ok

    # javac -> .class files
    cClassDir = oBuild.buildDir + "/obj/classes"
    mkDir(cClassDir)

    cFileList = ""
    nMax = len(aJavaFiles)
    for i = 1 to nMax
        cFileList += '"' + aJavaFiles[i] + '" '
    next

    cCmd = '"' + cJavac + '" -source 11 -target 11 -d "' + cClassDir +
           '" -classpath "' + cAndroidJar + '" ' + cFileList
    if shellExec(cCmd) != 0
        logError("Java compilation failed!")
        return false
    ok
    logBuild("Compiled Java sources")

    # d8 -> classes.dex
    cDexDir = oBuild.buildDir + "/dex"
    mkDir(cDexDir)

    cClassFiles = ""
    aClasses = listAllFilesEx(cClassDir, ".class")
    nMax = len(aClasses)
    for i = 1 to nMax
        # Escape '$' (anonymous/inner class files like MainActivity$1.class)
        # so the shell does not expand $1/$10/... inside the double quotes.
        cClassFiles += '"' + subStr(aClasses[i], "$", char(92) + "$") + '" '
    next

    cCmd = '"' + oBuild.env.d8 + '" --min-api ' + oBuild.config[:minSdk] +
           ' --lib "' + cAndroidJar + '" --output "' + cDexDir + '" ' + cClassFiles
    if shellExec(cCmd) != 0
        logError("d8 dexing failed!")
        return false
    ok

    # Stage at the APK root (addFilesToApk zips buildDir/apk)
    if not fExists(cDexDir + "/classes.dex")
        logError("d8 did not produce classes.dex")
        return false
    ok
    copyFile(cDexDir + "/classes.dex", oBuild.buildDir + "/apk/classes.dex")
    logBuild("Packaged classes.dex")
    return true

# Create the APK file
func createApk oBuild
    cAapt2 = oBuild.env.aapt2
    cBuildDir = oBuild.buildDir

    # Use the project's AndroidManifest.xml when present (NativeActivity,
    # custom resources, etc.), otherwise generate a default one
    cBuiltManifest = cBuildDir + "/AndroidManifest.xml"
    if fExists("AndroidManifest.xml")
        copyFile("AndroidManifest.xml", cBuiltManifest)
        logBuild("Using project AndroidManifest.xml")
    else
        cManifest = generateManifest(oBuild.config)
        write(cBuiltManifest, cManifest)
    ok

    # aapt2 requires a literal package attribute (--rename-manifest-package
    # only renames an existing one), so inject it when missing
    ensureManifestPackage(cBuiltManifest, oBuild.config[:packageId])

    # Find android.jar
    cAndroidJar = findPlatform(oBuild.env.sdkPath, oBuild.config[:compileSdk]) + "/android.jar"
    if not fExists(cAndroidJar)
        logError("android.jar not found for API " + oBuild.config[:compileSdk])
        return false
    ok

    # Link resources and create base APK
    cBaseApk = cBuildDir + "/base.apk"
    cResCompiled = cBuildDir + "/res-compiled"

    # Find all compiled resources
    cResFlat = ""
    if dirExists(cResCompiled)
        aFlats = dir(cResCompiled)
        for aFile in aFlats
            if aFile[2] = 0  # Is file
                cResFlat += '"' + cResCompiled + "/" + aFile[1] + '" '
            ok
        next
    ok

    cCmd = '"' + cAapt2 + '" link -o "' + cBaseApk + '" ' +
           '-I "' + cAndroidJar + '" ' +
           '--manifest "' + cBuildDir + '/AndroidManifest.xml" ' +
           '--rename-manifest-package ' + oBuild.config[:packageId] + ' ' +
           '--min-sdk-version ' + oBuild.config[:minSdk] + ' ' +
           '--target-sdk-version ' + oBuild.config[:targetSdk] + ' ' +
           '--version-code ' + oBuild.config[:versionCode] + ' ' +
           '--version-name ' + oBuild.config[:versionName] + ' '

    if len(cResFlat) > 0
        cCmd += cResFlat
    ok

    if oBuild.config[:debuggable]
        cCmd += '--debug-mode '
    ok

    if shellExec(cCmd) != 0
        logError("Failed to create base APK!")
        return false
    ok

    # Add native libraries and assets to APK
    cUnalignedApk = cBuildDir + "/unaligned.apk"
    copyFile(cBaseApk, cUnalignedApk)

    # Use zip to add files (assets, native libraries, ...)
    if addFilesToApk(cUnalignedApk, cBuildDir + "/apk") != 0
        logError("Failed to add files to APK!")
        return false
    ok

    # Align the APK
    cZipalign = oBuild.env.zipalign
    cAlignedApk = cBuildDir + "/aligned.apk"

    cCmd = '"' + cZipalign + '" -f -v 4 "' + cUnalignedApk + '" "' + cAlignedApk + '"'
    if shellSilent(cCmd) != 0
        logError("zipalign failed!")
        return false
    ok

    oBuild.alignedApk = cAlignedApk
    logBuild("Created aligned APK")
    return true

# Add files to APK using zip
func addFilesToApk cApkPath, cSourceDir
    # Resolve the APK path against the original working directory:
    # a relative path would be interpreted from inside cSourceDir
    cOldDir = currentDir()
    cAbsApk = cApkPath
    lAbsolute = left(cAbsApk, 1) = "/"
    if isWindows() and subStr(cAbsApk, ":") > 0
        lAbsolute = true
    ok
    if not lAbsolute
        cAbsApk = cOldDir + pathSeparator() + cAbsApk
    ok

    # Change to source directory and add files
    chdir(cSourceDir)

    nResult = 0
    if isWindows()
        # Prefer zip (correct / separators) if available (Git for Windows / Scoop)
        if shellSilent("where zip > NUL 2>&1") = 0
            nResult = shellSilent('zip -r "' + cAbsApk + '" .')
        else
            # PowerShell 5.1: must quote, must handle .zip auto-append, and
            # 5.1 writes \ separators (Android rejects) — fixed in pwsh 7 / .NET Core
            cQ = char(39)
            cTmpZip = cAbsApk + ".zip"
            nResult = shellSilent('powershell -Command "Compress-Archive -Path * -Force -DestinationPath ' + cQ + cTmpZip + cQ + '; Move-Item -Force ' + cQ + cTmpZip + cQ + ' ' + cQ + cAbsApk + cQ + '"')
        ok
    else
        # Use zip command (native libraries stay compressed: they are
        # extracted at install time, so no 16 KB zip-entry alignment is
        # required; their ELF segments are aligned by the linker flags)
        nResult = shellSilent('zip -r "' + cAbsApk + '" .')
    ok

    chdir(cOldDir)
    return nResult

# Sign the APK
func signApk oBuild
    cApksigner = oBuild.env.apksigner
    cAlignedApk = oBuild.alignedApk

    cOutputName = oBuild.config[:name]
    if oBuild.isRelease
        cOutputName += "-release"
    else
        cOutputName += "-debug"
    ok
    cOutputApk = oBuild.buildDir + "/" + cOutputName + ".apk"

    # Copy aligned APK to output
    copyFile(cAlignedApk, cOutputApk)
    # Password temp-file paths (release branch sets them; debug branch
    # leaves them empty so the cleanup below is a no-op)
    cStoreFile = ""
    cKeyFile = ""

    if oBuild.isRelease and len(oBuild.config[:keystore]) > 0
        # Sign with release keystore. Password goes via a temp file (file:
        cStoreFile = tempName() + ".pass"
        write(cStoreFile, oBuild.config[:keystorePassword] + nl)

        cCmd = '"' + cApksigner + '" sign ' +
               '--ks "' + oBuild.config[:keystore] + '" ' +
               '--ks-pass file:"' + cStoreFile + '" '

        if len(oBuild.config[:keyAlias]) > 0
            cCmd += '--ks-key-alias ' + oBuild.config[:keyAlias] + ' '
        ok

        if len(oBuild.config[:keyPassword]) > 0
            cKeyFile = tempName() + ".pass"
            write(cKeyFile, oBuild.config[:keyPassword] + nl)
            cCmd += '--key-pass file:"' + cKeyFile + '" '
        ok

        cCmd += '"' + cOutputApk + '"'
    else
        # Sign with debug keystore
        cDebugKeystore = getDebugKeystore()
        if len(cDebugKeystore) = 0
            logWarning("No debug keystore found, creating one...")
            cDebugKeystore = createDebugKeystore(oBuild.env.javaHome)
            if len(cDebugKeystore) = 0
                logError("Failed to create debug keystore")
                return false
            ok
        ok

        cCmd = '"' + cApksigner + '" sign ' +
               '--ks "' + cDebugKeystore + '" ' +
               '--ks-pass pass:android ' +
               '"' + cOutputApk + '"'
    ok

    nSignResult = shellSilent(cCmd)
    # Clean up password temp files regardless of outcome
    if len(cStoreFile) > 0 and fExists(cStoreFile)
        remove(cStoreFile)
    ok
    if len(cKeyFile) > 0 and fExists(cKeyFile)
        remove(cKeyFile)
    ok
    if nSignResult != 0
        logError("APK signing failed!")
        return false
    ok

    oBuild.outputApk = cOutputApk
    logBuild("Signed APK: " + cOutputApk)
    return true

# Get debug keystore path
func getDebugKeystore
    if isWindows()
        cPath = sysGet("USERPROFILE") + "\.android\debug.keystore"
    else
        cPath = sysGet("HOME") + "/.android/debug.keystore"
    ok

    if fExists(cPath)
        return cPath
    ok

    return ""

# Create debug keystore
func createDebugKeystore cJavaHome
    cKeytool = cJavaHome + pathSeparator() + "bin" + pathSeparator() + "keytool"
    if isWindows()
        cKeytool += ".exe"
    ok

    if isWindows()
        cKeystoreDir = sysGet("USERPROFILE") + "\.android"
        cKeystore = cKeystoreDir + "\debug.keystore"
    else
        cKeystoreDir = sysGet("HOME") + "/.android"
        cKeystore = cKeystoreDir + "/debug.keystore"
    ok

    mkDir(cKeystoreDir)

    cCmd = '"' + cKeytool + '" -genkeypair ' +
           '-alias androiddebugkey ' +
           '-keyalg RSA -keysize 2048 -validity 10000 ' +
           '-keystore "' + cKeystore + '" ' +
           '-storepass android -keypass android ' +
           '-dname "CN=Android Debug,O=Android,C=US"'

    if shellSilent(cCmd) != 0
        logError("keytool failed to create debug keystore")
        return ""
    ok
    return cKeystore

# Generate AndroidManifest.xml
func generateManifest oConfig
    cPermissions = ""
    for cPerm in oConfig[:permissions]
        cPermissions += '    <uses-permission android:name="' + cPerm + '" />' + nl
    next

    cFeatures = ""
    for cFeat in oConfig[:features]
        cFeatures += '    <uses-feature android:name="' + cFeat + '" android:required="false" />' + nl
    next

    # Icon is only referenced when the project ships a launcher icon
    cIcon = ""
    if resHasLauncherIcon(oConfig[:resDir])
        cIcon = '        android:icon="@mipmap/ic_launcher"' + nl
    ok

    # Activity choice: NativeActivity for pure-native apps, the project's
    # MainActivity when Java sources are present
    lHasJava = hasJavaSources("src/java")
    if lHasJava
        cActivityClass = oConfig[:packageId] + ".MainActivity"
        cHasCode = "true"
        cLibMeta = ""
    else
        cActivityClass = "android.app.NativeActivity"
        cHasCode = "false"
        cLibMeta = '            <meta-data android:name="android.app.lib_name" android:value="' +
                   getNativeLibName() + '" />' + nl
    ok

    # OpenGL ES: only emitted when requireGLES is set (e.g. "0x00030000").
    # Off by default - non-GL apps must not be hidden from GL-less devices.
    cGLES = ""
    if len(oConfig[:requireGLES]) > 0
        cGLES = '    <uses-feature android:glEsVersion="' + oConfig[:requireGLES] +
                '" android:required="true" />' + nl
    ok

    cManifest = `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="` + oConfig[:packageId] + `"
    android:versionCode="` + oConfig[:versionCode] + `"
    android:versionName="` + oConfig[:versionName] + `">

    <uses-sdk
        android:minSdkVersion="` + oConfig[:minSdk] + `"
        android:targetSdkVersion="` + oConfig[:targetSdk] + `" />

` + cPermissions + `
` + cFeatures + `
` + cGLES + `

    <application
        android:allowBackup="true"
` + cIcon + `        android:label="` + oConfig[:label] + `"
        android:theme="` + oConfig[:theme] + `"
        android:hardwareAccelerated="` + bool2str(oConfig[:hardwareAccelerated]) + `"
        android:hasCode="` + cHasCode + `"
        android:debuggable="` + bool2str(oConfig[:debuggable]) + `">

        <activity
            android:name="` + cActivityClass + `"
            android:exported="true"
            android:configChanges="orientation|screenSize|screenLayout|keyboardHidden"
            android:screenOrientation="` + oConfig[:orientation] + `">
` + cLibMeta + `            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
`
    return cManifest

# Inject a package attribute into the <manifest> tag if it lacks one
func ensureManifestPackage cManifestPath, cPackage
    cContent = read(cManifestPath)
    if subStr(cContent, "package=") > 0
        return cContent
    ok

    nManifestPos = subStr(cContent, "<manifest")
    if nManifestPos = 0
        return cContent
    ok

    cTail = subStr(cContent, nManifestPos)
    nTagEnd = subStr(cTail, ">")
    if nTagEnd = 0
        return cContent
    ok

    cTagOpen = subStr(cTail, 1, nTagEnd - 1)
    cRest = subStr(cTail, nTagEnd)
    cNew = subStr(cContent, 1, nManifestPos - 1) +
           cTagOpen + ' package="' + cPackage + '"' + cRest

    write(cManifestPath, cNew)
    return cNew

# Check whether the project ships Java sources
func hasJavaSources cJavaDir
    if not dirExists(cJavaDir)
        return false
    ok
    aFiles = listAllFilesEx(cJavaDir, ".java")
    return len(aFiles) > 0

# Check that the res tree contains a launcher icon (ic_launcher.*)
func resHasLauncherIcon cResDir
    aFiles = listAllFilesEx(cResDir, "")
    for cFile in aFiles
        if subStr(lower(cFile), "ic_launcher") > 0
            return true
        ok
    next
    return false

/*
    Build context class
*/
class BuildContext
    config env buildDir alignedApk outputApk
    isRelease = false isRebuild = false
