# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    Shared utilities for Ring2APK
*/

# Convert boolean to string
func bool2str lValue
    if lValue
        return "true"
    ok
    return "false"

# Canonical string form of an SDK version, accepting number or string input
func sdkVersionString xVersion
    if isnumber(xVersion)
        # SDK minor versions are single-digit (android-36.1, android-37.2):
        # a decimals(1) window stringifies exactly, immune to ambient precision.
        decimals(1)
        cVersion = string(xVersion)
        decimals(2)   # restore Ring default
    else
        cVersion = trim("" + xVersion)
    ok

    # Strip trailing zeros after a decimal point, then the dot itself
    if substr(cVersion, ".") != 0
        while right(cVersion, 1) = "0"
            cVersion = left(cVersion, len(cVersion) - 1)
        end
        if right(cVersion, 1) = "."
            cVersion = left(cVersion, len(cVersion) - 1)
        ok
    ok
    return cVersion

# List all files recursively
func listAllFilesEx cDir, cExt
    aResult = []
    if not dirExists(cDir)
        return aResult
    ok

    aFiles = dir(cDir)
    for aFile in aFiles
        cPath = cDir + "/" + aFile[1]
        if aFile[2]  # Directory
            aSubFiles = listAllFilesEx(cPath, cExt)
            for cSub in aSubFiles
                aResult + cSub
            next
        else  # File
            if len(cExt) = 0 or right(cPath, len(cExt)) = cExt
                aResult + cPath
            ok
        ok
    next

    return aResult