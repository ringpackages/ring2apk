/*
    setup-env — interactive Android toolchain installer for Ring2APK.

    Installs one or more of: JDK, Android SDK (cmdline-tools, platform-tools,
    platforms, build-tools), Android NDK, CMake — then writes the environment
    variables ring2apk needs (JAVA_HOME, ANDROID_HOME, ANDROID_SDK_ROOT,
    ANDROID_NDK_ROOT, PATH).

    Usage:  cd tools && ring setup-env.ring
            ring setup-env.ring --noninteractive
            ring setup-env.ring --root=/path/to/sdk

    Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
                    All rights reserved.
*/

# Load the Ring Standard Library
load "stdlibcore.ring"

# Load Ring HTML Extension
load "html.ring"

# Load Ring LibCurl Extension
load "libcurl.ring"

# Load Ring Archive Extension
load "archive.ring"

# Load Ring2APK utilities
load "../src/utils/colors.ring"
load "../src/utils/shell.ring"
load "../src/utils/json.ring"
load "../src/environment.ring"

# State
$RING2APK_VERBOSE = false
$ROOT = ""
$HOST = ""
$ARCH = ""
$REPO_XML = "https://dl.google.com/android/repository/repository2-3.xml"
$REPO_URL = "https://dl.google.com/android/repository/"
$ZULU_API = "https://api.azul.com/metadata/v1/zulu/packages/"
$DL = ""
$DONE = 0
$TOTAL = 0
$LAST_PCT = -1
$AUTO = false
$DL_FP = 0
$DID_PKG = false
$DID_JDK = false
$DID_SDK = false
$DID_NDK = false
$DID_CMAKE = false
$OLD_JAVA_HOME = ""
$OLD_ANDROID_HOME = ""
$OLD_ANDROID_SDK_ROOT = ""
$OLD_ANDROID_NDK_ROOT = ""
$OLD_NDK_HOME = ""
$OLD_CMAKE_HOME = ""

func main
    lAuto = false
    for x in sysargv
        if left(x, 6) = "--root" and substr(x, "=") > 0
            $ROOT = substr(x, substr(x, "=") + 1)
        ok
        if x = "--noninteractive"
            lAuto = true
        ok
    next
    $AUTO = lAuto

    # Snapshot inherited values: setWindowsEnv must not clobber
    # pre-existing variables for components this run didn't install.
    $OLD_JAVA_HOME = sysGet("JAVA_HOME")
    $OLD_ANDROID_HOME = sysGet("ANDROID_HOME")
    $OLD_ANDROID_SDK_ROOT = sysGet("ANDROID_SDK_ROOT")
    $OLD_ANDROID_NDK_ROOT = sysGet("ANDROID_NDK_ROOT")
    $OLD_NDK_HOME = sysGet("NDK_HOME")
    $OLD_CMAKE_HOME = sysGet("CMAKE_HOME")

    if len(sysGet("RING2APK_REPO_XML")) > 0
        $REPO_XML = sysGet("RING2APK_REPO_XML")
    ok
    if len(sysGet("RING2APK_ZULU_API")) > 0
        $ZULU_API = sysGet("RING2APK_ZULU_API")
    ok

    if isWindows()
        $HOST = "windows"
    but isMacOSX()
        $HOST = "macosx"
    else
        $HOST = "linux"
    ok
    $ARCH = getArch()

    if len($ROOT) = 0
        # reuse an existing SDK if one is already on this machine
        cDetected = detectAndroidSdk()
        if len(cDetected) > 0
            $ROOT = cDetected
        else
            $ROOT = defaultRoot()
        ok
    ok
    ? COLOR_BOLD + "Ring2APK toolchain setup" + COLOR_RESET + " — " + $HOST + " / " + $ARCH
    ? "Install root: " + FG_CYAN + $ROOT + COLOR_RESET
    ? ""
    showStatus()
    ? ""
    $DL = $ROOT + pathSeparator() + "downloads"
    mkDir($DL)

    if lAuto
        runAll()
        setEnvVars()
        ? "Done. Restart your shell (or source ~/.profile) for new PATH."
        return
    ok

    while true
        ? FG_CYAN + "What would you like to install?" + COLOR_RESET
        ? "    " + FG_GREEN + "1" + COLOR_RESET + "   JDK (Azul Zulu)"
        ? "    " + FG_GREEN + "2" + COLOR_RESET + "   Android SDK (cmdline-tools, platform-tools, platforms, build-tools)"
        ? "    " + FG_GREEN + "3" + COLOR_RESET + "   Android NDK"
        ? "    " + FG_GREEN + "4" + COLOR_RESET + "   CMake"
        ? "    " + FG_GREEN + "a" + COLOR_RESET + "   All (recommended defaults)"
        ? "    " + FG_GREEN + "e" + COLOR_RESET + "   Set environment variables"
        ? "    " + FG_GREEN + "0" + COLOR_RESET + "   Exit"
        see "Your choice: "
        cChoice = fReadLine(stdin)
        if cLineEof(cChoice)
            # stdin closed — stop instead of looping forever
            ? "Bye."
            return
        ok
        cChoice = lower(trim(cChoice))
        if len(cChoice) = 0
            # bare Enter = recommended default (1 — JDK)
            cChoice = "1"
        ok
        switch "x" + cChoice
        on "x1"
            installJdk()
        on "x2"
            installSdk()
        on "x3"
            installNdk()
        on "x4"
            installCmake()
        on "xa"
            runAll()
            setEnvVars()
        on "xe"
            setEnvVars()
        on "x0"
            ? "Bye."
            return
        other
            ? FG_RED + "Pick a number from the menu." + COLOR_RESET
        off
    end

