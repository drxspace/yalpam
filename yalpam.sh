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

[[ -x "$(which paplay)" ]] && [[ -d /usr/share/sounds/freedesktop/stereo/ ]] && {
	export errorSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/dialog-error.oga"
	export infoSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/dialog-information.oga"
}

export yalpamTitle="Yet another Arch Linux PAckage Manager"
export yalpamName="yalpam"
export yalpamVersion="0.0.171"

msg() {
	$(${errorSnd});
	if ! hash notify-send &>/dev/null; then
		echo -e ":: \e[1m$1\e[0m $2" 1>&2;
		exit $3;
	else
		notify-send "${yalpamTitle}" "<b>$1</b> $2" -i face-worried;
		exit $(($3 + 5));
	fi
}
export -f msg

# Prerequisites
# Check to see if all needed tools are present
if ! hash yad &>/dev/null; then
	msg "yad" "command not found." 10
elif ! hash yaourt &>/dev/null; then
	msg "yaourt" "command not found." 20
elif [ -z "$(yad --version | grep 'GTK+ 2')" ]; then
	msg "yad" "command uses an unsupported GTK+ platform version." 30
fi

fkey=$(($RANDOM * $$))

export fpipepkgssys=$(mktemp -u --tmpdir pkgssys.XXXXXXXX)
export fpipepkgslcl=$(mktemp -u --tmpdir pkgslcl.XXXXXXXX)
mkfifo "${fpipepkgssys}" "${fpipepkgslcl}"
export frunningPIDs=$(mktemp -u --tmpdir runningPIDs.XXXXXXXX)
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
	xterm -geometry 152x32 -e "sudo $1 -Rsun $2"
	doscan4pkgs
	return
}
export -f doremovepkg

doinstpkg() {
	until [[ "${packagenames}" ]] || [[ $ret -eq 1 ]]; do
		local packagenames=$(yad --entry --width=320 --borders=3 --align=center --center --fixed \
				--skip-taskbar --title="Enter a package name:" \
				--entry-text="${packagenames}" \
				--button="gtk-cancel:1" --button="gtk-ok:0")
		local ret=$?
	done

	[[ $ret -eq 0 ]] && [[ "${packagenames}" ]] && {
		xterm -geometry 152x32 -e "[[ \"$1\" == \"pacman\" ]] && { sudo $1 -Sy \"${packagenames}\"; } || { $1 -Sya \"${packagenames}\"; }"
		doscan4pkgs
	}
	return
}
export -f doinstpkg

doexecpkg() {
	[[ -x "$(which $1 2>/dev/null)" ]] || $(${infoSnd}) && $1
	return
}
export -f doexecpkg

domanpage() {
	man $1 &>/dev/null || $(${infoSnd}) && xterm -geometry 84x40 -e man $1
	return
}
export -f domanpage

doaction() {
	export -f doscan4pkgs
	export manager=$1
	export package=$3
	yad	--form --width=400 --borders=9 --align=center --center --fixed \
		--skip-taskbar --close-on-unfocus --title="Choose action:" \
		--image="dialog-information" --image-on-top \
		--text="Please, choose your desired action from the list below by clicking on its elements." \
		--field="<span color='#006699'>Reinstall/Update selected package</span>!gtk-refresh":btn 'bash -c "doreinstpkg $manager $package"' \
		--field="<span color='#006699'>Uninstall/Remove selected package</span>!gtk-delete":btn 'bash -c "doremovepkg $manager $package"' \
		--field="<span color='#006699'>Install a package of the selected category</span>!gtk-go-down":btn 'bash -c "doinstpkg $manager"' \
		--field="":lbl '' \
		--field="<span color='#006699'>Try to <i>execute</i> the selected package</span>!gtk-execute":btn 'bash -c "doexecpkg $package"' \
		--field="<span color='#006699'>Try to view the <i>man page</i> of the selected package</span>!gtk-help":btn 'bash -c "domanpage $package"' \
		--buttons-layout="center" \
		--button=$"Close!gtk-close!Closes the current dialog":0 &>/dev/null &

	local pid=$!
	sed -i "s/frmPopupPIDs=(\(.*\))/frmPopupPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	local Closed=$?
	if [[ -e ${frunningPIDs} ]]; then
		if [[ ${Closed} ]]; then
			sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
		fi
	fi
	return
}
export -f doaction

# ---[ Buttons functionality ]-------------------------------------------------|

