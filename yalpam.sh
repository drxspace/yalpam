#!/usr/bin/env bash
#
# _________        ____  ____________         _______ ___________________
# ______  /__________  |/ /___  ____/________ ___    |__  ____/___  ____/
# _  __  / __  ___/__    / ______ \  ___  __ \__  /| |_  /     __  __/
# / /_/ /  _  /    _    |   ____/ /  __  /_/ /_  ___ |/ /___   _  /___
# \__,_/   /_/     /_/|_|  /_____/   _  .___/ /_/  |_|\____/   /_____/
#                                    /_/           drxspace@gmail.com
#
#
set -e
#
set -x

export yalpamVersion="0.3.002"

export yalpamTitle="Yet another Arch Linux PAckage Manager"
export yalpamName="yalpam"

hash paplay 2>/dev/null && [[ -d /usr/share/sounds/freedesktop/stereo/ ]] && {
	export errorSnd="paplay /usr/share/sounds/freedesktop/stereo/dialog-error.oga"
	export infoSnd="paplay /usr/share/sounds/freedesktop/stereo/dialog-information.oga"
}

msg() {
	$(${errorSnd});
	if ! hash notify-send 2>/dev/null; then
		echo -e ":: \e[1m$1\e[0m $2" 1>&2;
		exit $3;
	else
		notify-send "${yalpamTitle}" "<b>$1</b> $2" -i face-worried;
		exit $(($3 + 5));
	fi
}