# Report what is already installed (uses ring2apk's own detectors)
func showStatus
    cJava = detectJavaHome()
    cSdk = detectAndroidSdk()
    cNdk = ""
    cCmake = ""
    if len(cSdk) > 0
        cNdk = detectAndroidNdk(cSdk)
        cCmake = getCMake(cSdk)
    ok
    # our own Zulu installs count even without an exported JAVA_HOME yet
    if len(cJava) = 0
        cJdkDir = $ROOT + pathSeparator() + "jdk"
        if dirExists(cJdkDir)
            aJ = topEntries(cJdkDir)
            if len(aJ) > 0
                cJava = aJ[1] + "  (run: e → writes JAVA_HOME)"
            ok
        ok
    ok
    ? FG_CYAN + "Detected:" + COLOR_RESET
    printDetected("JDK", cJava)
    printDetected("Android SDK", cSdk)
    printDetected("Android NDK", cNdk)
    printDetected("CMake", cCmake)

func printDetected cName, cPath
    if len(cPath) > 0
        ? "  " + FG_GREEN + "[OK]" + COLOR_RESET + " " + cName + ": " + cPath
    else
        ? "  " + FG_RED + "[ X ]" + COLOR_RESET + " " + cName + ": not found"
    ok

func runAll
    installJdk()
    installSdk()
    installNdk()
    installCmake()

/* ------------------------------------------------------------------ */
/*  Version picker: numbered list, return chosen index (0 = skip)     */
/* ------------------------------------------------------------------ */
func pick aItems, cTitle
    n = len(aItems)
    if n = 0
        ? FG_RED + "No items found." + COLOR_RESET
        return 0
    ok
    if $AUTO
        return 1
    ok
    ? COLOR_BOLD + cTitle + COLOR_RESET
    for i = 1 to n
        cDetail = ""
        if len(aItems[i]) > 1
            cDetail = "  (" + aItems[i][2] + ")"
        ok
        ? "    " + FG_GREEN + i + COLOR_RESET + ". " + aItems[i][1] + cDetail
    next
    ? "    " + FG_GREEN + "0" + COLOR_RESET + ". Skip"
    while true
        see "Pick a number [1-" + n + "] (enter = 1): "
        cLine = fReadLine(stdin)
        if cLineEof(cLine)
            # stdin closed
            return 0
        ok
        cLine = trim(cLine)
        if len(cLine) = 0
            return 1
        ok
        nPick = toNum(cLine)
        if nPick = 0
            return 0
        ok
        if nPick >= 1 and nPick <= n
            return nPick
        ok
        ? FG_RED + "Pick a number between 1 and " + n + " (or 0 to skip)." + COLOR_RESET
    end

/* ------------------------------------------------------------------ */
/*  JDK — Azul Zulu metadata API (live list, one build per major)     */
/* ------------------------------------------------------------------ */
func installJdk
    cOs = "linux"
    if isWindows()
        cOs = "windows"
    but isMacOSX()
        cOs = "macosx"
    ok
    cArch = "x64"
    if $ARCH = "aarch64"
        cArch = "aarch64"
    but $ARCH = "x86"
        cArch = "x86"
    ok
    cType = "tar.gz"
    if isWindows()
        cType = "zip"
    ok
    cUrl = $ZULU_API + "?java_package_type=jdk&javafx_bundled=false&os=" + cOs +
           "&arch=" + cArch + "&archive_type=" + cType + "&latest=true"
    logInfo("Fetching available JDK versions from Azul...")
    cJson = httpGet(cUrl)
    if len(cJson) = 0
        return
    ok
    oList = json_parse(cJson)
    if type(oList) != "LIST"
        logError("Unexpected JDK metadata reply.")
        return
    ok

    aRows = []
    aSeen = []
    for o in oList
        cName = o.getValue("name")
        if substr(cName, "crac") > 0 or substr(cName, "musl") > 0
            loop
        ok
        v = o.getValue("java_version")
        nMajor = 0
        if type(v) = "LIST" and len(v) > 0
            nMajor = toNum(v[1])
        ok
        if find(aSeen, nMajor) > 0
            loop
        ok
        aSeen + nMajor
        add(aRows, [o.getValue("download_url"), cName, nMajor])
    next
    if len(aRows) = 0
        logError("No JDK builds found for " + cOs + "/" + cArch)
        return
    ok

    # sort by major descending
    for i = 2 to len(aRows)
        x = aRows[i]
        j = i - 1
        while j >= 1 and aRows[j][3] < x[3]
            aRows[j + 1] = aRows[j]
            j = j - 1
        end
        aRows[j + 1] = x
    next

    aLabels = []
    for r in aRows
        cMark = ""
        cBase = fileOf(r[1])
        cBase = substr(cBase, ".tar.gz", "")
        cBase = substr(cBase, ".zip", "")
        if dirExists($ROOT + pathSeparator() + "jdk" + pathSeparator() + cBase)
            cMark = FG_YELLOW + " [installed]" + COLOR_RESET
        ok
        add(aLabels, ["JDK " + r[3] + " — " + r[2] + cMark, "major " + r[3]])
    next
    nPick = pick(aLabels, "Available JDK builds")
    if nPick = 0
        return
    ok

    cJdkDir = $ROOT + pathSeparator() + "jdk"
    mkDir(cJdkDir)
    cBase = fileOf(aRows[nPick][1])
    cBase = substr(cBase, ".tar.gz", "")
    cBase = substr(cBase, ".zip", "")
    if not confirmReinstall(cJdkDir + pathSeparator() + cBase)
        return
    ok
    cArchive = download(aRows[nPick][1], "jdk")
    cTemp = $DL + pathSeparator() + "stage-jdk"
    rmrf(cTemp)
    mkDir(cTemp)
    logStep("Extract", "Unpacking JDK...")
    archive_extract(cArchive, cTemp)
    aTop = topEntries(cTemp)
    if len(aTop) != 1
        logError("Unexpected JDK archive layout.")
        return
    ok
    cDest = cJdkDir + pathSeparator() + fileOf(aTop[1])
    rmrf(cDest)
    rename(aTop[1], cDest)
    rmrf(cTemp)
    makeExecutable(cDest)
    $DID_JDK = true
    setVar("JAVA_HOME", cDest)
    logSuccess("JDK installed to " + cDest)

