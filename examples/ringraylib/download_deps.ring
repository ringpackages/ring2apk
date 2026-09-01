load "stdlibcore.ring"
load "libcurl.ring"
load "ziplib.ring"

func main
	download("https://github.com/raysan5/raylib/archive/refs/tags/5.5.zip",
	     "src/cpp", "raylib-5.5", "raylib")
	download("https://github.com/raysan5/raygui/archive/refs/tags/5.0.zip",
	     "src/cpp", "raygui-5.0", "raygui")
	? "Done."

func download cUrl, cDestParent, cExtractName, cTargetName
	? "Downloading " + cUrl + " ..."

	hCurl = curl_easy_init()
	curl_easy_setopt(hCurl, CURLOPT_URL, cUrl)
	curl_easy_setopt(hCurl, CURLOPT_FOLLOWLOCATION, 1)
	curl_easy_setopt(hCurl, CURLOPT_USERAGENT, "download_deps")
	curl_easy_setopt(hCurl, CURLOPT_NOPROGRESS, 1)
	curl_easy_setopt(hCurl, CURLOPT_SSL_VERIFYPEER, 0)
	curl_easy_setopt(hCurl, CURLOPT_SSL_VERIFYHOST, 0)
	cData = curl_easy_perform_silent(hCurl)
	curl_easy_cleanup(hCurl)

	if len(cData) = 0
		? "  Download failed (empty response)."
		return
	ok

	cZip = tempname() + ".zip"
	write(cZip, cData)

	zip_extract_allfiles(cZip, cDestParent)
	remove(cZip)

	cExtractedPath = cDestParent + "/" + cExtractName
	cTargetPath    = cDestParent + "/" + cTargetName

	if dirExists(cTargetPath)
		osDeleteFolder(cTargetPath)
	ok

	if cExtractedPath != cTargetPath and dirExists(cExtractedPath)
		rename(cExtractedPath, cTargetPath)
	ok

	? "  -> " + cTargetPath