doabout() {
	yad	--form --width=420 --borders=9 --align=center --center --fixed \
		--skip-taskbar --close-on-unfocus --title="About ${yalpamTitle}" \
		--image="system-software-install" --image-on-top \
		--text="<span font_size='medium' font_weight='bold'>${yalpamTitle} v${yalpamVersion}</span>\nby John A Ginis (a.k.a. <a href='https://github.com/drxspace'>drxspace</a>)\n<span font_size='small'>build on Summer of 2017</span>" \
		--field="":lbl '' \
		--field="These are packages from all enabled repositories except for base and base-devel ones. Also, you\'ll find packages that are locally installed such as AUR packages.":lbl '' \
		--field="":lbl '' \
		--buttons-layout="center" \
		--button=$"Close!gtk-close!Closes the current dialog":0 &>/dev/null &

	local pid=$!
	sed -i "s/frmAboutPIDs=(\(.*\))/frmAboutPIDs=(\1 $(echo ${pid}))/" ${frunningPIDs}
	wait ${pid}
	local Closed=$?
	if [[ -e ${frunningPIDs} ]]; then
		if [[ ${Closed} ]]; then
			sed -i "s/ $(echo ${pid})//" ${frunningPIDs}
		fi
	fi
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
		grep -vx --line-buffered "$(pacman -Qm)" |\
		awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgssys}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=300 --align=center --center --fixed --borders=9 --skip-taskbar --title="Querying packages" --text-align="center" --text="One moment please. Querying <i>System</i> packages..."

	echo -e '\f' >> "${fpipepkgslcl}"
	pacman -Qm | awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' |\
		tee -a "${fpipepkgslcl}" |\
		yad --progress --pulsate --auto-close --no-buttons --width=300 --align=center --center --fixed --borders=9 --skip-taskbar --title="Querying packages" --text-align="center" --text="One moment please. Querying <i>Local/AUR</i> packages..."
	return
}
export -f doscan4pkgs

# -----------------------------------------------------------------------------|

trap "rm -f ${fpipepkgssys} ${fpipepkgslcl} ${frunningPIDs};" EXIT

# -----------------------------------------------------------------------------|

exec 3<> ${fpipepkgssys}
exec 4<> ${fpipepkgslcl}

echo 'frmAboutPIDs=()
frmPopupPIDs=()' > ${frunningPIDs}

yad --plug="${fkey}" --tabnum=1 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction pacman %s %s %s"' \
    --text "List of <i>System</i> packages:" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':num --column='Package Name' --column='Package Version' <&3 &

yad --plug="${fkey}" --tabnum=2 --list --grid-lines="hor" \
    --dclick-action='bash -c "doaction yaourt %s %s %s"' \
    --text "List of <i>Local/AUR</i> packages:" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':num --column='Package Name' --column='Package Version' <&4 &

yad --key="${fkey}" --notebook --width=520 --height=640 \
    --borders=9 --tab-borders=3 --active-tab=1 --focus-field=1 \
    --window-icon="system-software-install" --title="${yalpamTitle} v${yalpamVersion}" \
    --image="system-software-install" --image-on-top \
    --text="<span font_size='medium' font_weight='bold'>View Lists of Installed Packages</span>\n\
These are packages from all enabled repositories except for <i>base</i> repository. Also, you\'ll find packages that are locally installed such as <i>AUR</i> packages." \
    --tab=" <i>System</i> packages category" --tab=" <i>Local/AUR</i> packages category" \
    --button="<span color='#0066ff'>List/Update</span>!system-search!Scans databases for installed packages:bash -c 'doscan4pkgs'" \
    --button="Save/Backup!gtk-save!Saves packages lists to disk for later use:bash -c 'dosavepkglists'" \
    --button="gtk-about:bash -c 'doabout'" \
    --button="gtk-close":0

exec 3>&-
exec 4>&-

# -----------------------------------------------------------------------------|

source ${frunningPIDs}
runningPIDs+=${frmAboutPIDs[@]}
[[ "${frmAboutPIDs}" ]] && [[ "${frmPopupPIDs}" ]] && runningPIDs+=' '
runningPIDs+=${frmPopupPIDs[@]}

[[ "${runningPIDs}" ]] && {
	eval "kill -15 ${runningPIDs[@]}" &>/dev/null
#	[[ "${#runningPIDs[@]}" -ge 1 ]] && eval "kill -15 ${runningPIDs[@]}" &>/dev/null
	sleep 4
}

exit $?