/* ----------------------------------------------------------------------- */
/*  Android SDK: cmdline-tools + platform-tools + platforms + build-tools  */
/* ----------------------------------------------------------------------- */
func installSdk
    $DID_PKG = false
    cXml = repoXml()
    if len(cXml) = 0
        return
    ok

    aPkgs = repoPackages(cXml, "cmdline-tools")
    if len(aPkgs) > 0
        aLabels = []
        for p in aPkgs
            cM = installedTag(sdkDestFor(p[1], p[2], true))
            add(aLabels, [p[2], p[3] + "  " + humanSize(p[5]) + cM])
        next
        nPick = pick(aLabels, "Choose Android SDK command-line tools")
        if nPick > 0
            installRepoPkg(aPkgs[nPick], true)
        ok
    ok

    aPkgs = repoPackages(cXml, "build-tools")
    if len(aPkgs) > 0
        aLabels = []
        for p in aPkgs
            cM = installedTag(sdkDestFor(p[1], p[2], false))
            add(aLabels, [p[2], p[3] + "  " + humanSize(p[5]) + cM])
        next
        nPick = pick(aLabels, "Choose Android SDK build-tools")
        if nPick > 0
            installRepoPkg(aPkgs[nPick], false)
        ok
    ok

    aPkgs = repoPackages(cXml, "platforms")
    if len(aPkgs) > 0
        aLabels = []
        for p in aPkgs
            cV = p[2]
            if left(cV, 8) = "android-"
                cV = substr(cV, 9)
            ok
            cM = installedTag(sdkDestFor(p[1], p[2], false))
            add(aLabels, ["android-" + cV, p[3] + "  " + humanSize(p[5]) + cM])
        next
        nPick = pick(aLabels, "Choose Android SDK platform")
        if nPick > 0
            installRepoPkg(aPkgs[nPick], false)
        ok
    ok

    aPkgs = repoPackages(cXml, "platform-tools")
    if len(aPkgs) > 0
        aLabels = []
        for p in aPkgs
            cM = installedTag(sdkDestFor(p[1], p[2], false))
            add(aLabels, [p[2], p[3] + "  " + humanSize(p[5]) + cM])
        next
        nPick = pick(aLabels, "Install platform-tools (adb)")
        if nPick > 0
            installRepoPkg(aPkgs[nPick], false)
        ok
    ok

    setVar("ANDROID_HOME", $ROOT)
    setVar("ANDROID_SDK_ROOT", $ROOT)
    if $DID_PKG
        $DID_SDK = true
    ok
    logSuccess("Android SDK is set up at " + $ROOT)

/* ------------------------------------------------------------------ */
/*  NDK                                                               */
/* ------------------------------------------------------------------ */
func installNdk
    $DID_PKG = false
    cXml = repoXml()
    if len(cXml) = 0
        return
    ok
    aPkgs = repoPackages(cXml, "ndk")
    if len(aPkgs) = 0
        logError("No NDK packages found.")
        return
    ok
    aLabels = []
    for p in aPkgs
        cM = installedTag(sdkDestFor(p[1], p[2], false))
        add(aLabels, [p[2], p[3] + "  " + humanSize(p[5]) + cM])
    next
    nPick = pick(aLabels, "Choose Android NDK version")
    if nPick = 0
        return
    ok
    installRepoPkg(aPkgs[nPick], false)
    cNdk = $ROOT + pathSeparator() + "ndk" + pathSeparator() + aPkgs[nPick][2]
    setVar("ANDROID_NDK_ROOT", cNdk)
    setVar("NDK_HOME", cNdk)
    if $DID_PKG
        $DID_NDK = true
    ok
    logSuccess("Android NDK installed to " + cNdk)