# -----------------------------------------------------------------------------]
__CNKDISTRO__=$(sed -n '/^ID=/s/ID=//p' /etc/*release 2>/dev/null)

# for ArchLinux distros only
# you can type yours below
__CNKARCHES__="arch|antergos|manjaro|apricity"

DIR="$(dirname "$0")"
if [[ ! ${__CNKDISTRO__} =~ ${__CNKARCHES__} ]]; then
	msg "$__CNKDISTRO__" "for ArchLinux distros only." 8
fi
# -----------------------------------------------------------------------------]

# Prerequisites
# Check to see if all needed tools are present
if ! hash yad 2>/dev/null; then
	msg "yad" "command not found." 10
elif ! hash yaourt 2>/dev/null; then
	msg "yaourt" "command not found." 20
elif [ -z "$(yad --version | grep 'GTK+ 2')" ]; then
	msg "yad" "command uses an unsupported GTK+ platform version." 30
elif ! hash xterm  2>/dev/null; then
	msg "xterm" "command not found." 40
fi

fkey=$(($RANDOM * $$))

export frealtemp=$(mktemp -u --tmpdir realtemp.XXXXXXXX)
export frunningPIDs=$(mktemp -u --tmpdir runningPIDs.XXXXXXXX)
export fpipepkgssys=$(mktemp -u --tmpdir pkgssys.XXXXXXXX)
export fpipepkgslcl=$(mktemp -u --tmpdir pkgslcl.XXXXXXXX)
mkfifo "${fpipepkgssys}" "${fpipepkgslcl}"

export GDK_BACKEND=x11			# https://groups.google.com/d/msg/yad-common/Jnt-zCeCVg4/Gwzx-O-2BQAJ

declare -a runningPIDs=()

#export V=true				# V for verbose
#	${V} && { echo "$1 $2 $3 $4" 1>&2; }
# --close-on-unfocus
# declare/local -x

# ---[ Task functions ]------------------------------------------------------|

dodailytasks() {
	local args
	echo "7:@disable@"
	[[ "$2" = "TRUE" ]] && args=$args" -m" 
	[[ "$3" = "TRUE" ]] && args=$args" -u" 
	[[ "$4" = "TRUE" ]] && args=$args" -p" 
	[[ "$5" = "TRUE" ]] && args=$args" -o" 
	[[ "$6" = "TRUE" ]] && args=$args" -r" 
	xterm -geometry 152x32 -e "yup $args" && doscan4pkgs
	echo '7:@bash -c "dodailytasks %1 %2 %3 %4 %5 %6"'
	return
}
export -f dodailytasks

# ---[ Action functions ]------------------------------------------------------|

doreinstpkg() {
	kill -s USR1 $YAD_PID # Close caller window
	xterm -geometry 152x32 -e "[[ \"$1\" == \"pacman\" ]] && { sudo $1 -Sy --force --noconfirm $2; } || { $1 -Sya --force --noconfirm $2; }"
	doscan4pkgs
	return
}
export -f doreinstpkg

doremovepkg() {
	kill -s USR1 $YAD_PID # Close caller window
	xterm -geometry 152x32 -e "sudo $1 -Rcsn $2" && doscan4pkgs
	return
}
export -f doremovepkg

function on_click ()
{
	[[ "$1" ]] && {
		echo -n "$1" > ${frealtemp}
		kill -s USR1 $YAD_PID
	} || {
		$(${infoSnd})
		echo "2:<Type one or more package names>"
	}
}
export -f on_click

doinstpkg() {
	local ret=
	local packagenames=
	kill -s USR1 $YAD_PID # Close caller window
	yad	--form --width=420 --borders=9 --align="center" --center --fixed --skip-taskbar \
		--title="Enter package name(s)..." \
		--no-buttons --columns=2 --focus-field=2 \
		--field="Input here one or more package names separated by <i>blank</i> characters:":lbl '' \
		--field='' '' \
		--field="gtk-cancel":fbtn 'bash -c "kill -s USR2 $YAD_PID"' \
		--field="gtk-ok":fbtn '@bash -c "on_click %2"' & local pid=$!
		#--button='gtk-cancel:bash -c "kill -s USR2 $YAD_PID"' \
		#--button='gtk-ok:bash -c "on_click \%1"' & local pid=$!

	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	local ret=$?
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	packagenames=$(<${frealtemp})

	fxtermstatus=$(mktemp -u --tmpdir xtermstatus.XXXXXXXX)
	[[ $ret -eq 0 ]] && [[ "${packagenames}" ]] && {
		xterm -geometry 152x32 -e "[[ \"$1\" == \"pacman\" ]] && { sudo $1 -Sy ${packagenames}; } || { $1 -Sya ${packagenames}; }; echo $? > ${fxtermstatus}"
		[[ $(<$fxtermstatus) -eq 0 ]] && doscan4pkgs || $(${infoSnd})
	}
	rm -f ${fxtermstatus}
	return
}
export -f doinstpkg

docrawl() {
	kill -s USR1 $YAD_PID # Close caller window
	[[ -x $BROWSER ]] || BROWSER=$(command -v xdg-open 2>/dev/null || command -v gnome-open 2>/dev/null)
	[[ "$1" == "pacman" ]] && {
		URL="https://www.archlinux.org/packages/?sort=&q=${2}&maintainer=&flagged=";
	} || {
		URL="https://aur.archlinux.org/packages/?O=0&SeB=n&K=${2}&outdated=&SB=n&SO=a&PP=50&do_Search=Go";
	}
	exec "$BROWSER" "$URL"
	return
}
export -f docrawl

doexecpkg() {
	kill -s USR1 $YAD_PID # Close caller window
	$1 || $(${infoSnd})
	return
}
export -f doexecpkg

domanpage() {
	kill -s USR1 $YAD_PID # Close caller window
	man $1 &>/dev/null || $(${infoSnd}) && xterm -geometry 84x40 -e man $1
	return
}
export -f domanpage

doaction() {
	export -f doscan4pkgs

	export manager=$1
	export package=$3

	yad	--form --width=400 --borders=3 --align="center" --fixed \
		--skip-taskbar --title="Choose action:" \
		--image="dialog-information" --image-on-top \
		--text="Please, choose your desired action from the list below by clicking on its elements." \
		--field="<span color='#006699'>Reinstall/Update selected package</span>!gtk-refresh":btn 'bash -c "doreinstpkg $manager $package"' \
		--field="<span color='#006699'>Uninstall/Remove selected package</span>!gtk-delete":btn 'bash -c "doremovepkg $manager $package"' \
		--field="<span color='#006699'>Install a package of the selected category</span>!gtk-go-down":btn 'bash -c "doinstpkg $manager"' \
		--field="":lbl '' \
		--field="<span color='#006699'>Browse the package on the web</span>!gtk-home":btn 'bash -c "docrawl $manager $package"' \
		--field="":lbl '' \
		--field="<span color='#006699'>Try to <i>execute</i> the selected package</span>!gtk-execute":btn 'bash -c "doexecpkg $package"' \
		--field="<span color='#006699'>Try to view the <i>man page</i> of the selected package</span>!gtk-help":btn 'bash -c "domanpage $package"' \
		--buttons-layout="center" \
		--button=$"Close!gtk-close!Closes the current dialog":0 &>/dev/null & local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f doaction

# ---[ Buttons functionality ]-------------------------------------------------|

doabout() {
	yad	--form --width=400 --borders=9 --align="center" --fixed \
		--skip-taskbar --title="About ${yalpamTitle}" \
		--image="system-software-install" --image-on-top \
		--text="<span font_size='medium' font_weight='bold'>${yalpamTitle} v${yalpamVersion}</span>\nby John A Ginis (a.k.a. <a href='https://github.com/drxspace'>drxspace</a>)\n<span font_size='small'>build on Summer of 2017</span>" \
		--field="":lbl '' \
		--field="<b><i>yalpam</i></b> is a helper tool for managing Arch Linux packages, that I started to build in order to cope with my own personal <i>special</i> needs.\nIt uses the great tool <a href='https://sourceforge.net/projects/yad-dialog/'>yad</a> which is a personal project of <a href='https://plus.google.com/+VictorAnanjevsky'>Victor Ananjevsky</a>.\n\nI decided to share my <i>joy</i> with you because you may find it useful too.\n\nHave fun and bring joy into your lifes,\nJohn":lbl '' \
		--field="":lbl '' \
		--buttons-layout="center" \
		--button=$"Close!gtk-close!Closes the current dialog":0 &>/dev/null & local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f doabout

dosavepkglists() {
	local dirname=$(yad --file --directory --filename="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}/" \
			    --width=640 --height=480 --skip-taskbar \
			    --title="Choose a directory to save the files...")
	if [ "${dirname}" ]; then
		pacman -Qqe |\
			grep -vx "$(pacman -Qqg base)" |\
			grep -vx "$(pacman -Qqm)" > "${dirname}"/$(date -u +"%g%m%d")-SYSTEMpkgs.txt
		pacman -Qqm > "${dirname}"/$(date -u +"%g%m%d")-LOCALpkgs.txt
	fi
	return
}
export -f dosavepkglists

doscan4pkgs() {
	echo -e '\f' >> "${fpipepkgssys}"
	pacman -Qe |\
		grep -vx "$(pacman -Qg base)" |\
		grep -vx "$(pacman -Qm)" |\
		awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgssys}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=320 --align="center" --center --borders=9 --skip-taskbar --title="Querying packages" --text-align="center" --text="One moment please. Querying <i>System</i> packages..."

	echo -e '\f' >> "${fpipepkgslcl}"
	pacman -Qm | awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgslcl}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=320 --align="center" --center --borders=9 --skip-taskbar --title="Querying packages" --text-align="center" --text="One moment please. Querying <i>Local/AUR</i> packages..."
	return
}
export -f doscan4pkgs

# -----------------------------------------------------------------------------|

exec 3<> ${fpipepkgssys}
exec 4<> ${fpipepkgslcl}

echo 'openedFormPIDs=()' > ${frunningPIDs}

yad --plug="${fkey}" --tabnum=1 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction pacman %s %s %s"' \
    --text="List of <i>System</i> packages:\n<span font_size='small'>Double click on a package for more <i>action</i>.</span>" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':num --column='Package Name' --column='Package Version' <&3 &>/dev/null &

yad --plug="${fkey}" --tabnum=2 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction yaourt %s %s %s"' \
    --text="List of <i>Local/AUR</i> packages:\n<span font_size='small'>Double click on a package for more <i>action</i>.</span>" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':num --column='Package Name' --column='Package Version' <&4 &>/dev/null &

yad --plug="${fkey}" --tabnum=3 --form \
    --field="Refresh pacman databases:chk" 'TRUE' \
    --field="Retrieve and Filter a list of the latest Manjaro-Arch Linux mirrors:chk" 'FALSE' \
    --field="Update packages:chk" 'FALSE' \
    --field="Clean ALL files from cache, unused and sync repositories databases:chk" 'FALSE' \
    --field="Optimize pacman databases:chk" 'FALSE' \
    --field="Refresh pacman GnuPG keys:chk" 'FALSE' \
    --field="Let's Go!gtk-execute:fbtn" '@bash -c "dodailytasks %1 %2 %3 %4 %5 %6"' &>/dev/null &

yad --key="${fkey}" --notebook --width=480 --height=640 \
    --borders=9 --tab-borders=3 --active-tab=1 --focus-field=1 \
    --window-icon="system-software-install" --title="${yalpamTitle} v${yalpamVersion}" \
    --image="system-software-install" --image-on-top \
    --text="<span font_size='medium' font_weight='bold'>View Lists of Installed Packages</span>\n\
These are <i><b>only</b> the explicitly installed</i> packages from all enabled repositories except for <i>base</i> repository. Also, you\'ll find packages that are locally installed such as <i>AUR</i> packages." \
    --tab=" <i>System</i> packages category" \
    --tab=" <i>Local/AUR</i> packages category" \
    --tab=" Other tasks" \
    --button="<span color='#0066ff'>List/Update</span>!system-search!Scans databases for installed packages:bash -c 'doscan4pkgs'" \
    --button="Save/Backup!gtk-save!Saves package lists to disk for later use:bash -c 'dosavepkglists'" \
    --button="gtk-about:bash -c 'doabout'" \
    --button="gtk-close":0 &>/dev/null

# -----------------------------------------------------------------------------|

_trapfunc_() {
	exec 3>&-
	exec 4>&-

	source ${frunningPIDs}
	runningPIDs=${openedFormPIDs[@]}
	[[ "${runningPIDs}" ]] && {
		kill -s 15 ${runningPIDs[@]}
	#	[[ "${#runningPIDs[@]}" -ge 1 ]] && eval "kill -15 ${runningPIDs[@]}"
		sleep 5
	}
	rm -f ${fpipepkgssys} ${fpipepkgslcl} ${frunningPIDs} ${frealtemp}
}
trap '_trapfunc_' EXIT

# -----------------------------------------------------------------------------|

exit $?
