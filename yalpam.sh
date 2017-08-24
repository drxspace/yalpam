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

fkey=$(($RANDOM * $$))

export fpipepkgssys=$(mktemp -u --tmpdir pkgssys.XXXXXXXX)
export fpipepkgslcl=$(mktemp -u --tmpdir pkgslcl.XXXXXXXX)
mkfifo "${fpipepkgssys}" "${fpipepkgslcl}"
export frealtemp=$(mktemp -u --tmpdir realtemp.XXXXXXXX)

export V=true			# V for verbose
declare -a runningProcessIDs=()
export runningProcessIDs

# ---[ Functions ]-------------------------------------------------------------|

function doreinstpkg
{
#	${V} && { echo "$1 $2 $3 $4" 1>&2; }

#	exec xterm

	return
}

function doremovepkg
{
#	${V} && { echo "$1 $2 $3 $4" 1>&2; }

#	exec xterm -geometry=94x24+0+0 -e "man $1"

	return
}

function domanpage
{
#	${V} && { echo "$1 $2 $3 $4" 1>&2; }

#	exec xterm -geometry=94x24+0+0 -e "man $1"

	return
}

function doexecpkg
{
	${V} && { echo "Executing $1" 1>&2; }

#	exec "$(which $1)"

	return
}

export execpkg_cmd='bash -c "doexecpkg $3"'

function dopopup
{
	${V} && { echo "$1 $2 $3 $4" 1>&2; }

	local frmpopup=$(yad --form --width=400 --borders=9 --center --fixed \
		--skip-taskbar --no-buttons --title="Choose action:" \
		--image="dialog-information" --image-on-top \
		--text="Please, choose your desired action from the list below by clicking on its elements" \
		--field="<span color='#006699'>Reinstall selected package</span>!gtk-refresh":fbtn "${doreinstpkg} $1 $3" \
		--field="<span color='#006699'>Uninstall/Remove selected package</span>!gtk-delete":fbtn "${doremovepkg} $1 $3" \
		--field="<span color='#006699'>Try to run selected package</span>!gtk-execute":fbtn "$execpkg_cmd" \
		--field="<span color='#006699'>Try to view the man page of the selected package</span>!gtk-help":fbtn "${domanpage} $3") &
	runningProcessIDs+=($!)
	${V} && { echo "${runningProcessIDs[@]}" 1>&2; }

	return
}

# -----------------------------------------------------------------------------|

export -f doexecpkg
export -f domanpage
export -f dopopup
export -f doreinstpkg
export -f doremovepkg

# -----------------------------------------------------------------------------|

function doabout
{
	local frmabout=$(yad --form --width=400 --borders=9 --center --fixed \
		--skip-taskbar --title="About Yet another Arch Linux PAckage Manager" \
		--image="system-software-install" --image-on-top \
		--text="<span font_size='medium' font_weight='bold'>Yet another Arch Linux PAckage Manager</span>\nby John A Ginis (a.k.a. <a href='https://github.com/drxspace'>drxspace</a>)\n<span font_size='small'>build on Summer of 2017</span>" \
		--field="":lbl \
		--field="These are packages from all enabled repositories except for base and base-devel ones. Also, you\'ll find packages that are locally installed such as AUR packages.":lbl \
		--field="":lbl \
		--buttons-layout="center" \
		--button=$"Κλείσιμο!window-close!Κλείνει το παράθυρο":0) &
	runningProcessIDs+=($!)
	${V} && { echo "${runningProcessIDs[@]}" 1>&2; }

	return
}

function dosavepkglists
{
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

function doscan4pkgs
{
	echo -e '\f' >> "${fpipepkgssys}"
	pacman -Qe |\
		grep -vx "$(pacman -Qg base)" |\
		grep -vx --line-buffered "$(pacman -Qm)" |\
		awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' >> "${fpipepkgssys}"

	echo -e '\f' >> "${fpipepkgslcl}"
	pacman -Qm | awk '{printf "%d\n%s\n%s\n", ++i, $1, $2}' >> "${fpipepkgslcl}"

	return
}

# -----------------------------------------------------------------------------|

export -f doabout
export -f dosavepkglists
export -f doscan4pkgs

# -----------------------------------------------------------------------------|

trap "	rm -f ${fpipepkgssys} ${fpipepkgslcl} ${frealtemp};
	unset fpipepkgssys fpipepkgslcl frealtemp;
	unset V doabout doexecpkg domanpage doreinstpkg doremovepkg dopopup dosavepkglists doscan4pkgs runningProcessIDs;" EXIT

# -----------------------------------------------------------------------------|

exec 3<> ${fpipepkgssys}
exec 4<> ${fpipepkgslcl}

yad --plug="${fkey}" --tabnum=1 --list --no-markup --grid-lines="hor" \
    --dclick-action='bash -c "dopopup pacman %s %s %s"' \
    --text "List of system packages:" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':NUM --column='Package Name' --column='Package Version' <&3 &

yad --plug="${fkey}" --tabnum=2 --list --no-markup --grid-lines="hor" \
    --dclick-action='bash -c "dopopup yaourt %s %s %s"' \
    --text "List of local (includes AUR) packages:" \
    --search-column=2 --expand-column=2 --focus-field=1 \
    --column='No:':NUM --column='Package Name' --column='Package Version' <&4 &

yad --key="${fkey}" --notebook --width=520 --height=640 \
    --borders=9 --tab-borders=3 --active-tab=1 --focus-field=1 \
    --window-icon="system-software-install" --title="Yet another Arch Linux PAckage Manager" \
    --image="system-software-install" --image-on-top \
    --text="<span font_size='medium' font_weight='bold'>View Lists of Installed Packages</span>\n\
These are packages from all enabled repositories except for base and base-devel ones. Also, you\'ll find packages that are locally installed such as AUR packages." \
    --tab=" System" --tab=" Local/AUR" \
    --button="<span color='#0066ff'>List packages</span>!system-search!Scans databases for installed packages:bash -c 'doscan4pkgs'" \
    --button="Save packages!document-save!Saves packages lists to disk:bash -c 'dosavepkglists'" \
    --button="gtk-about:bash -c 'doabout'" \
    --button="gtk-close":0

exec 3>&-
exec 4>&-

[[ ${#runningProcessIDs[@]} -gt 0 ]] && eval "kill -15 ${runningProcessIDs[@]}"

exit $?