/* ------------------------------------------------------------------ */
/*  CMake                                                             */
/* ------------------------------------------------------------------ */
func installCmake
    $DID_PKG = false
    cXml = repoXml()
    if len(cXml) = 0
        return
    ok
    aPkgs = repoPackages(cXml, "cmake")
    if len(aPkgs) = 0
        logError("No CMake packages found.")
        return
    ok
    aLabels = []
    for p in aPkgs
        cM = installedTag(sdkDestFor(p[1], p[2], false))
        add(aLabels, [p[2], p[3] + "  " + humanSize(p[5]) + cM])
    next
    nPick = pick(aLabels, "Choose CMake version")
    if nPick = 0
        return
    ok
    installRepoPkg(aPkgs[nPick], false)
    cCmake = $ROOT + pathSeparator() + "cmake" + pathSeparator() + aPkgs[nPick][2] + pathSeparator() + "bin"
    setVar("CMAKE_HOME", cCmake)
    if $DID_PKG
        $DID_CMAKE = true
    ok
    logSuccess("CMake installed to " + cCmake)

/* ------------------------------------------------------------------ */
/*  Fetch the Android repo XML (live, once per run)                   */
/* ------------------------------------------------------------------ */
func repoXml
    logInfo("Fetching Google Android repository...")
    return httpGet($REPO_XML)

/* ------------------------------------------------------------------ */
/*  Parse remotePackage entries for a path prefix.                    */
/*  Returns rows sorted by version descending:                        */
/*     [cPath, cVersion, cDisplayName, cUrl, nSize]                   */
/* ------------------------------------------------------------------ */
func repoPackages cXml, cPrefix
    oDoc = new html(cXml)
    aAll = oDoc.find("remotePackage")
    aRows = []
    for o in aAll
        cPath = o.attr("path")
        if substr(cPath, cPrefix) = 0
            loop
        ok
        # version = the "slug" after the last ';'
        nSemi = 0
        for i = len(cPath) to 1 step -1
            if cPath[i] = ";"
                nSemi = i
                exit
            ok
        next
        if nSemi = 0
            cVersion = "latest"
        else
            cVersion = substr(cPath, nSemi + 1)
        ok
        if substr(cVersion, "-alpha") > 0 or substr(cVersion, "-beta") > 0 or
           substr(cVersion, "-rc") > 0 or substr(cVersion, "-ext") > 0
            loop
        ok

        cDisplay = ""
        aDn = o.find("display-name")
        if len(aDn) > 0
            cDisplay = aDn[1].text()
        ok

        # archive matching this host, or host-independent
        cUrl = ""
        nSize = 0
        aArchs = o.find("archive")
        for a in aArchs
            aOs = a.find("host-os")
            if len(aOs) > 0
                if lower(aOs[1].text()) != $HOST
                    loop
                ok
            ok
            aUrl = a.find("url")
            if len(aUrl) = 0
                loop
            ok
            aSz = a.find("size")
            nSize = 0
            if len(aSz) > 0
                nSize = toNum(aSz[1].text())
            ok
            cUrl = aUrl[1].text()
            exit
        next
        if len(cUrl) = 0
            loop
        ok
        if substr(cUrl, "http") = 0
            cUrl = $REPO_URL + cUrl
        ok
        if findCol(aRows, 1, cPath) = 0
            add(aRows, [cPath, cVersion, cDisplay, cUrl, nSize])
        ok
    next

    # sort by version descending
    for i = 2 to len(aRows)
        x = aRows[i]
        j = i - 1
        while j >= 1 and verCmp(aRows[j][2], x[2]) < 0
            aRows[j + 1] = aRows[j]
            j = j - 1
        end
        aRows[j + 1] = x
    next
    return aRows

/* ------------------------------------------------------------------ */
/*  Install one repo package: download, extract, move into root.      */
/* ------------------------------------------------------------------ */
func installRepoPkg aPkg, lCmdline
    cVersion = aPkg[2]
    cPath = aPkg[1]

        cDest = sdkDestFor(cPath, cVersion, lCmdline)
    if not confirmReinstall(cDest)
        return
    ok

    cArchive = download(aPkg[4], "pkg")

    cTemp = $DL + pathSeparator() + "stage-pkg"
    rmrf(cTemp)
    mkDir(cTemp)
    logStep("Extract", "Unpacking " + cVersion + "...")
    archive_extract(cArchive, cTemp)

    aTop = topEntries(cTemp)
    if len(aTop) = 0
        logError("Archive was empty.")
        return
    ok
    cSrc = aTop[1]
    if len(aTop) > 1
        cSrc = cTemp
    ok

    cParent = parentOf(cDest)
    mkDir(cParent)
    rmrf(cDest)
    if cSrc = cTemp
        # multi-entry archive: move everything in
        moveContents(cSrc, cDest)
    else
        moveIntoDir(cSrc, cDest)
    ok
    makeExecutable(cDest)
    # keep <root>/cmdline-tools/latest valid for sdkmanager & PATH
    if substr(cPath, "cmdline-tools") > 0
        cLatest = $ROOT + pathSeparator() + "cmdline-tools" + pathSeparator() + "latest"
        rmrf(cLatest)
        if isWindows()
            systemSilent('mklink /J "' + cLatest + '" "' + cDest + '" >NUL')
        else
            systemSilent('ln -sfn "' + cDest + '" "' + cLatest + '"')
        ok
        logInfo("cmdline-tools/latest -> " + cVersion)
    ok
    $DID_PKG = true

