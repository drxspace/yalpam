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
#
set -x

[[ -x "$(which paplay)" ]] && [[ -d /usr/share/sounds/freedesktop/stereo/ ]] && {
	export ErrorSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/dialog-error.oga"
	export InfoSnd="$(which paplay) /usr/share/sounds/freedesktop/stereo/dialog-information.oga"
}

# Check to see if all needed tools are present
# Prerequisites
if ! hash yad &>/dev/null; then
	$(${ErrorSnd});
	if ! hash notify-send &>/dev/null; then
		echo -e ":: \e[1myad\e[0m command not found." 1>&2;
		exit 10;
	else
		notify-send "Yet another Arch Linux PAckage Manager" "<b>yad</b> command not found." -i face-worried;
		exit 20;
	fi
elif [ -n $(yad --version | grep "GTK+ 2") ]; then
	notify-send "Yet another Arch Linux PAckage Manager" "<b>yad</b> command uses an unsupported <i>GTK+ platform</i> version." -i face-worried
	$(${InfoSnd}); exit 30;
fi

fkey=$(($RANDOM * $$))

export fpipepkgssys=$(mktemp -u --tmpdir pkgssys.XXXXXXXX)
export fpipepkgslcl=$(mktemp -u --tmpdir pkgslcl.XXXXXXXX)
mkfifo "${fpipepkgssys}" "${fpipepkgslcl}"
export frunningPIDs=$(mktemp -u --tmpdir runningPIDs.XXXXXXXX)

#export V=true				# V for verbose
#	${V} && { echo "$1 $2 $3 $4" 1>&2; }
# --close-on-unfocus
# declare/local -x

declare -a runningPIDs=()

# ---[ Action functions ]------------------------------------------------------|

doreinstpkg() {
	xterm -e "[[ \"$1\" == \"pacman\" ]] && { sudo $1 -Sy --force --noconfirm $2; } || { $1 -Sya --force --noconfirm $2; }"
	doscan4pkgs
	return
}
export -f doreinstpkg

doremovepkg() {
	xterm -e "sudo $1 -Rsun $2"
	doscan4pkgs
	return
}
export -f doremovepkg

doinstpkg() {
	doscan4pkgs
	return
}
export -f doinstpkg

doexecpkg() {
	exec "$(which $1 &>/dev/null)" || $(${InfoSnd})
	return
}
export -f doexecpkg

domanpage() {
	xterm -e "man $1 || $(${InfoSnd})"
	return
}
export -f domanpage

doaction() {
	export -f doscan4pkgs
	export InfoSnd
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
	yad	--form --width=400 --borders=9 --align=center --center --fixed \
		--skip-taskbar --close-on-unfocus --title="About Yet another Arch Linux PAckage Manager" \
		--image="system-software-install" --image-on-top \
		--text="<span font_size='medium' font_weight='bold'>Yet another Arch Linux PAckage Manager</span>\nby John A Ginis (a.k.a. <a href='https://github.com/drxspace'>drxspace</a>)\n<span font_size='small'>build on Summer of 2017</span>" \
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
    --window-icon="system-software-install" --title="Yet another Arch Linux PAckage Manager" \
    --image="system-software-install" --image-on-top \
    --text="<span font_size='medium' font_weight='bold'>View Lists of Installed Packages</span>\n\
These are packages from all enabled repositories except for <i>base</i> repository. Also, you\'ll find packages that are locally installed such as <i>AUR</i> packages." \
    --tab=" <i>System</i> packages category" --tab=" <i>Local/AUR</i> packages category" \
    --button="<span color='#0066ff'>List packages</span>!system-search!Scans databases for installed packages:bash -c 'doscan4pkgs'" \
    --button="Save packages!gtk-save!Saves packages lists to disk:bash -c 'dosavepkglists'" \
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
