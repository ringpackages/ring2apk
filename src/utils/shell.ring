# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    Shell utilities for Ring2APK
    Execute system commands and capture output
*/

# Execute a command and return exit code
func shellExec cCommand
    logCommand(cCommand)
    nResult = system(cCommand)
    return nResult

# Execute a command and return output as string
func shellOutput cCommand
    cTempFile = tempName() + ".txt"
    system(cCommand + " > " + cTempFile + " 2>&1")
    cOutput = ""
    if fExists(cTempFile)
        cOutput = read(cTempFile)
        remove(cTempFile)
    ok
    return trim(cOutput)

# Execute a command silently (suppress output)
func shellSilent cCommand
    if isWindows()
        return system(cCommand + " > NUL 2>&1")
    else
        return system(cCommand + " > /dev/null 2>&1")
    ok

# Check if a command exists in PATH
func commandExists cCommand
    if isWindows()
        return shellSilent("where " + cCommand) = 0
    else
        return shellSilent("which " + cCommand) = 0
    ok

# Get path separator for current OS
func pathSeparator
    if isWindows()
        return "\"
    else
        return "/"
    ok

# Join path components
func joinPath aComponents
    cSep = pathSeparator()
    cResult = ""
    for i = 1 to len(aComponents)
        cResult += aComponents[i]
        if i < len(aComponents)
            cResult += cSep
        ok
    next
    return cResult

# Create directory
func mkDir cFolder
	if isWindows()
		cFolder = substr(cFolder, "/", "\")
		return system('mkdir "' + cFolder + '" > NUL 2>&1')
	else
		return system('mkdir -p "' + cFolder + '" > /dev/null 2>&1')
	ok

# Remove directory recursively (with a sanity guard)
func rmrf cPath
    # Refuse empty/root/relative-dangerous paths and traversal segments
    if len(cPath) < 2 or cPath = "/" or cPath = ".."
        return 0
    ok
    # Reject "." and "./" - they resolve to CWD and would delete the project
    cNorm = subStr(cPath, char(92), "/")
    cStripped = cNorm
    while left(cStripped, 2) = "./" and len(cStripped) > 2
        cStripped = subStr(cStripped, 3)
    end
    if cStripped = "." or cStripped = "./"
        return 0
    ok
    if isWindows() and len(cPath) = 3 and right(cPath, 2) = ":\"
        return 0
    ok
    # Reject any ".." path segment (handles "build/..", "a/../b", "..\x")
    if pathHasTraversal(cPath)
        return 0
    ok
    if isWindows()
        cPath = substr(cPath, "/", "\")
        return shellSilent('rmdir /s /q "' + cPath + '" 2>NUL')
    else
        return shellSilent('rm -rf "' + cPath + '"')
    ok

# Copy file
func copyFile cSrc, cDest
    if isWindows()
        cSrc = substr(cSrc, "/", "\")
        cDest = substr(cDest, "/", "\")
        return shellSilent('copy /y "' + cSrc + '" "' + cDest + '"')
    else
        return shellSilent('cp "' + cSrc + '" "' + cDest + '"')
    ok

# Copy directory recursively
func copyDir cSrc, cDest
    if isWindows()
        cSrc = substr(cSrc, "/", "\")
        cDest = substr(cDest, "/", "\")
        return shellSilent('xcopy /e /i /y "' + cSrc + '" "' + cDest + '"')
    else
        return shellSilent('cp -r "' + cSrc + "/." + '" "' + cDest + '"')
    ok


# True if cPath contains a ".." segment (rejects "build/..", "a/../b", "..\x")
func pathHasTraversal cPath
    # Normalize separators to "/" so one scan covers both platforms
    cNorm = subStr(cPath, char(92), "/")
    nPos = subStr(cNorm, "/..")
    if nPos > 0
        return true
    ok
    # Leading ".." with no separator (exact or "..\x")
    if left(cNorm, 2) = ".."
        return true
    ok
    return false
