# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

# ANSI color and style utilities for terminal output

# Enable unicode support in Windows CMD/PowerShell
if isWindows()
	system("chcp 65001 > NUL 2>&1")
ok

# Colors
COLOR_RESET     = char(27) + "[0m"
COLOR_BOLD      = char(27) + "[1m"
COLOR_DIM       = char(27) + "[2m"
COLOR_ITALIC    = char(27) + "[3m"
COLOR_UNDERLINE = char(27) + "[4m"

# Foreground colors
FG_BLACK   = char(27) + "[30m"
FG_RED     = char(27) + "[31m"
FG_GREEN   = char(27) + "[32m"
FG_YELLOW  = char(27) + "[33m"
FG_BLUE    = char(27) + "[34m"
FG_MAGENTA = char(27) + "[35m"
FG_CYAN    = char(27) + "[36m"
FG_WHITE   = char(27) + "[37m"

# Bright foreground colors
FG_BRIGHT_BLACK   = char(27) + "[90m"
FG_BRIGHT_RED     = char(27) + "[91m"
FG_BRIGHT_GREEN   = char(27) + "[92m"
FG_BRIGHT_YELLOW  = char(27) + "[93m"
FG_BRIGHT_BLUE    = char(27) + "[94m"
FG_BRIGHT_MAGENTA = char(27) + "[95m"
FG_BRIGHT_CYAN    = char(27) + "[96m"
FG_BRIGHT_WHITE   = char(27) + "[97m"

# Helper functions
func bold(text)
	return COLOR_BOLD + text + COLOR_RESET

func dim(text)
	return COLOR_DIM + text + COLOR_RESET

func italic(text)
	return COLOR_ITALIC + text + COLOR_RESET

func underline(text)
	return COLOR_UNDERLINE + text + COLOR_RESET

func red(text)
	return FG_RED + text + COLOR_RESET

func green(text)
	return FG_GREEN + text + COLOR_RESET

func yellow(text)
	return FG_YELLOW + text + COLOR_RESET

func blue(text)
	return FG_BLUE + text + COLOR_RESET

func magenta(text)
	return FG_MAGENTA + text + COLOR_RESET

func cyan(text)
	return FG_CYAN + text + COLOR_RESET

func brightCyan(text)
	return FG_BRIGHT_CYAN + text + COLOR_RESET

func brightYellow(text)
	return FG_BRIGHT_YELLOW + text + COLOR_RESET

func brightGreen(text)
	return FG_BRIGHT_GREEN + text + COLOR_RESET

func brightMagenta(text)
	return FG_BRIGHT_MAGENTA + text + COLOR_RESET

func brightRed(text)
	return FG_BRIGHT_RED + text + COLOR_RESET

# Colored log functions
func logInfo cMessage
	? FG_BLUE + "INFO: " + COLOR_RESET + cMessage

func logSuccess cMessage
	? FG_GREEN + "SUCCESS: " + COLOR_RESET + cMessage

func logWarning cMessage
	? FG_YELLOW + "WARNING: " + COLOR_RESET + cMessage

func logError cMessage
	? FG_RED + "ERROR: " + COLOR_RESET + cMessage

func logStep cStep, cMessage
	? FG_CYAN + "[" + cStep + "] " + COLOR_RESET + cMessage

func logBuild cMessage
	? COLOR_BOLD + "   Building: " + COLOR_RESET + cMessage

func logProgress nCurrent, nTotal, cMessage
	cProgress = "" + nCurrent + "/" + nTotal
	? FG_CYAN + "[" + cProgress + "] " + COLOR_RESET + cMessage

func logCommand cCmd
	if $RING2APK_VERBOSE
		? FG_YELLOW + "  $ " + COLOR_RESET + cCmd
	ok

func logVerbose cMessage
	if $RING2APK_VERBOSE
		? COLOR_RESET + "  " + cMessage
	ok

func setVerbose lFlag
	$RING2APK_VERBOSE = lFlag

func fail cMessage
	logError(cMessage)
	shutdown(1)