/* ------------------------------------------------------------------ */
/*  HTTP GET to string (libcurl), follow redirects, fail loudly       */
/* ------------------------------------------------------------------ */
func httpGet cUrl
    hCurl = curl_easy_init()
    curl_easy_setopt(hCurl, CURLOPT_URL, cUrl)
    curl_easy_setopt(hCurl, CURLOPT_FOLLOWLOCATION, 1)
    curl_easy_setopt(hCurl, CURLOPT_USERAGENT, "ring2apk-setup/1.0")
    curl_easy_setopt(hCurl, CURLOPT_CONNECTTIMEOUT, 30)
    curl_easy_setopt(hCurl, CURLOPT_LOW_SPEED_LIMIT, 100)
    curl_easy_setopt(hCurl, CURLOPT_LOW_SPEED_TIME, 30)
    if isWindows()
        # Windows libcurl uses Schannel; cert-store failures kill the transfer
        curl_easy_setopt(hCurl, CURLOPT_SSL_VERIFYPEER, 0)
    ok
    cOut = curl_easy_perform_silent(hCurl)
    nCode = curl_getResponseCode(hCurl)
    curl_easy_cleanup(hCurl)
    if nCode != 200 and nCode != 206
        logError("HTTP " + nCode + " fetching " + cUrl)
        return ""
    ok
    return cOut

/* ------------------------------------------------------------------ */
/*  Download to $DL with progress + resume. Returns final path.       */
/* ------------------------------------------------------------------ */
func download cUrl, cKind
    cBase = fileOf(cUrl)
    if len(cBase) = 0
        cBase = cKind + ".bin"
    ok
    cPart = $DL + pathSeparator() + cBase + ".part"
    cFinal = $DL + pathSeparator() + cBase

    logInfo("Downloading " + cBase + " ...")
    nAttempt = 0
    while nAttempt < 5
        nAttempt += 1
        resetProgress()
        nResume = 0
        if fExists(cPart)
            nResume = getFileSize(cPart)
        ok
        if curlDownload(cUrl, cPart, nResume)
            if fExists(cFinal)
                remove(cFinal)
            ok
            rename(cPart, cFinal)
            logSuccess("Downloaded " + humanSize(getFileSize(cFinal)))
            return cFinal
        ok
        logWarning("Download failed — retrying (" + nAttempt + "/5)...")
        syssleep(2000)
    end
    logError("Giving up on " + cUrl)
    shutdown(1)

func curlDownload cUrl, cPart, nResume
    cMode = "wb"
    if nResume > 0
        cMode = "ab"
    ok
    $DL_FP = fopen(cPart, cMode)
    if isNULL($DL_FP) or $DL_FP = 0
        return false
    ok
    hCurl = curl_easy_init()
    curl_easy_setopt(hCurl, CURLOPT_URL, cUrl)
    curl_easy_setopt(hCurl, CURLOPT_FOLLOWLOCATION, 1)
    curl_easy_setopt(hCurl, CURLOPT_USERAGENT, "ring2apk-setup/1.0")
    curl_easy_setopt(hCurl, CURLOPT_CONNECTTIMEOUT, 30)
    curl_easy_setopt(hCurl, CURLOPT_LOW_SPEED_LIMIT, 1024)
    curl_easy_setopt(hCurl, CURLOPT_LOW_SPEED_TIME, 60)
    if isWindows()
        # Windows libcurl uses Schannel; cert-store failures kill the transfer
        curl_easy_setopt(hCurl, CURLOPT_SSL_VERIFYPEER, 0)
    ok
    if nResume > 0
        curl_easy_setopt(hCurl, CURLOPT_RESUME_FROM, nResume)
    ok
    curl_easy_setopt(hCurl, CURLOPT_NOPROGRESS, 0)
    curl_easy_setopt(hCurl, CURLOPT_XFERINFOFUNCTION, "xferInfo")
    curl_easy_setopt(hCurl, CURLOPT_WRITEFUNCTION, "writeChunk")
    nRet = curl_easy_perform(hCurl)
    fclose($DL_FP)
    $DL_FP = 0
    curl_easy_cleanup(hCurl)
    if nRet = 0 and $TOTAL > 0
        ? ""
    ok
    return nRet = 0

func writeChunk
    cData = curl_get_data()
    fwrite($DL_FP, cData)
    return len(cData)

func resetProgress
	$LAST_PCT = -1

