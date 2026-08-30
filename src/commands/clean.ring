# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    clean command for Ring2APK
    Remove build artifacts
*/

# Execute clean command
func cmdClean aArgs
    lAll = false
    
    # Parse arguments
    for cArg in aArgs
        if cArg = "--all"
            lAll = true
        ok
    next
    
    logInfo("Cleaning build artifacts...")
    
    # Load config to get build directory
    oConfig = loadConfig("ring2apk.ring")
    if isNull(oConfig)
        fail("Configuration could not be loaded")
    ok
    cBuildDir = oConfig[:outputDir]
    
    if dirExists(cBuildDir)
        logStep("Clean", "Removing " + cBuildDir + "/...")
        rmrf(cBuildDir)
        logSuccess("Build directory cleaned!")
    else
        logInfo("Build directory not found, nothing to clean.")
    ok
    
    if lAll
        # Also clean any generated files
        cleanGeneratedFiles()
    ok
    

# Clean generated files
func cleanGeneratedFiles
    aFiles = [
        "*.apk",
        "*.aab",
        "local.properties"
    ]
    
    for cPattern in aFiles
        aDir = dir(".")
        for aFile in aDir
            if not aFile[2]
                if matchPattern(aFile[1], cPattern)
                    logStep("Remove", aFile[1])
                    remove(aFile[1])
                ok
            ok
        next
    next

# Simple pattern matching (supports * wildcard)
func matchPattern cStr, cPattern
    # Handle *.ext pattern
    if left(cPattern, 1) = "*"
        cExt = subStr(cPattern, 2)
        return right(cStr, len(cExt)) = cExt
    ok
    
    # Exact match
    return lower(cStr) = lower(cPattern)
