# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

load "stdlibcore.ring"
load "src/utils/colors.ring"

func main
	cOS = ""

	if isWindows()
		cOS = "windows"
	but isLinux()
		cOS = "linux"
	but isMacOSX()
		cOS = "macos"
	but isFreeBSD()
		cOS = "freebsd"
	else
		logError("Unsupported operating system detected!")
		shutdown(1)
	ok

	logInfo("Uninstalling ring2apk...")

	if cOS = "windows"
		cBinPath = exefolder() + "ring2apk.exe"
		if fexists(cBinPath)
			remove(cBinPath)
			logSuccess("Removed " + cBinPath)
		else
			logWarning("Binary not found: " + cBinPath)
		ok
	else
		cBinPath = exefolder() + "ring2apk"
		cDestDir = ""
		if cOS = "macos"
			cDestDir = "/usr/local/bin"
		but cOS = "linux"
			cDestDir = "/usr/bin"
		but cOS = "freebsd"
			cDestDir = "/usr/local/bin"
		ok

		cLinkPath = cDestDir + "/ring2apk"

		# Remove symlink
		cFinalCmd = 'which sudo >/dev/null 2>&1 && sudo ' +
			'rm -f "' + cLinkPath + '"' +
			' || (which doas >/dev/null 2>&1 && doas ' +
			'rm -f "' + cLinkPath + '"' +
			' || rm -f "' + cLinkPath + '")'
		system(cFinalCmd)

		if not fexists(cLinkPath)
			logSuccess("Removed symlink: " + cLinkPath)
		else
			logWarning("Could not remove symlink: " + cLinkPath)
		ok

		# Remove binary
		if fexists(cBinPath)
			remove(cBinPath)
			logSuccess("Removed " + cBinPath)
		else
			logWarning("Binary not found: " + cBinPath)
		ok
	ok

	logSuccess("Uninstallation finished.")
