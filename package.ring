aPackageInfo = [
	:name = "ring2apk",
	:description = "Build Android APKs from Ring applications",
	:folder = "ring2apk",
	:developer = "ysdragon",
	:email = "",
	:license = "MIT License",
	:version = "1.0.1",
	:ringversion = "1.27",
	:versions = 	[
		[
			:version = "1.0.1",
			:branch = "master"
		]
	],
	:libs = 	[
		[
			:name = "ringcurl",
			:version = "1.0.18",
			:providerusername = "ringpackages"
		]
	],
	:files = 	[
		"ring2apk.ring",
		"lib.ring",
		"main.ring",
		"LICENSE",
		"README.md",
		"src/app.ring",
		"src/config.ring",
		"src/environment.ring",
		"src/commands/build.ring",
		"src/commands/run.ring",
		"src/commands/sign.ring",
		"src/commands/clean.ring",
		"src/commands/init.ring",
		"src/utils/colors.ring",
		"src/utils/json.ring",
		"src/utils/install.ring",
		"src/utils/uninstall.ring",
		"src/utils/shared.ring",
		"src/utils/shell.ring",

		# Hello example
		"examples/hello/ring2apk.ring",
		"examples/hello/ring/main.ring",
		"examples/hello/README.md",
		"examples/hello/res/values/colors.xml",
		"examples/hello/res/values/strings.xml",
		"examples/hello/res/values/styles.xml",
		"examples/hello/src/cpp/CMakeLists.txt",
		"examples/hello/src/cpp/main.c",
		"examples/hello/src/cpp/README.md",

		# RingRayLib example
		"examples/ringraylib/.gitignore",
		"examples/ringraylib/AndroidManifest.xml",
		"examples/ringraylib/README.md",
		"examples/ringraylib/download_deps.ring",
		"examples/ringraylib/res/mipmap-hdpi/ic_launcher.png",
		"examples/ringraylib/res/mipmap-mdpi/ic_launcher.png",
		"examples/ringraylib/res/mipmap-xhdpi/ic_launcher.png",
		"examples/ringraylib/res/mipmap-xxhdpi/ic_launcher.png",
		"examples/ringraylib/res/values/colors.xml",
		"examples/ringraylib/res/values/strings.xml",
		"examples/ringraylib/res/values/styles.xml",
		"examples/ringraylib/ring/classes.ring",
		"examples/ringraylib/ring/functions.ring",
		"examples/ringraylib/ring/main.ring",
		"examples/ringraylib/ring/raygui.rh",
		"examples/ringraylib/ring/raylib.rh",
		"examples/ringraylib/ring/raylib.ring",
		"examples/ringraylib/ring/shader.ring",
		"examples/ringraylib/ring2apk.ring",
		"examples/ringraylib/screenshots/screens.png",
		"examples/ringraylib/src/cpp/CMakeLists.txt",
		"examples/ringraylib/src/cpp/main.c",
		"examples/ringraylib/src/cpp/ring_raylib.c",
		"examples/ringraylib/src/java/com/ring/ringraylib/MainActivity.java"
	],
	:ringfolderfiles = 	[

	],
	:windowsfiles = 	[

	],
	:linuxfiles = 	[

	],
	:ubuntufiles = 	[

	],
	:fedorafiles = 	[

	],
	:freebsdfiles = 	[

	],
	:macosfiles = 	[

	],
	:windowsringfolderfiles = 	[

	],
	:linuxringfolderfiles = 	[

	],
	:ubunturingfolderfiles = 	[

	],
	:fedoraringfolderfiles = 	[

	],
	:freebsdringfolderfiles = 	[

	],
	:macosringfolderfiles = 	[

	],
	:run = "ring ring2apk.ring",
	:windowsrun = "",
	:linuxrun = "",
	:macosrun = "",
	:ubunturun = "",
	:fedorarun = "",
	:setup = "ring src/utils/install.ring",
	:windowssetup = "",
	:linuxsetup = "",
	:macossetup = "",
	:ubuntusetup = "",
	:fedorasetup = "",
	:remove = "ring src/utils/uninstall.ring",
	:windowsremove = "",
	:linuxremove = "",
	:macosremove = "",
	:ubunturemove = "",
	:fedoraremove = ""
]
