# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

/*
    sign command for Ring2APK
    Sign APK with keystore for release distribution
*/

# Execute sign command
func cmdSign aArgs
    cKeystore = ""
    cKeystorePass = ""
    cKeyAlias = ""
    cKeyPass = ""
    cApkPath = ""
    
    # Parse arguments
    for cArg in aArgs
        if left(cArg, 11) = "--keystore="
            cKeystore = subStr(cArg, 12)
        but left(cArg, 10) = "--ks-pass="
            cKeystorePass = subStr(cArg, 11)
        but left(cArg, 12) = "--key-alias="
            cKeyAlias = subStr(cArg, 13)
        but left(cArg, 11) = "--key-pass="
            cKeyPass = subStr(cArg, 12)
        but left(cArg, 6) = "--apk="
            cApkPath = subStr(cArg, 7)
        but left(cArg, 2) != "--"
            cApkPath = cArg
        ok
    next
    
    logInfo("Signing APK...")
    
    # Check environment
    oEnv = detectEnvironment()
    if len(oEnv.apksigner) = 0
        fail("apksigner not found!")
    ok
    
    # Load config for defaults
    oConfig = loadConfig("ring2apk.ring")
    if isNull(oConfig)
        fail("Configuration could not be loaded")
    ok
    
    # Use config values if not specified
    if len(cKeystore) = 0
        cKeystore = oConfig[:keystore]
    ok
    if len(cKeystorePass) = 0
        cKeystorePass = oConfig[:keystorePassword]
    ok
    if len(cKeyAlias) = 0
        cKeyAlias = oConfig[:keyAlias]
    ok
    if len(cKeyPass) = 0
        cKeyPass = oConfig[:keyPassword]
    ok
    
    # Find APK if not specified
    if len(cApkPath) = 0
        cApkPath = joinPath([oConfig[:outputDir], oConfig[:name] + "-release.apk"])
        if not fExists(cApkPath)
            cApkPath = joinPath([oConfig[:outputDir], oConfig[:name] + "-debug.apk"])
        ok
    ok
    
    if not fExists(cApkPath)
        fail("APK not found: " + cApkPath + " — specify one with --apk=path/to/app.apk")
    ok
    
    # Check keystore
    if len(cKeystore) = 0
        ? "Options:"
        ? "  1. Specify keystore: ring2apk sign --keystore=release.keystore --ks-pass=password"
        ? "  2. Add to ring2apk.ring:"
        ? '       keystore = "release.keystore"'
        ? '       keystorePassword = "your-password"'
        ? ""
        ? "To create a new keystore:"
        ? '  keytool -genkeypair -alias release -keyalg RSA -keysize 2048 \'
        ? "    -validity 10000 -keystore release.keystore"
        fail("No keystore specified!")
    ok
    
    if not fExists(cKeystore)
        fail("Keystore not found: " + cKeystore)
    ok
    
    # Prompt for password if not provided
    if len(cKeystorePass) = 0
        see "Enter keystore password: "
        give cKeystorePass
    ok
    
    # Sign the APK
    logStep("Sign", "Signing with " + cKeystore + "...")
    
    # Pass passwords to apksigner via temp files
    cStoreFile = tempName() + ".pass"
    write(cStoreFile, cKeystorePass + nl)
    cKeyFile = ""
    
    cCmd = '"' + oEnv.apksigner + '" sign ' +
           '--ks "' + cKeystore + '" ' +
           '--ks-pass file:"' + cStoreFile + '" '
    
    if len(cKeyAlias) > 0
        cCmd += '--ks-key-alias ' + cKeyAlias + ' '
    ok
    
    if len(cKeyPass) > 0
        cKeyFile = tempName() + ".pass"
        write(cKeyFile, cKeyPass + nl)
        cCmd += '--key-pass file:"' + cKeyFile + '" '
    ok
    
    cCmd += '"' + cApkPath + '"'
    
    nResult = shellSilent(cCmd)
    if fExists(cStoreFile)
        remove(cStoreFile)
    ok
    if len(cKeyFile) > 0 and fExists(cKeyFile)
        remove(cKeyFile)
    ok
    
    if nResult != 0
        fail("Signing failed!")
    ok
    
    logSuccess("APK signed successfully!")
    ? "Signed APK: " + cApkPath
    
    # Verify signature
    verifySignature(oEnv.apksigner, cApkPath)

# Verify APK signature
func verifySignature cApksigner, cApkPath
    logStep("Verify", "Verifying signature...")
    
    cCmd = '"' + cApksigner + '" verify -v "' + cApkPath + '"'
    cOutput = shellOutput(cCmd)
    
    if subStr(cOutput, "Verified") > 0
        logSuccess("Signature verified!")
    else
        logWarning("Could not verify signature")
        ? cOutput
    ok

# Create a new release keystore
func cmdCreateKeystore aArgs
    cKeystorePath = "release.keystore"
    cAlias = "release"
    cValidity = "10000"
    cDName = ""
    
    # Parse arguments
    for cArg in aArgs
        if left(cArg, 7) = "--name="
            cKeystorePath = subStr(cArg, 8)
        but left(cArg, 8) = "--alias="
            cAlias = subStr(cArg, 9)
        but left(cArg, 11) = "--validity="
            cValidity = subStr(cArg, 12)
        but left(cArg, 8) = "--dname="
            cDName = subStr(cArg, 9)
        ok
    next
    
    # Check for keytool
    oEnv = detectEnvironment()
    if len(oEnv.javaHome) = 0
        fail("Java not found!")
    ok
    
    cKeytool = oEnv.javaHome + pathSeparator() + "bin" + pathSeparator() + "keytool"
    if isWindows()
        cKeytool += ".exe"
    ok
    
    if fExists(cKeystorePath)
        fail("Keystore already exists: " + cKeystorePath)
    ok
    
    logInfo("Creating release keystore...")
    
    # Prompt for information
    see "Enter keystore password (min 6 chars): "
    give cPassword
    
    if len(cDName) = 0
        see "Enter your name (CN): "
        give cCN
        see "Enter organization (O): "
        give cOrg
        see "Enter country code (C, e.g., US): "
        give cCountry
        
        cDName = "CN=" + cCN + ",O=" + cOrg + ",C=" + cCountry
    ok
    
    # Pass the password via a temp file (keytool's -storepass:file reads
    # the first line) instead of argv. argv is visible in `ps`; a file
    # path is not. Same approach as apksigner signing, and avoids relying
    # on env-var propagation to the child process.
    cPassFile = tempName() + ".pass"
    write(cPassFile, cPassword + nl)

    cCmd = '"' + cKeytool + '" -genkeypair ' +
           '-alias ' + cAlias + ' ' +
           '-keyalg RSA -keysize 2048 ' +
           '-validity ' + cValidity + ' ' +
           '-keystore "' + cKeystorePath + '" ' +
           '-storepass:file "' + cPassFile + '" ' +
           '-keypass:file "' + cPassFile + '" ' +
           '-dname "' + cDName + '"'

    nResult = shellSilent(cCmd)
    if fExists(cPassFile)
        remove(cPassFile)
    ok

    if nResult = 0
        logSuccess("Keystore created: " + cKeystorePath)
        ? "Add to ring2apk.ring:"
        ? '    keystore = "' + cKeystorePath + '"'
        ? '    keystorePassword = "<your-password>"'
        ? '    keyAlias = "' + cAlias + '"'
    else
        fail("Failed to create keystore!")
    ok
