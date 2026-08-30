aPackageInfo = [
	:name = "ring2apk",
	:description = "Build Android APKs from Ring applications",
	:folder = "ring2apk",
	:developer = "ysdragon",
	:email = "",
	:license = "MIT License",
	:version = "1.0.0",
	:ringversion = "1.27",
	:versions = 	[
		[
			:version = "1.0.0",
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
		"examples/hello/ring2apk.ring",
		"examples/hello/ring/main.ring",
		"examples/hello/README.md",
		"examples/hello/res/values/colors.xml",
		"examples/hello/res/values/strings.xml",
		"examples/hello/res/values/styles.xml",
		"examples/hello/src/cpp/CMakeLists.txt",
		"examples/hello/src/cpp/main.c",
		"examples/hello/src/cpp/README.md"
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
