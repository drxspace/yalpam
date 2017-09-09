#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#
#set -e set -x
#set -x set -e

[[ $EUID -ne 0 ]] && exec $(which sudo) "$0" "$1";

source "$(dirname "$0")"/libfuncs &>/dev/null || {
	echo "Missing file: libfuncs";
	exit 1;
}

[[ "$1" = "-m" ]] || [[ "$1" = "" ]] || [[ "$1" = "-a" ]] && {
	msg "Creating an initial ramdisk environment" 12;
	mkinitcpio -n -p linux;
	echo;
}

[[ "$1" = "-g" ]] || [[ "$1" = "" ]] || [[ "$1" = "-a" ]] && {
	msg "Probing disks on the system for other operating systems" 12;
	os-prober;
	msg "Generating a GRUB configuration file" 10;
	exec grub-mkconfig -o /boot/grub/grub.cfg;
}

exit $?
