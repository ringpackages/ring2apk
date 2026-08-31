# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    run command for Ring2APK
    Build, install, and run APK on connected device
*/

# Execute run command
func cmdRun aArgs
    cDevice = ""
    lRelease = false
    lNoLogcat = false
    lRebuild = false
    
    # Parse arguments
    for cArg in aArgs
        if left(cArg, 9) = "--device="
            cDevice = subStr(cArg, 10)
        but cArg = "--release"
            lRelease = true
        but cArg = "--no-logcat"
            lNoLogcat = true
        but cArg = "--rebuild"
            lRebuild = true
        ok
    next
    
    logInfo("Building and running app...")
    
    # Check environment
    oEnv = detectEnvironment()
    if not isEnvironmentReady(oEnv)
        logError("Build environment not ready!")
        printEnvironment(oEnv)
        shutdown(1)
    ok
    
    # Check for connected device
    if not hasConnectedDevice(oEnv.adb)
        ? "Connect a device via USB or start an emulator."
        fail("No device connected!")
    ok
    
    # Build first (skips when APK exists unless --rebuild)
    aBuildArgs = []
    if lRelease
        aBuildArgs + "--release"
    ok
    if lRebuild
        aBuildArgs + "--rebuild"
    ok
    cmdBuild(aBuildArgs)
    
    # Load config to get package name and APK path
    oConfig = loadConfig("ring2apk.ring")
    if isNull(oConfig)
        fail("Configuration could not be loaded")
    ok
    
    cApkName = oConfig[:name]
    if lRelease
        cApkName += "-release"
    else
        cApkName += "-debug"
    ok
    cApkPath = oConfig[:outputDir] + "/" + cApkName + ".apk"
    
    if not fExists(cApkPath)
        fail("APK not found: " + cApkPath)
    ok
    
    # Install APK
    logStep("Install", "Installing APK on device...")
    if not installApk(oEnv.adb, cApkPath, cDevice)
        fail("Installation failed!")
    ok
    
    # Launch app
    logStep("Launch", "Starting application...")
    if not launchApp(oEnv.adb, oConfig[:packageId], cDevice)
        fail("Failed to launch app!")
    ok
    
    logSuccess("App launched successfully!")
    
    # Follow logcat unless disabled
    if not lNoLogcat
        ? "Press Ctrl+C to stop logcat..."
        followLogcat(oEnv.adb, oConfig[:packageId], cDevice)
    ok

# Check if device is connected
func hasConnectedDevice cAdb
    cOutput = shellOutput('"' + cAdb + '" devices')
    aLines = str2List(cOutput)
    
    # Skip first line (header) and look for devices
    for i = 2 to len(aLines)
        cLine = trim(aLines[i])
        if len(cLine) > 0 and subStr(cLine, "device") > 0
            return true
        ok
    next
    
    return false

# Get list of connected devices
func getConnectedDevices cAdb
    aDevices = []
    cOutput = shellOutput('"' + cAdb + '" devices')
    aLines = str2List(cOutput)
    
    for i = 2 to len(aLines)
        cLine = trim(aLines[i])
        if len(cLine) > 0
            # Parse "serial\tstate"
            nTab = subStr(cLine, char(9))  # Tab character
            if nTab > 0
                cSerial = left(cLine, nTab - 1)
                cState = subStr(cLine, nTab + 1)
                if trim(cState) = "device"
                    aDevices + cSerial
                ok
            ok
        ok
    next
    
    return aDevices

# Install APK on device
func installApk cAdb, cApkPath, cDevice
    cCmd = '"' + cAdb + '"'

    if len(cDevice) > 0
        cCmd += ' -s ' + cDevice
    ok

    cCmd += ' install -r "' + cApkPath + '"'

    cErrFile = tempName() + ".txt"
    nResult = shellExec(cCmd + ' 2> "' + cErrFile + '"')
    if nResult != 0
        cErr = ""
        if fExists(cErrFile)
            cErr = trim(read(cErrFile))
        ok
        if len(cErr) > 0
            logError(cErr)
        ok
        return false
    ok
    if fExists(cErrFile)
        remove(cErrFile)
    ok
    return true

