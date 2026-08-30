# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

load "stdlibcore.ring"
load "libcurl.ring"
load "src/utils/json.ring"
load "src/utils/colors.ring"

func main
	cRepoUser = "ysdragon"
	cRepoName = "ring2apk"
	cReleaseApiUrl = "https://api.github.com/repos/" + cRepoUser + "/" + cRepoName + "/releases/latest"

	# Cleanup tracking
	cSavePath = ""
	cTempDir = ""

	logInfo("Starting installation for " + cRepoName + "...")

	# Detect OS
	cOS = ""
	cArch = getArch()
	
	switch true
		on isWindows() cOS = "windows"
		on isLinux()   cOS = "linux"
		on isMacOSX()  cOS = "macos"
		on isFreeBSD() cOS = "freebsd"
		other
			failure("Unsupported operating system detected!", cSavePath, cTempDir)
	off

	logInfo("Detected System: " + cOS + " (" + cArch + ")")

	# Fetch Latest Release Information
	logInfo("Fetching latest release info from GitHub...")
	
	curl = curl_easy_init()
	curl_easy_setopt(curl, CURLOPT_URL, cReleaseApiUrl)
	curl_easy_setopt(curl, CURLOPT_USERAGENT, "ring2apk Install Script")
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1)

	if cOS = "windows"
		curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0)
	ok

	cJsonResponse = curl_easy_perform_silent(curl)
	curl_easy_cleanup(curl)

	if len(cJsonResponse) < 10
		failure("Failed to retrieve release information.", cSavePath, cTempDir)
	ok

	# Parse JSON
	try
		oResponse = json_parse(cJsonResponse)
	catch
		failure("Failed to parse GitHub response.", cSavePath, cTempDir)
	done

	if not json_isobject(oResponse)
		failure("Invalid JSON response format.", cSavePath, cTempDir)
	ok

	aAssets = oResponse.getValue("assets")

	if len(aAssets) = 0
		failure("No assets found in the latest release.", cSavePath, cTempDir)
	ok

	cDownloadUrl = ""
	cFileName = ""
	cTargetSearch = ""

	# Determine target naming
	if cOS = "windows"
		if cArch = "x64" cTargetSearch = "windows-amd64"
		but cArch = "x86" cTargetSearch = "windows-i386"
		but cArch = "arm64" cTargetSearch = "windows-arm64" ok
	but cOS = "linux"
		if cArch = "x64" cTargetSearch = "linux-amd64"
		but cArch = "arm64" cTargetSearch = "linux-arm64" ok
	but cOS = "macos"
		if cArch = "x64" cTargetSearch = "macos-amd64"
		but cArch = "arm64" cTargetSearch = "macos-arm64" ok
	but cOS = "freebsd"
		if cArch = "x64" cTargetSearch = "freebsd-amd64" ok
	else
		failure("Unsupported architecture detected!", cSavePath, cTempDir)
	ok

	for asset in aAssets
		cName = asset.getValue("name")
		cUrl = asset.getValue("browser_download_url")
		if substr(cName, cTargetSearch) = 0
			continue
		ok
		cFileName = cName
		cDownloadUrl = cUrl
		exit
	next

	if isNull(cDownloadUrl)
		failure("No match found for " + cTargetSearch, cSavePath, cTempDir)
	ok

	logInfo("Downloading from: " + cDownloadUrl)

	curl = curl_easy_init()
	curl_easy_setopt(curl, CURLOPT_URL, cDownloadUrl)
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1)
	curl_easy_setopt(curl, CURLOPT_USERAGENT, "ring2apk installer")
	curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 1)

	if cOS = "windows"
		curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0)
	ok

	cContent = curl_easy_perform_silent(curl)
	curl_easy_cleanup(curl)

	if len(cContent) = 0
		failure("Download failed (empty response).", cSavePath, cTempDir)
	ok

	if cOS = "windows"
		cSavePath = exefolder() + "ring2apk.exe"
	else
		cSavePath = exefolder() + "ring2apk"
	ok

	write(cSavePath, cContent)

	if not fexists(cSavePath)
		failure("Download failed (write error).", cSavePath, cTempDir)
	ok

	if cOS != "windows"
		systemSilent('chmod +x "' + cSavePath + '"')
	ok

	logSuccess("Download complete.")

	# Create symlink for Linux/macOS/FreeBSD
	if cOS != "windows"
		if cOS = "macos"
			cDestDir = "/usr/local/bin"
		but cOS = "linux"
			cDestDir = "/usr/bin"
		but cOS = "freebsd"
			cDestDir = "/usr/local/bin"
		ok

		logInfo("Creating symlink for ring2apk...")
		runPrivileged('ln -sf "' + cSavePath + '" "' + cDestDir + '"')
	ok

	cleanup(cTempDir, NULL)
	logSuccess("Installation finished successfully.")

func failure cMsg, cSavePath, cTempDir
	logError(cMsg)
	cleanup(cTempDir, cSavePath)
	shutdown(1)

func cleanup cTempDir, cSavePath
	if not isNull(cTempDir) and fexists(cTempDir)
		if isWindows()
			systemSilent("rmdir /s /q " + cTempDir)
		else
			systemSilent("rm -rf " + cTempDir)
		ok
	ok
	if not isNull(cSavePath) and fexists(cSavePath)
		remove(cSavePath)
	ok

func runPrivileged cCmd
	cFinalCmd = 'which sudo >/dev/null 2>&1 && sudo ' + cCmd + 
			' || (which doas >/dev/null 2>&1 && doas ' + cCmd + 
			' || ' + cCmd + ')'
	system(cFinalCmd)