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