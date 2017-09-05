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

hash paplay 2>/dev/null && [[ -d /usr/share/sounds/freedesktop/stereo/ ]] && {
	export errorSnd="paplay /usr/share/sounds/freedesktop/stereo/dialog-error.oga"
	export infoSnd="paplay /usr/share/sounds/freedesktop/stereo/dialog-information.oga"
}

export yalpamTitle="Yet another Arch Linux PAckage Manager"
export yalpamName="yalpam"
export yalpamVersion="0.0.240"

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

# Prerequisites
# Check to see if all needed tools are present
if ! hash yad 2>/dev/null; then
	msg "yad" "command not found." 10
elif ! hash yaourt 2>/dev/null; then
	msg "yaourt" "command not found." 20
elif [ -z "$(yad --version | grep 'GTK+ 2')" ]; then
	msg "yad" "command uses an unsupported GTK+ platform version." 30
fi

fkey=$(($RANDOM * $$))

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

# ---[ Action functions ]------------------------------------------------------|

doreinstpkg() {
	xterm -geometry 152x32 -e "[[ \"$1\" == \"pacman\" ]] && { sudo $1 -Sy --force --noconfirm $2; } || { $1 -Sya --force --noconfirm $2; }"
	doscan4pkgs
	return
}
export -f doreinstpkg

doremovepkg() {
	xterm -geometry 152x32 -e "sudo $1 -Rcsn $2"
	doscan4pkgs
	return
}
export -f doremovepkg

doinstpkg() {
	local packagenames=
	local ret=
	until [[ "${packagenames}" ]] || [[ $ret -eq 1 ]]; do
		packagenames=$(yad	--entry --width=320 --borders=9 --align=center --center --fixed \
					--skip-taskbar --title="Enter package name(s)..." \
					--text="Input here one or more package names separated\nby <i>blank</i> characters:" \
					--entry-text="${packagenames}" \
					--button="gtk-cancel:1" --button="gtk-ok:0") &
		local pid=$(pidof yad)
		sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
		wait ${pid}
		local ret=$?
		[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
		[[ ${ret-1} -gt 1 ]] && ret=1
	done

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
	$1 || $(${infoSnd})
	return
}
export -f doexecpkg

domanpage() {
	man $1 &>/dev/null || $(${infoSnd}) && xterm -geometry 84x40 -e man $1
	return
}
export -f domanpage

doaction() {
	export frunningPIDs
	export -f doscan4pkgs

	export manager=$1
	export package=$3

	yad	--form --width=340 --borders=3 --align=center --fixed \
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
		--button=$"Close!gtk-close!Closes the current dialog":0 &>/dev/null &

	local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
#	local ret=$?
	[[ -e ${frunningPIDs} ]] && sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
	return
}
export -f doaction

# ---[ Buttons functionality ]-------------------------------------------------|

doabout() {
	yad	--form --width=480 --borders=9 --align=center --fixed \
		--skip-taskbar --title="About ${yalpamTitle}" \
		--image="system-software-install" --image-on-top \
		--text="<span font_size='medium' font_weight='bold'>${yalpamTitle} v${yalpamVersion}</span>\nby John A Ginis (a.k.a. <a href='https://github.com/drxspace'>drxspace</a>)\n<span font_size='small'>build on Summer of 2017</span>" \
		--field="":lbl '' \
		--field="...":lbl '' \
		--field="":lbl '' \
		--buttons-layout="center" \
		--button=$"Close!gtk-close!Closes the current dialog":0 &>/dev/null &

	local pid=$!
	sed -i "s/openedFormPIDs=(\(.*\))/openedFormPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
#	local ret=$?
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
			grep -vx "$(pacman -Qqm)" > "${dirname}"/pkgsSYSTEM.txt
		pacman -Qqm > "${dirname}"/pkgsLOCAL.txt
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
		yad --progress --pulsate --auto-close --no-buttons --width=320 --align=center --center --borders=9 --skip-taskbar --title="Querying packages" --text-align="center" --text="One moment please. Querying <i>System</i> packages..."

	echo -e '\f' >> "${fpipepkgslcl}"
	pacman -Qm | awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgslcl}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=320 --align=center --center --borders=9 --skip-taskbar --title="Querying packages" --text-align="center" --text="One moment please. Querying <i>Local/AUR</i> packages..."
	return
}
export -f doscan4pkgs

# -----------------------------------------------------------------------------|

exec 3<> ${fpipepkgssys}
exec 4<> ${fpipepkgslcl}

echo 'openedFormPIDs=()' > ${frunningPIDs}

yad --plug="${fkey}" --tabnum=1 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction pacman %s %s %s"' \
    --text "List of <i>System</i> packages:" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':num --column='Package Name' --column='Package Version' <&3 &>/dev/null &

yad --plug="${fkey}" --tabnum=2 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction yaourt %s %s %s"' \
    --text "List of <i>Local/AUR</i> packages:" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':num --column='Package Name' --column='Package Version' <&4 &>/dev/null &

yad --key="${fkey}" --notebook --width=480 --height=640 \
    --borders=9 --tab-borders=3 --active-tab=1 --focus-field=1 \
    --window-icon="system-software-install" --title="${yalpamTitle} v${yalpamVersion}" \
    --image="system-software-install" --image-on-top \
    --text="<span font_size='medium' font_weight='bold'>View Lists of Installed Packages</span>\n\
These are packages from all enabled repositories except for <i>base</i> repository. Also, you\'ll find packages that are locally installed such as <i>AUR</i> packages." \
    --tab=" <i>System</i> packages category" --tab=" <i>Local/AUR</i> packages category" \
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
		eval "kill -15 ${runningPIDs[@]}"
	#	[[ "${#runningPIDs[@]}" -ge 1 ]] && eval "kill -15 ${runningPIDs[@]}"
		sleep 5
	}
	rm -f ${fpipepkgssys} ${fpipepkgslcl} ${frunningPIDs}
}
trap '_trapfunc_' EXIT

# -----------------------------------------------------------------------------|



exit $?