func xferInfo
	aInfo = curl_get_progress_info()
	$TOTAL = aInfo[1]
	$DONE = aInfo[2]
	if $TOTAL > 0
		nPct = 100 * $DONE / $TOTAL
		if nPct >= $LAST_PCT + 2 or $DONE = $TOTAL
			$LAST_PCT = nPct
			cBar = "["
			for i = 1 to 20
				if i <= nPct / 5
					cBar += "#"
				else
					cBar += "-"
				ok
			next
			cBar += "]"
			see char(13) + "   " + cBar + " " + left("" + nPct, 5) + "%  " +
				humanSize($DONE) + " / " + humanSize($TOTAL) + "        "
		ok
	ok
	curl_set_progress_result(0)

/* ------------------------------------------------------------------ */
/*  Environment variables                                             */
/* ------------------------------------------------------------------ */
func setEnvVars
    logInfo("Writing environment variables...")
    resolveEnvVars()
    if isWindows()
        setWindowsEnv()
    else
        setProfileEnv()
    ok
    logSuccess("Done.")

# Populate process env from installed state so the writers below see it
func resolveEnvVars
    if len(sysGet("JAVA_HOME")) = 0
        cJava = detectJavaHome()
        if len(cJava) = 0
            cJdkDir = $ROOT + pathSeparator() + "jdk"
            if dirExists(cJdkDir)
                aJ = topEntries(cJdkDir)
                if len(aJ) > 0
                    cJava = aJ[1]
                ok
            ok
        ok
        if len(cJava) > 0
            sysSet("JAVA_HOME", cJava)
        ok
    ok
    if len(sysGet("ANDROID_HOME")) = 0
        cSdk = detectAndroidSdk()
        if len(cSdk) = 0
            cSdk = $ROOT
        ok
        if dirExists(cSdk)
            sysSet("ANDROID_HOME", cSdk)
            sysSet("ANDROID_SDK_ROOT", cSdk)
        ok
    ok
    if len(sysGet("ANDROID_NDK_ROOT")) = 0
        cNdk = detectAndroidNdk(sysGet("ANDROID_HOME"))
        if len(cNdk) > 0
            sysSet("ANDROID_NDK_ROOT", cNdk)
            sysSet("NDK_HOME", cNdk)
        ok
    ok
    if len(sysGet("CMAKE_HOME")) = 0
        cCmake = getCMake(sysGet("ANDROID_HOME"))
        # getCMake returns the cmake EXE (or bare "cmake" from PATH);
        # CMAKE_HOME is the bin DIR (same convention installCmake writes).
        if right(lower(cCmake), 10) = "cmake.exe"
            cCmake = parentOf(cCmake)
        but right(lower(cCmake), 9) = "cmake" and not dirExists(cCmake)
            cCmake = ""
        ok
        if dirExists(cCmake)
            sysSet("CMAKE_HOME", cCmake)
        ok
    ok

# Windows: persistent user scope. Never clobber a pre-existing value
# unless this run installed that component (or nothing was set before).
func setWindowsEnv
    persistWinVar("JAVA_HOME", $OLD_JAVA_HOME, $DID_JDK)
    persistWinVar("ANDROID_HOME", $OLD_ANDROID_HOME, $DID_SDK)
    persistWinVar("ANDROID_SDK_ROOT", $OLD_ANDROID_SDK_ROOT, $DID_SDK)
    persistWinVar("ANDROID_NDK_ROOT", $OLD_ANDROID_NDK_ROOT, $DID_NDK)
    persistWinVar("NDK_HOME", $OLD_NDK_HOME, $DID_NDK)
    persistWinVar("CMAKE_HOME", $OLD_CMAKE_HOME, $DID_CMAKE)
    appendWindowsPath()

func persistWinVar cName, cOld, lInstalled
    cVal = sysGet(cName)
    if len(cVal) = 0
        return
    ok
    if len(cOld) > 0 and not lInstalled
        logInfo("Kept existing " + cName + " = " + cOld)
        return
    ok
    systemSilent('setx ' + cName + ' "' + cVal + '" >NUL')
    logStep("setx", cName + " = " + cVal)

# POSIX: managed marker block in ~/.profile
func setProfileEnv
    cHome = sysGet("HOME")
    if len(cHome) = 0
        cHome = sysGet("USERPROFILE")
    ok
    if len(cHome) = 0
        cHome = "."
    ok
    cProfile = cHome + pathSeparator() + ".profile"
    cBlock = buildEnvBlock()
    if len(cBlock) = 0
        logInfo("No new variables to write.")
        return
    ok
    upsertMarkerBlock(cProfile, cBlock)
    # interactive shells (ssh, new terminals) read .bashrc, not .profile
    cRc = cHome + pathSeparator() + ".bashrc"
    if fExists(cRc)
        upsertMarkerBlock(cRc, cBlock)
        logInfo("Updated " + cRc)
    ok
    logInfo("Restart your shell (or run: source " + cProfile + ") to apply.")

