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

ScriptVersion="0.9.3"

source "$(dirname "$0")"/libfuncs &>/dev/null || {
	echo "Missing file: libfuncs";
	exit 1;
}

ShowHelp() {
	echo -e "\e[1;38;5;209m${ScriptName}\e[0m - Package manager helper utility (depends on \e[1myaourt\e[0m -- https://archlinux.fr/yaourt-en and \e[1mreflector\e[0m -- https://wiki.archlinux.org/index.php/Reflector)" >&2
	echo -e "\nUsage: ${0##*/} [-c | --country] [-h | --help] [-m | --mirrors] [-o | --optimize] [-p | --purge] [-r | --refresh-keys] [-u | --update] [-v | --version]" >&2
	echo -e "\nOptions:" >&2
	echo -e "  -c, --country CODE\tTwo letters country code from where to generate the mirrorlist" >&2
	echo -e "\t\t\tUse the command \e[1mreflector --list-countries\e[0m to list them" >&2
	echo -e "\t\t\tThe \e[1m-m\e[0m option is implied" >&2
	echo -e "  -h, --help\t\tPrint this help text and exit" >&2
	echo -e "  -m, --mirrors\t\tRetrieve and filter a list of the latest Arch Linux mirrors" >&2
	echo -e "  -o, --optimize\tClean, upgrade and optimize pacman databases" >&2
	echo -e "  -p, --purge\t\tClean ALL files from cache, unused and sync repositories databases" >&2
	echo -e "  -r, --refresh-keys\tRefresh pacman GnuPG keys" >&2
	echo -e "  -u, --update\t\tUpgrades all packages that are out-of-date, package downgrades enabled" >&2
	echo -e "  -v, --version\t\tDisplay \e[1m${ScriptName}\e[0m utility version" >&2
	exit 10
}


isCountry() {
	# reflector --list-countries
	local _CountryCodes=("AU" "AT" "BY" "BE" "BA" "BR" "BG" "CA" "CL" "CN" "CO" "HR" "CZ" "DK" "EC" "FI" "FR" "DE" "GR" "HK" "HU" "IS" "ID" "IE" "IL" "IT" "JP" "KZ" "LV" "LT" "LU" "MK" "NL" "NC" "NO" "PH" "PL" "PT" "QA" "RO" "RU" "SG" "SK" "SI" "ZA" "KR" "ES" "SE" "CH" "TW" "TH" "TR" "UA" "GB" "US" "VN")
	local cc
	for cc in "${_CountryCodes[@]}"; do [[ "$cc" == $1 ]] && return 0; done
	return 1
}

Mirrors=false
Optimize=false
Purge=false
RefreshKeys=false
Update=false
nReflectorMirrors=10
nReflectorMirrorsAge=12
nReflectorThreads=4
ReflectorCountry=''

WrongOption=""

yupRC="${HOME}"/.config/yuprc

initiateRC() {
	echo "# ${ScriptName} - Package manager helper utility" > "${yupRC}"
	echo "#" >> "${yupRC}"
	echo "#" >> "${yupRC}"
	echo "ReflectorCountry=${ReflectorCountry}" >> "${yupRC}"
	return 1
}

if [ -f "${yupRC}" ]; then
	source "${yupRC}"
fi
if [ -z "${ReflectorCountry}" ]; then
	ReflectorCountry='DE' # DE (Denmark) is the default country code
	initiateRC
fi

refreshPKGDBs() {
	# -y, --refresh
	#	Passing two --refresh or -y flags will
	#	force a refresh of all package databases, even if they appear to be up-to-date.
	# -a, --aur
	#	Also search in AUR database.
	yaourt --color -Syy --aur --devel
	# Write any data buffered in memory out to disk
	sudo sync
	return 1
}


while [[ "$1" == -* ]]; do
	case "$1" in
		-c | --country)
			shift
			isCountry "${1^^}" && {
				ReflectorCountry=${1^^}
				sed -i "/ReflectorCountry/s/=.*/=$(echo ${ReflectorCountry})/" "${yupRC}"
				Mirrors=true
			} || {
				msg "Invalid country code. Try “${ScriptName} -h” for more information" 1
				exit 20
			}
			;;

		-h | --help)
			ShowHelp
			;;

		-m | --mirrors)
			Mirrors=true
			;;

		-o | --optimize)
			Optimize=true
			;;

		-p | --purge)
			Purge=true
			;;

		-r | --refresh-keys)
			RefreshKeys=true
			;;

		-u | --update)
			Update=true
			;;

		-v | --version)
			msg "${ScriptVersion}" 3
			exit 30
			;;

		 *)
			WrongOption=$1
			;;
	esac
	shift
done

# Check options for error
if [[ "${WrongOption}" != "" ]] || [[ -n "$1" ]]; then
	msg "Invalid option "${WrongOption}". Try “${ScriptName} -h” for more information" 1
	exit 40
fi

if ! hash yaourt &>/dev/null; then
	msg "\e[1myaourt\e[0m: command not found! See https://archlinux.fr/yaourt-en on how to install it" 1
	exit 50
fi

# Grant root privileges
sudo -v || exit 1

