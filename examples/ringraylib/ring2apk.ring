/*
    Ring2APK configuration file
    Edit this file to configure your Android app build
*/

# App configuration
Ring2ApkConfig = [
    # App identity
    :name = "ringraylib",
    :packageId = "com.ring.ringraylib",
    :versionCode = 1,
    :versionName = "1.0.0",

    # Android SDK versions
    :minSdk = 21,
    :targetSdk = 34,
    :compileSdk = 34,

    # Target architectures
    :targets = ["arm64-v8a"],

    # Directories
    :assetsDir = "assets",
    :resDir = "res",
    :srcDir = "src",
    :outputDir = "build",

    # Entry point Ring file
    :entryPoint = "main.ring",
    :ringSrcDir = "ring",

    # App display settings
    :label = "RingRayLib",
    :orientation = "unspecified",
    :requireGLES = "0x00020000",

    # Permissions (uncomment as needed)
    # permissions = [
    #     "android.permission.INTERNET",
    #     "android.permission.VIBRATE"
    # ]
]