func appendWindowsPath
    cAdb = sysGet("ANDROID_HOME")
    cJava = sysGet("JAVA_HOME")
    cCmake = sysGet("CMAKE_HOME")
    aSegs = []
    if len(cAdb) > 0
        add(aSegs, cAdb + "\platform-tools")
        add(aSegs, cAdb + "\cmdline-tools\latest\bin")
    ok
    if len(cJava) > 0
        add(aSegs, cJava + "\bin")
    ok
    if len(cCmake) > 0
        add(aSegs, cCmake)
    ok
    if len(aSegs) = 0
        return
    ok
    # Read the *user* Path verbatim — including %VAR% segments. The old code
    # dropped %-segments and rewrote the value with setx (which also flips
    # REG_EXPAND_SZ to REG_SZ and truncates at 1024 chars).
    cCur = shellOutput('reg query "HKCU\Environment" /v Path 2>NUL')
    cOld = ""
    for line in split(cCur, nl)
        line = trim(line)
        if substr(line, "REG_EXPAND_SZ") > 0 or substr(line, "REG_SZ") > 0
            # "    Path    REG_EXPAND_SZ    C:\...;C:\..."
            nPos = 0
            if substr(line, "REG_EXPAND_SZ") > 0
                nPos = substr(line, "REG_EXPAND_SZ") + 13
            else
                nPos = substr(line, "REG_SZ") + 6
            ok
            if nPos < len(line)
                cOld = trim(substr(line, nPos))
            ok
            exit
        ok
    next
    # Append-only: existing segments (order, % refs) are never touched.
    # Our segments join only when missing and only when they are real
    # directories — never files (a past CMAKE_HOME bug put cmake.exe on PATH).
    cOut = cOld
    for s in aSegs
        if not dirExists(s)
            logWarning("Not added to PATH (missing dir): " + s)
            loop
        ok
        if findSeg(cOut, lower(s)) = 0
            if len(cOut) > 0
                cOut += ";"
            ok
            cOut += s
        ok
    next
    if cOut = cOld
        logInfo("PATH already up to date.")
        return cOut
    ok
    # Persist via PowerShell reading a temp file: the value never passes
    # through cmd's parser, so %VAR% segments survive verbatim (cmd would
    # expand defined vars and delete undefined ones; setx would also flip
    # REG_EXPAND_SZ to REG_SZ and truncate at 1024 chars). Proven against
    # live HKCU output: written value is byte-identical, type ExpandString.
    cTmp = $DL + pathSeparator() + "pathval.tmp"
    write(cTmp, cOut)
    sysSet("R2APK_PATHVAL", cTmp)
    q = char(39)
    if commandExists("powershell")
        systemSilent('powershell -c "Set-ItemProperty -Path ' + q + 'HKCU:\Environment' + q + ' -Name ' + q + 'Path' + q + ' -Value (Get-Content -Raw $env:R2APK_PATHVAL).Trim() -Type ExpandString"')
    else
        systemSilent('reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "' + cOut + '" /f >NUL')
    ok
    remove(cTmp)
    logStep("PATH", cOut)
    return cOut

func findSeg cPath, cKey
    for seg in split(cPath, ";")
        if lower(trim(seg)) = cKey
            return 1
        ok
    next
    return 0

func fReadLine fp
    cOut = ""
    while true
        c = fgetc(fp)
        if c = -1
            if len(cOut) = 0
                return 0
            ok
            exit
        ok
        if c = char(10)
            exit
        ok
        if c != char(13)
            cOut += c
        ok
    end
    return cOut

func cLineEof cLine
    return isnumber(cLine) and cLine = 0

/* ------------------------------------------------------------------ */
/*  Build the export block for ~/.profile (marker-wrapped)            */
/* ------------------------------------------------------------------ */
func buildEnvBlock
    cJava = sysGet("JAVA_HOME")
    cHome = sysGet("ANDROID_HOME")
    cSdk = sysGet("ANDROID_SDK_ROOT")
    cNdk = sysGet("ANDROID_NDK_ROOT")
    cCmake = sysGet("CMAKE_HOME")
    if len(cJava) = 0 and len(cHome) = 0 and len(cSdk) = 0 and
       len(cNdk) = 0 and len(cCmake) = 0
        return ""
    ok
    aLines = ["# === ring2apk environment (managed) ==="]
    if len(cJava) > 0
        add(aLines, 'export JAVA_HOME="' + cJava + '"')
    ok
    if len(cHome) > 0
        add(aLines, 'export ANDROID_HOME="' + cHome + '"')
    ok
    if len(cSdk) > 0
        add(aLines, 'export ANDROID_SDK_ROOT="' + cSdk + '"')
    ok
    if len(cNdk) > 0
        add(aLines, 'export ANDROID_NDK_ROOT="' + cNdk + '"')
        add(aLines, 'export NDK_HOME="' + cNdk + '"')
    ok
    if len(cCmake) > 0
        add(aLines, 'export CMAKE_HOME="' + cCmake + '"')
        add(aLines, 'export PATH="$CMAKE_HOME:$PATH"')
    ok
    if len(cHome) > 0
        add(aLines, 'export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"')
    ok
    add(aLines, "# === end ring2apk environment ===")
    cOut = ""
    for l in aLines
        cOut += l + nl
    next
    return cOut

/* replace an existing marker block, or append at the end */
func upsertMarkerBlock cFile, cBlock
    cEnd = "# === end ring2apk environment ==="
    cNew = ""
    if fExists(cFile)
        cNew = read(cFile)
        nS = substr(cNew, "# === ring2apk environment (managed) ===")
        if nS > 0
            nE = substr(cNew, cEnd)
            if nE > nS
                cNew = left(cNew, nS - 1) + substr(cNew, nE + len(cEnd))
            ok
        ok
    ok
    if len(cNew) > 0 and cNew[len(cNew)] != nl
        cNew += nl
    ok
    cNew += cBlock
    write(cFile, cNew)