if $RefreshKeys; then
	# Grant root privileges
	sudo -v || exit 3

	msg "Refreshing pacman GnuPG keys..." 11

	Flavours="archlinux"
	declare -a NeededPkgs=("gnupg" "archlinux-keyring") 
	[[ $(yaourt  -Ssq apricity-keyring) ]] && { Flavours=${Flavours}" apricity"; NeededPkgs+=("apricity-keyring"); }
	[[ $(yaourt  -Ssq antergos-keyring) ]] && { Flavours=${Flavours}" antergos"; NeededPkgs+=("antergos-keyring"); }
	[[ $(yaourt  -Ssq manjaro-keyring) ]] && { Flavours=${Flavours}" manjaro"; NeededPkgs+=("manjaro-keyring"); }

	msg "~> Reinitiating current user's PGP keys..." 3
	rm -rfv ${HOME}/.gnupg
	gpg --list-keys
	msg "~> Managing and downloading certificate revocation lists..." 3
	touch ${HOME}/.gnupg/dirmngr_ldapservers.conf
	sudo dirmngr --debug-level guru < /dev/null
	msg "~> Clear out any already downloaded software packages..." 3
	sudo pacman --color always -Sc --force --noconfirm
	msg "~> Reinstaling needing packages..." 3
	###  Public keyring not found; have you run 'pacman-key --init'?
	# LocalFileSigLevel = Optional
	sudo pacman -Syw --noconfirm --quiet --force ${NeededPkgs[@]}
	for iPkg in "${!NeededPkgs[@]}"; do
		sudo pacman -U --force --noconfirm /var/cache/pacman/pkg/"${NeededPkgs[${iPkg}]}"*
	done
	msg "~> Removing existing trusted keys..." 3
	sudo rm -rfv /var/lib/pacman/sync
	sudo rm -rfv /etc/pacman.d/gnupg
	msg "~> Reinitiating pacman trusted keys..." 3
	sudo pacman-key --init
	msg "~> The initial setup of keys..." 3
	sudo pacman-key --populate ${Flavours}
	msg "~> Refreshing pacman trusted keys..." 3
	sudo pacman-key --refresh-keys
	msg "~> Refreshing databases..." 3
	#refreshPKGDBs
	# Write any data buffered in memory out to disk
	sudo sync
fi

if $Mirrors; then
	if hash pacman-mirrors &>/dev/null; then
		msg "Retrieving and Filtering a list of the latest Manjaro-Arch Linux mirrors..." 10
		sudo pacman-mirrors -c Germany -m  rank
	elif ! hash reflector &>/dev/null; then
		msg "\e[1mreflector\e[0m: command not found! Use \e[1msudo pacman -S reflector\e[0m to install it" 2
	else
		# Grant root privileges
		sudo -v || exit 2
		msg "Retrieving and Filtering a list of the latest Arch Linux mirrors..." 13
		sudo $(which reflector) --country ${ReflectorCountry} --latest ${nReflectorMirrors} --age ${nReflectorMirrorsAge} --fastest ${nReflectorMirrors} --threads ${nReflectorThreads} --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
		echo -e "\n\e[0;94m\e[40m"
		cat /etc/pacman.d/mirrorlist
		echo -e "\e[0;100m\e[0;91m"
		sudo rm -fv /etc/pacman.d/mirrorlist.*
		echo -e "\e[0m"
		# Write any data buffered in memory out to disk
		sudo sync
	fi
fi

### Standard Action
#
refreshPKGDBs
#
### Standard Action

if $Update && [ $(yaourt -Qu --aur | wc -l) -gt 0 ]; then
	# Grant root privileges
	sudo -v || exit 4

	msg "Updating packages..." 10

#	 -u, --sysupgrade
#		Pass this option twice to enable package downgrades; in this case, pacman will select sync packages
#		whose versions do not match with the local versions. This can be useful when the user switches from a
#		testing repository to a stable one.
#	-a, --aur
#		With -u or --sysupgrade, upgrade aur packages that are out of date.
	yaourt --color -Suu --aur 
	# Write any data buffered in memory out to disk
	sudo sync
fi

if $Optimize; then
	# Grant root privileges
	sudo -v || exit 5

	msg "Updating the stored metadata files..." 10
	sudo pkgfile --update

	msg "Upgrading and Optimizing pacman databases..." 10

	sudo pacman-db-upgrade
	sudo pacman-optimize

	# Write any data buffered in memory out to disk
	sudo sync
fi

if $Purge; then
	# Grant root privileges
	sudo -v || exit 6

	msg "Cleaning ALL files from cache, unused and sync repositories databases..." 11

	if [[ -d /var/lib/pacman/sync ]]; then
		# Cleaning an Arch Linux installation
		# https://andreascarpino.it/posts/cleaning-an-arch-linux-installation.html
		if [[ -n $(pacman -Qqdtt) ]]; then
			sudo pacman --color always -Rs $(pacman -Qqdtt)
		fi

		# -c, --clean
		#	Use one --clean switch to only remove packages that are no
		#	longer installed; use two to remove all files from the cache. In both cases, you will have a yes or no
		#	option to remove packages and/or unused downloaded databases.
		#sudo pacman --color always -Scc
		yaourt -Scc

		echo -e "\nPacman sync repositories directory: /var/lib/pacman/sync"
		echo -en "\e[1;34m:: \e[1;39mDo you want to remove ALL the sync repositories databases? [y/N] \e[0m"
		read ANS
		[[ ${ANS:-N} == [Yy] ]] && {
			echo "removing all sync repositories..."
			sudo rm -rfv /var/lib/pacman/sync
			msg "Repositories databases don't exist anymore. You may have to REFRESH them." 2
			echo -en "\e[1;34m:: \e[1;39mDo it now? [Y/n] \e[0m"
			read ANS
			[[ ${ANS:-Y} == [Yy] ]] && {
				refreshPKGDBs # Standard Action
			}
		}
		# Write any data buffered in memory out to disk
		sudo sync
	fi
fi

exit $?