# Launch the app
func launchApp cAdb, cPackage, cDevice
    # Prefer the activity declared in the project manifest (NativeActivity,
    # MainActivity, ...)
    cActivity = findLaunchActivity(cPackage, "AndroidManifest.xml")
    
    # Normalize the activity name
    if left(cActivity, 1) = "."
        cActivity = cPackage + cActivity
    but subStr(cActivity, ".") = 0
        cActivity = cPackage + "." + cActivity
    ok
    
    cCmd = '"' + cAdb + '"'
    
    if len(cDevice) > 0
        cCmd += ' -s ' + cDevice
    ok
    
    # Try the manifest activity, then fall back to common defaults
    cCmd += ' shell am start -n ' + cPackage + '/' + cActivity
    if shellSilent(cCmd) = 0
        return true
    ok
    
    cCmd = '"' + cAdb + '"'
    if len(cDevice) > 0
        cCmd += ' -s ' + cDevice
    ok
    cCmd += ' shell am start -n ' + cPackage + '/' + cPackage + '.MainActivity'
    return shellSilent(cCmd) = 0

# Extract the main launcher activity name from AndroidManifest.xml
func findLaunchActivity cPackage, cManifestPath
    # Mirror the generated-manifest rule: no Java sources -> NativeActivity,
    # with src/java/*.java -> <package>.MainActivity
    cFallback = "android.app.NativeActivity"
    if hasJavaSources("src/java")
        cFallback = cPackage + ".MainActivity"
    ok

    if not fExists(cManifestPath)
        return cFallback
    ok

    cContent = read(cManifestPath)
    nMax = len(cContent)
    nPos = 1

    while nPos > 0 and nPos <= nMax
        nAct = subString(cContent, "<activity", nPos)
        if nAct = 0
            exit
        ok

        # Skip <activity-alias and similar: the char after "<activity"
        # must be whitespace, ">" or "/"
        cNext = subStr(cContent, nAct + len("<activity"), 1)
        if cNext != " " and cNext != ">" and cNext != "/" and
           cNext != nl and cNext != char(9) and cNext != char(13)
            nPos = nAct + len("<activity")
            loop
        ok

        # Find the end of the opening tag: the first ">" after "<activity".
        # If that ">" is part of "/>", the element is self-closing.
        nTagEnd = subString(cContent, ">", nAct)
        if nTagEnd = 0
            exit
        ok

        if nTagEnd > 1 and subStr(cContent, nTagEnd - 1, 1) = "/"
            # Self-closing <activity .../>: the element is just the opener
            nElemEnd = nTagEnd
        else
            # Regular element: extend to the matching </activity>
            nClose = subString(cContent, "</activity>", nTagEnd)
            if nClose = 0
                exit
            ok
            nElemEnd = nClose + len("</activity>") - 1
        ok

        cElem = subStr(cContent, nAct, nElemEnd - nAct + 1)

        if subStr(cElem, "android.intent.action.MAIN") > 0
            nNamePos = subStr(cElem, 'android:name="')
            if nNamePos > 0
                nStart = nNamePos + len('android:name="')
                cValue = subStr(cElem, nStart)
                nEndQuote = subStr(cValue, '"')
                if nEndQuote > 0
                    cActivity = subStr(cValue, 1, nEndQuote - 1)
                    if len(cActivity) > 0
                        return cActivity
                    ok
                ok
            ok
        ok

        nPos = nElemEnd + 1
    end

    return cFallback

# Follow logcat output for the app
func followLogcat cAdb, cPackage, cDevice
    # Device serial flag, reused for every adb invocation below
    cDevFlag = ""
    if len(cDevice) > 0
        cDevFlag = ' -s ' + cDevice
    ok

    # Resolve the app PID first
    cPidCmd = '"' + cAdb + '"' + cDevFlag + ' shell pidof -s ' + cPackage
    cPid = trim(shellOutput(cPidCmd))

    cCmd = '"' + cAdb + '"' + cDevFlag
    if len(cPid) > 0
        cCmd += ' logcat --pid=' + cPid
    else
        if isWindows()
            cCmd += ' logcat | findstr /i "' + cPackage + '"'
        else
            cCmd += ' logcat | grep -i "' + cPackage + '"'
        ok
    ok

    shellExec(cCmd)

# Uninstall app from device
func uninstallApp cAdb, cPackage, cDevice
    cCmd = '"' + cAdb + '"'
    
    if len(cDevice) > 0
        cCmd += ' -s ' + cDevice
    ok
    
    cCmd += ' uninstall ' + cPackage
    
    return shellSilent(cCmd) = 0
