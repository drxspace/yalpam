#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#
#set -e
#set -x

ScriptVersion="0.9.1"
ScriptName="$(basename $0)"

msg() {
	local msgStartOptions=""
	local msgEndOptions="\033[0m"

	case $2 in
		0|"")	# Generic message
			msgStartOptions="\033[1;33m${ScriptName}\033[0m: \033[94m"
			;;
		1)	# Error message
			msgStartOptions="\033[1;31m${ScriptName}\033[0m: \033[91m"
			;;
		2)	# Warning
			msgStartOptions="\033[1;38;5;209m${ScriptName}\033[0m: \033[93m"
			;;
		3)	# Information
			msgStartOptions="\033[1;94m${ScriptName}\033[0m: \033[94m"
			;;
		4)	# Question
			msgStartOptions="\033[1;38;5;57m${ScriptName}\033[0m: \033[36m"
			;;
		5)	# Success
			msgStartOptions="\033[1;92m${ScriptName}\033[0m: \033[32m"
			;;
		10)	# Header
			msgStartOptions="\n\033[1;34m:: \033[1;39m"
			msgEndOptions="\033[0m\n"
			;;
		11)	# Header
			msgStartOptions="\n\033[1;34m:: \033[1;39m"
			;;
		12)	# Header
			msgStartOptions="\033[1;34m:: \033[1;39m"
			msgEndOptions="\033[0m\n"
			;;
		13)	# Header
			msgStartOptions="\033[1;34m:: \033[1;39m"
			;;
		*)	# Fallback to Generic message
			msgStartOptions="\033[1;33m${ScriptName}\033[0m: \033[94m"
			;;
	esac

	echo -e "${msgStartOptions}${1}${msgEndOptions}"
}