/* ------------------------------------------------------------------ */
/*  Small helpers                                                     */
/* ------------------------------------------------------------------ */
func setVar cName, cVal
    sysSet(cName, cVal)
    logStep("set", cName + " = " + cVal)

func topEntries cDir
    aT = dir(cDir)
    aTop = []
    for e in aT
        if e[1] != "." and e[1] != ".."
            add(aTop, cDir + pathSeparator() + e[1])
        ok
    next
    return aTop

func moveContents cSrc, cDst
    mkDir(cDst)
    aT = dir(cSrc)
    for e in aT
        if e[1] != "." and e[1] != ".."
            moveIntoDir(cSrc + pathSeparator() + e[1], cDst + pathSeparator() + e[1])
        ok
    next

func moveIntoDir cSrc, cDst
    cParent = parentOf(cDst)
    mkDir(cParent)
    if dirExists(cDst) or fExists(cDst)
        rmrf(cDst)
    ok
    if isWindows()
        systemSilent('move /Y "' + cSrc + '" "' + cDst + '" >NUL')
    else
        systemSilent('mv "' + cSrc + '" "' + cDst + '"')
    ok

func parentOf cPath
    for i = len(cPath) to 1 step -1
        if cPath[i] = "/" or cPath[i] = char(92)
            return left(cPath, i - 1)
        ok
    next
    return "."

func fileOf cPath
    for i = len(cPath) to 1 step -1
        if cPath[i] = "/" or cPath[i] = char(92)
            return substr(cPath, i + 1)
        ok
    next
    return cPath

# destination directory for a repo package (single source of truth)
func sdkDestFor cPath, cVersion, lCmdline
    if lCmdline or substr(cPath, "cmdline-tools") > 0
        return $ROOT + pathSeparator() + "cmdline-tools" + pathSeparator() + cVersion
    but substr(cPath, "build-tools") > 0
        return $ROOT + pathSeparator() + "build-tools" + pathSeparator() + cVersion
    but substr(cPath, "platforms") > 0
        cPlatV = cVersion
        if left(cPlatV, 8) = "android-"
            cPlatV = substr(cPlatV, 9)
        ok
        return $ROOT + pathSeparator() + "platforms" + pathSeparator() + "android-" + cPlatV
    but substr(cPath, "ndk") > 0
        return $ROOT + pathSeparator() + "ndk" + pathSeparator() + cVersion
    but substr(cPath, "cmake") > 0
        return $ROOT + pathSeparator() + "cmake" + pathSeparator() + cVersion
    but substr(cPath, "platform-tools") > 0
        return $ROOT + pathSeparator() + "platform-tools"
    ok
    return $ROOT + pathSeparator() + cVersion

func installedTag cDest
    if dirExists(cDest)
        return FG_YELLOW + " [installed]" + COLOR_RESET
    ok
    return ""

func confirmReinstall cDest
    if not dirExists(cDest) or $AUTO
        return true
    ok
    ? FG_YELLOW + cDest + " already exists." + COLOR_RESET
    print("Reinstall (re-download & overwrite)? [y/N]: ")
    cLine = fReadLine(stdin)
    if cLineEof(cLine)
        return false
    ok
    return lower(trim(cLine)) = "y"

func makeExecutable cDir
    if isWindows()
        return
    ok
    # zip/tar member perms are not restored on extract — make everything runnable
    systemSilent('chmod -R a+x "' + cDir + '" 2>/dev/null')

func defaultRoot
    if isWindows()
        cHome = sysGet("USERPROFILE")
        if len(cHome) = 0
            return "C:\Android"
        ok
        return cHome + "\Android"
    ok
    cHome = sysGet("HOME")
    if len(cHome) = 0
        cHome = "."
    ok
    return cHome + "/Android"

# numeric compare tolerant of non-numeric version tokens ("latest", "1-rc2")
func verCmp cV1, cV2
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
			n1 = segNum(a1[i])
		ok
		if i <= len(a2)
			n2 = segNum(a2[i])
		ok
		if n1 > n2
			return 1
		but n1 < n2
			return -1
		ok
	next
	return 0

func findCol aRows, nCol, cVal
	for i = 1 to len(aRows)
		if aRows[i][nCol] = cVal
			return i
		ok
	next
	return 0

func toNum cStr
	if isnumber(cStr)
		return cStr + 0
	ok
	return segNum("" + cStr)

func segNum cSeg
	cD = ""
	for i = 1 to len(cSeg)
		if isdigit(cSeg[i])
			cD += cSeg[i]
		else
			exit
		ok
	next
	if len(cD) = 0
		return 0
	ok
	return 0 + cD

func humanSize nBytes
    if nBytes >= 1073741824
        return "" + (nBytes / 1073741824.0) + " GB"
    but nBytes >= 1048576
        return "" + (nBytes / 1048576.0) + " MB"
    but nBytes >= 1024
        return "" + (nBytes / 1024.0) + " KB"
    ok
    return "" + nBytes