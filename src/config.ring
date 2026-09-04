# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    Configuration parser for Ring2APK
    Parses ring2apk.ring config files and merges them with defaults
*/

/*
    Configuration list - Default values
*/
Ring2ApkConfig = [
    # Package info - using packageId instead of 'package' (reserved word)
    :name = "myapp",
    :packageId = "com.example.myapp",
    :versionCode = 1,
    :versionName = "1.0.0",
    
    # Android SDK settings
    :minSdk = 21,
    :targetSdk = 34,
    :compileSdk = 34,
    # Build targets (ABIs)
    :targets = ["arm64-v8a", "armeabi-v7a"],
    
    # Paths
    :assetsDir = "assets",
    :resDir = "res",
    :srcDir = "src",
    :outputDir = "build",
    
    # Ring source entry point
    :entryPoint = "main.ring",

    # Ring source directory for embedded bytecode (empty = disabled).
    # When set, ring2apk compiles entryPoint (and all transitive loads) into
    # a .ringo object file via `ring -go -norun`, then hex-embeds it into
    # ringappcode.c/.h. The .ring sources are NOT packaged as assets.
    :ringSrcDir = "",
    
    # Permissions
    :permissions = [],
    
    # Features
    :features = [],
    
    # Application settings
    :label = "My App",
    :icon = "",
    :theme = "@android:style/Theme.NoTitleBar.Fullscreen",
    # OpenGL ES requirement for the generated manifest (off by default:
    # only GL-using native apps need it; set via :requireGLES = "0x00030000")
    :requireGLES = "",

    :hardwareAccelerated = true,
    :orientation = "unspecified",
    
    # Signing (for release builds)
    :keystore = "",
    :keystorePassword = "",
    :keyAlias = "",
    :keyPassword = "",
    
    # Debug mode
    :debuggable = true
]


# Load and parse config from file
    
func loadConfig cConfigFile
    # Snapshot defaults (eval replaces the global Ring2ApkConfig below)
    aDefaults = Ring2ApkConfig
    
    if not fExists(cConfigFile)
        logError("Config file not found: " + cConfigFile + " — run 'ring2apk init' to create one")
        return NULL
    ok
    
    logInfo("Loading config: " + cConfigFile)
    
    cText = read(cConfigFile)
    # ponytail: substring check for Ring2ApkConfig, not full parse — catches empty/wrong files cheaply; use AST if false positives matter
    if subStr(cText, "Ring2ApkConfig") = 0
        logError("Config missing Ring2ApkConfig assignment: " + cConfigFile)
        return NULL
    ok
    
    # Execute the config file. The file assigns the global Ring2ApkConfig,
    # replacing it with the user's hash list. Unset keys fall back to defaults.
    try
        eval(cText)
    catch
        logError("Failed to parse config file: " + cCatchError)
        return NULL
    done
    
    aUser = Ring2ApkConfig
    if not isList(aUser)
        logError("Failed to parse config file: Ring2ApkConfig is not a list")
        return NULL
    ok
    if len(aUser) = 0
        logError("Config empty: Ring2ApkConfig has no entries")
        return NULL
    ok
    
    aConfig = mergeConfig(aDefaults, aUser)

    # Canonicalize SDK versions once
    aConfig[:minSdk] = sdkVersionString(aConfig[:minSdk])
    aConfig[:targetSdk] = sdkVersionString(aConfig[:targetSdk])
    if isString(aConfig[:compileSdk])
        aConfig[:compileSdk] = trim(aConfig[:compileSdk])
    else
        aConfig[:compileSdk] = sdkVersionString(aConfig[:compileSdk])
    ok

    return aConfig

# Merge user config into default config
# Configs are hash lists stored as [key, value] pairs: iterate pairs and
# let known keys override the defaults (unknown keys are preserved too).
func mergeConfig aDefault, aUser
    nMax = len(aUser)
    for i = 1 to nMax
        aPair = aUser[i]
        if isList(aPair) and len(aPair) >= 2
            if isString(aPair[1])
                aDefault[ aPair[1] ] = aPair[2]
            ok
        ok
    next
    return aDefault

