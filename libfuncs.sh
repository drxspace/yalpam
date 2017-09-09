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

ScriptName="$(basename $0)"

msg() {
	local msgStartOptions=""
	local msgEndOptions="\e[0m"

	case $2 in
		0|"")	# Generic message
			msgStartOptions="\e[1;33m${ScriptName}\e[0m: \e[94m"
			;;
		1)	# Error message
			msgStartOptions="\e[1;31m${ScriptName}\e[0m: \e[91m"
			;;
		2)	# Warning
			msgStartOptions="\e[1;38;5;209m${ScriptName}\e[0m: \e[93m"
			;;
		3)	# Information
			msgStartOptions="\e[1;94m${ScriptName}\e[0m: \e[94m"
			;;
		4)	# Question
			msgStartOptions="\e[1;38;5;57m${ScriptName}\e[0m: \e[36m"
			;;
		5)	# Success
			msgStartOptions="\e[1;92m${ScriptName}\e[0m: \e[32m"
			;;
		10)	# Header
			msgStartOptions="\n\e[1;34m:: \e[1;39m"
			msgEndOptions="\e[0m\n"
			;;
		11)	# Header
			msgStartOptions="\n\e[1;34m:: \e[1;39m"
			;;
		12)	# Header
			msgStartOptions="\e[1;34m:: \e[1;39m"
			msgEndOptions="\e[0m\n"
			;;
		13)	# Header
			msgStartOptions="\e[1;34m:: \e[1;39m"
			;;
		*)	# Fallback to Generic message
			msgStartOptions="\e[1;33m${ScriptName}\e[0m: \e[94m"
			;;
	esac

	echo -e "${msgStartOptions}${1}${msgEndOptions}"
}