# Validate configuration
func validateConfig oConfig
    aErrors = []
    
    # Check required fields
    if len(oConfig[:name]) = 0
        aErrors + "App name is required"
    ok
    
    if len(oConfig[:packageId]) = 0
        aErrors + "Package ID is required"
    ok
    
    # Validate package name format
    if not isValidPackageName(oConfig[:packageId])
        aErrors + ("Invalid package name format: " + oConfig[:packageId])
    ok
    
    # Validate SDK versions
    if NumOrZero(oConfig[:minSdk]) < 21
        aErrors + "minSdk must be at least 21"
    ok
    
    if NumOrZero(oConfig[:targetSdk]) < NumOrZero(oConfig[:minSdk])
        aErrors + "targetSdk must be >= minSdk"
    ok
    
    # Validate targets
    aValidTargets = ["arm64-v8a", "armeabi-v7a", "x86", "x86_64"]
    for cTarget in oConfig[:targets]
        if find(aValidTargets, cTarget) = 0
            aErrors + ("Invalid target ABI: " + cTarget)
        ok
    next
    
    return aErrors

# Check if package name is valid
func isValidPackageName cPkg
    # Must have at least two segments
    if subStr(cPkg, ".") = 0
        return false
    ok
    
    # Check each segment
    aSegments = split(cPkg, ".")
    for cSeg in aSegments
        if len(cSeg) = 0
            return false
        ok
        # First char must be letter
        if not isAlpha(cSeg[1])
            return false
        ok
    next
    
    return true


# Join list to string with separator
func strJoin aList, cSep
    cResult = ""
    for i = 1 to len(aList)
        cResult += aList[i]
        if i < len(aList)
            cResult += cSep
        ok
    next
    return cResult

# Save config to file
func saveConfig cPath, oConfig
    cContent = generateConfigFile(oConfig)
    write(cPath, cContent)
    logSuccess("Config saved to: " + cPath)

# Generate config file content
func generateConfigFile oConfig
    cContent = "/*" + nl
    cContent += "    Ring2APK configuration file" + nl
    cContent += "    Edit this file to configure your Android app build" + nl
    cContent += "*/" + nl + nl
    cContent += "# App configuration" + nl
    cContent += "Ring2ApkConfig = [" + nl
    cContent += "    # App identity" + nl
    cContent += '    :name = "' + oConfig[:name] + '",' + nl
    cContent += '    :packageId = "' + oConfig[:packageId] + '",' + nl
    cContent += "    :versionCode = " + oConfig[:versionCode] + "," + nl
    cContent += '    :versionName = "' + oConfig[:versionName] + '",' + nl
    cContent += nl
    cContent += "    # Android SDK versions" + nl
    cContent += "    :minSdk = " + oConfig[:minSdk] + "," + nl
    cContent += "    :targetSdk = " + oConfig[:targetSdk] + "," + nl
    cContent += "    :compileSdk = " + oConfig[:compileSdk] + "," + nl
    cContent += nl
    cContent += "    # Target architectures" + nl
    cContent += '    :targets = ["' + strJoin(oConfig[:targets], '", "') + '"],' + nl
    cContent += nl
    cContent += "    # Directories" + nl
    cContent += '    :assetsDir = "' + oConfig[:assetsDir] + '",' + nl
    cContent += '    :resDir = "' + oConfig[:resDir] + '",' + nl
    cContent += '    :srcDir = "' + oConfig[:srcDir] + '",' + nl
    cContent += '    :outputDir = "' + oConfig[:outputDir] + '",' + nl
    cContent += nl
    cContent += "    # Entry point Ring file" + nl
    cContent += '    :entryPoint = "' + oConfig[:entryPoint] + '",' + nl
    cContent += '    :ringSrcDir = "' + oConfig[:ringSrcDir] + '",' + nl
    cContent += nl
    cContent += "    # App display settings" + nl
    cContent += '    :label = "' + oConfig[:label] + '",' + nl
    cContent += '    :orientation = "' + oConfig[:orientation] + '",' + nl
    cContent += nl
    cContent += "    # Permissions (uncomment as needed)" + nl
    cContent += "    # permissions = [" + nl
    cContent += '    #     "android.permission.INTERNET",' + nl
    cContent += '    #     "android.permission.VIBRATE"' + nl
    cContent += "    # ]" + nl
    cContent += "]" + nl + nl
    
    return cContent