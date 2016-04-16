#!/bin/bash
# asbt: A tool to manage packages in a local slackbuilds repository.
##
# Copyright (C) 2014-2015 Aaditya Bagga <aaditya_gnulinux@zoho.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed WITHOUT ANY WARRANTY;
# without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
##

VER="1.8.0 (dated: 16 Apr 2016)" # Version

# Variables used:

REPODIR="$HOME/git/slackbuilds" # Repository for slackbuilds. Required.
#REPODIR="/home/$USER/slackbuilds" # Alternate repository for slackbuilds.

SRCDIR="$HOME/src" # Where the downloaded source is to be placed.
#SRCDIR="" # Leave blank for saving it in the same directory as the slackbuild.

PKGDIR="$HOME/pkg" # Where the built package will be placed.
#PKGDIR="" # Leave it blank for putting built package(s) in /tmp.

GITDIR="$HOME/git/slackbuilds/.git" # Slackbuilds git repo directory.
#GITDIR="/home/$USER/slackbuilds/.git" # Alternate git repo directory.

EDITOR="/usr/bin/vim" # Editor for viewing/editing slackbuilds.
#EDITOR="/usr/bin/nano" # Alternate editor.

BUILDFLAGS="MAKEFLAGS=-j2" # Build flags specified while building a package
#BUILDFLAGS="" # No build flags

PAUSE="yes" # Pause for input when using superuser privileges.

IGNORE=""  # Packages to ignore while checking updates.

CONFIG="/etc/asbt/asbt.conf" # Config file which over-rides above defaults.

ALTCONFIG="$HOME/.config/asbt.conf" # Alternate config file which overrides above config.

#--------------------------------------------------------------------------------------#

PACKAGE="$2" # Name of package input by the user.
# Since version 0.9.5, this is default for options that take a single argument;
# else $package is modified in a loop for processing multiple packages.

# Colors
BOLD="\e[1m"
CLR="\e[0m"

# Check number of arguments
check_input () {
	if [[ $1 -gt 2 ]] ; then
		echo "Invalid syntax. Type asbt -h for more info."; exit 1
	fi
}

# Check if argument empty
check_arg () {
	if [[ -z $1 ]]; then
		echo "Additional parameter required for this option. Type asbt -h for more info."; exit 1
	fi
}

# Check some special options
check_options () {
	# check_options "$@"
	for i in "$@"; do
		if [[ $i = -n ]]; then
			PAUSE=no
			break
		fi
	done
}

pause_for_input () {
	# Check for override
	if [[ ! $PAUSE = no ]]; then
		echo -e "$BOLD" "Press enter to continue..." "$CLR"; read -r
	fi
}

# Check for the configuration file
check_config () {
	if [[ -e $CONFIG ]]; then
		. "$CONFIG"
	fi
	# Check for alternate config
	if [[ -e $ALTCONFIG ]]; then
		. "$ALTCONFIG"
	fi
}

# Check the repo directory
check_repo () {
	if [[ ! -d $REPODIR ]] || [[ $(find -L "$REPODIR" -maxdepth 1 | wc -w) -le 1 ]]; then
		echo "SlackBuild repository $REPODIR does not exist or is empty."
		echo "To setup the slackbuilds repository 'asbt -S' can be used."
		exit 1
	fi
}

edit_config () {
	if [[ ! -e $ALTCONFIG ]]; then
		# Root privileges required to edit global config file
		SUDO="/usr/bin/sudo"
		echo "Enter your password to view or edit the configuration file $CONFIG"
	else
		# Root privileges not required to edit config in $HOME folder
		SUDO=""
		CONFIG="$ALTCONFIG"
	fi

	if [[ $(type $EDITOR) ]]; then
		$SUDO $EDITOR "$CONFIG"
	elif [[ -e /usr/bin/nano ]]; then
		$SUDO nano "$CONFIG"
	elif [[ -e /usr/bin/vim ]]; then
		$SUDO vim "$CONFIG"
	else
	       echo "Unable to find $EDITOR to edit the configuration file $CONFIG"
	       exit 1
	fi
}

# Check the src and output(package) directories
check_dir () {
	# check_dir $dir
	local dir=$1
	if [[ ! -d $dir ]]; then
		return 1
	fi
	return 0
}

# Clone git repository from slackbuilds.org (SBo)
create_git_repo () {
	echo -n "Clone the Slackbuild repository from www.slackbuilds.org? [Y/n]: "
	read -r -e ch2
	if [[ $ch2 = n ]] || [[ $ch2 = N ]]; then
		exit 1
	else
		# A workaround has to be applied to clone the git directory as the basename of the repodir
		cd "$REPODIR/.." && rmdir --ignore-fail-on-non-empty "$(basename "$REPODIR")" && git clone git://slackbuilds.org/slackbuilds.git "$(basename "$REPODIR")"
		# Now check if the git repo was cloned successfully or the directory was just removed
		if [[ ! -d $REPODIR ]]; then
			# Again try to clone the git repo
			cd "$REPODIR/.." || exit 1
			git clone --depth=15 git://slackbuilds.org/slackbuilds.git "$(basename "$REPODIR")"
		fi
	fi
}

# Get the full path of the package
get_path() {
	# Check if path to package is specified instead of package name
	if [[ -d $PACKAGE ]] && echo "$PACKAGE" | grep -e "/" -e "." -q; then
		PKGPATH=$(readlink -f "$PACKAGE")
		# Get the name of the package
		PACKAGE=$(find -L "$PKGPATH" -maxdepth 1 -type f -name "*.SlackBuild" -printf "%P\n" | cut -f 1 -d ".")
		if [[ -z $PACKAGE ]]; then
			echo "asbt: Unable to process $PKGPATH; SlackBuild not found."
			exit 1
		fi
	elif echo "$PACKAGE" | grep -q "/"; then
		# Non-existing directory
		echo "Invalid path $PACKAGE specified."
		exit 1
	else
		# Search in the slackbuilds repo
		PKGPATH=$(find -L "$REPODIR" -maxdepth 2 -type d -name "$PACKAGE")
	fi
	# Check path (if directory exists)
	if [[ ! -d $PKGPATH ]]; then
		echo "$PACKAGE in $REPODIR N/A"
		exit 1
	fi
}

# Source info file for the package
get_info () {
	# Source the .info file to get the package details
	if [[ -f "$PKGPATH/$PACKAGE.info" ]]; then
		. "$PKGPATH/$PACKAGE.info"
		echo "asbt: $PKGPATH/$PACKAGE.info sourced."
	else
		echo "asbt: $PACKAGE.info in $PKGPATH N/A"
		exit 1
	fi
}

get_content () {
	# get_content $file
	local file=$1
	if [[ -f "$file" ]]; then
		# Return the content of the argument passed.
		cat "$file"
	else
		echo "File: $file N/A"
		exit 1
	fi
}

# Setup function
setup () {
	local repopath
	local ch
	if [[ ! -d $REPODIR ]]; then
		echo "Slackbuild repository not present."
	       	echo -n "Press y to set it up, or n to exit [Y/n]: "
		read -r -e ch
		if [[ $ch = n ]] || [[ $ch = N ]]; then
			exit 1
		else
			echo "Selected Slackbuilds directory: $REPODIR"
	       		echo -n "Press y use it, or n to change [Y/n]: "
			read -r -e ch1
			if [[ $ch1 = n ]] || [[ $ch1 = N ]]; then
				echo "Enter path of existing directory to use, or path of new dirctory to create: "
				read -r -e repopath
				if [[ -d $repopath ]]; then
					REPODIR="$repopath"
				else
					mkdir -p "$repopath" || exit 1
					REPODIR="$repopath"
				fi
			else
				# Use what was set before
				if [[ ! -d $REPODIR ]]; then
					mkdir -p "$REPODIR"
				fi
			fi
		fi
		# Edit the config file to reflect above changes
		if [[ -e $ALTCONFIG ]] && grep -q REPODIR "$ALTCONFIG"; then
			sed "s|REPODIR=.*|REPODIR=\"${REPODIR}\"|" -i "$ALTCONFIG"
		else
			sed "s|REPODIR=.*|REPODIR=\"${REPODIR}\"|" "$CONFIG" >> "$ALTCONFIG"
		fi
		# Now create git repo from upstream
		if [[ $(find -L "$REPODIR" -maxdepth 1 | wc -w) -le 1 ]]; then
			echo "Slackbuild repository seems to be empty."
			create_git_repo
		fi
		# Re-read the config file and check repo
		check_config
		check_repo
	elif [[ $(find -L "$REPODIR" -maxdepth 1 | wc -w) -le 1 ]]; then
		echo "Slackbuild repository $REPODIR seems to be empty."
		create_git_repo
	else
		edit_config || exit 1
		check_config
	fi
}

# Get info about the source of the package
get_src_data () {
	get_info
	# Check special cases where the package has a separate download for x86_64
	if [[ $(uname -m) = x86_64 ]] && [[ ${DOWNLOAD_x86_64:-""} ]]; then
		LINK=($DOWNLOAD_x86_64)
		MD5S=($MD5SUM_x86_64)
	else
		LINK=($DOWNLOAD)
		MD5S=($MD5SUM)
	fi
	# Since links can be multi line, so use a src array..
	for linki in "${LINK[@]}"; do
		SRC+=($(basename "$linki"))	# Name of source files
	done
	# Calculate md5sum of downloaded source
	# Check for source in various locations
	for srci in "${SRC[@]}"; do
		if [[ -f "$SRCDIR/$srci" ]]; then
			MD5+=($(md5sum "$SRCDIR/$srci" | cut -f 1 -d " "))
		elif [[ -f "$SRCDIR/$PRGNAM-$srci" ]]; then
			MD5+=($(md5sum "$SRCDIR/$PRGNAM-$srci" | cut -f 1 -d " "))
		elif [[ -e "$PKGPATH/$srci" ]]; then
			MD5+=($(md5sum "$PKGPATH/$srci" | cut -f 1 -d " "))
		elif [[ -e "$PKGPATH/$PRGNAM-$srci" ]]; then
			MD5+=($(md5sum "$PKGPATH/$PRGNAM-$srci" | cut -f 1 -d " "))
		fi
	done
}

# Check if src is already present
check_source () {
	local srci=$1	# Source item passed as argument
	local md5s=$2	# md5 of src item
	local md5i=$3	# Calculated md5sum
	VALID=0		# Guilty until proven otherwise ;)
	# Check if source has already been downloaded
	if [[ -e $PKGPATH/$srci ]]; then
		# Check validity of downloaded source
		if [[ $md5i = "$md5s" ]]; then
			VALID=1
		fi
	elif [[ -f "$SRCDIR/$srci" ]]; then
		# Check if source present but not linked
		if [[ $md5i = "$md5s" ]]; then
			ln -svf "$SRCDIR/$srci" "$PKGPATH" && VALID=1
		fi
	elif [[ -f "$SRCDIR/$PRGNAM-$srci" ]]; then
		# When src was renamed while saving
		if [[ $md5i = "$md5s" ]]; then
			ln -svf "$SRCDIR/$PRGNAM-$srci" "$PKGPATH/$srci" && VALID=1
		fi
	fi
}

download_source () {
	local srci=$1	# Source item passed as argument
	local linki=$2	# Link of src item
	# Check for unsupported url
	if [[ $linki = UNSUPPORTED ]] || [[ $linki = UNTESTED ]]; then
		echo "Unsupported source in info file"
		exit 1
	fi
	echo "Downloading $srci"
	# Check if srcdir is specified (if yes, download is saved there)
	if [[ -z $SRCDIR ]]; then
		wget --tries=5 --directory-prefix="$PKGPATH" -N "$linki" || exit 1
	else
		wget --tries=5 --directory-prefix="$SRCDIR" -N "$linki" || exit 1
		# Check if downloaded src package(s) contains the package name or not
		# Rename only if src item does not contain program name and is short
		if ! echo "$srci" | grep -q "$PRGNAM" && [[ ${#srci} -le 18 ]]; then
			# Rename it and link it
			echo "Renaming $srci"
			mv -v "$SRCDIR/$srci" "$SRCDIR/$PRGNAM-$srci"
			ln -sf "$SRCDIR/$PRGNAM-$srci" "$PKGPATH/$srci" || exit 1
			echo  # Give a line break
		else
			# Only linking required
			ln -sf "$SRCDIR/$srci" "$PKGPATH" || exit 1
		fi
	fi
}

get_package () {
	# get_package $re
	local re=$1	# Whether to re-download or not
	get_src_data
	for ((i=0; i<${#SRC[*]}; i++)); do
		# Check source for each source item
		check_source "${SRC[$i]}" "${MD5S[$i]}" "${MD5[$i]}"
		if [[ $VALID -ne 1 ]]; then
			# Download the source
			download_source "${SRC[$i]}" "${LINK[$i]}"
		else
			echo "Source: ${SRC[$i]} present and md5sum matched."
			# Check if re-download arg was specified
			if [[ -n "$re" ]]; then
				echo -n "Re-download? [y/N]: "
				read -r -e choice
				if [[ $choice = y ]] || [[ $choice = Y ]]; then
					download_source "${SRC[$i]}" "${LINK[$i]}"
				fi
			fi
		fi
	done
	# Some variables will need to be unset if this function is to be called again
	unset SRC MD5
}

check_built_pkg () {
	# Source the .info file to get the package version
	if [[ -f $PKGPATH/$PACKAGE.info ]]; then
		. "$PKGPATH/$PACKAGE.info"
	else
		VERSION=""
	fi
	# Check if package has already been built
	if [[ $(ls -t "/tmp/${PACKAGE}-${VERSION}"*.t?z 2> /dev/null) ]] || [[ $(ls -t "${PKGDIR}/${PACKAGE}-${VERSION}"*.t?z 2> /dev/null) ]]; then
		BUILT=1
		echo "Package: $PACKAGE($VERSION) already built."
	else
		BUILT=0
	fi
}

build_package () {
	# build_package $rebuild
	local rebuild=$1	# Whether to rebuild or not
	check_built_pkg
	# Check if package was already built and if we dont need to rebuild
	if [[ $BUILT -eq 1 ]] && [[ -z "$rebuild" ]]; then
		return 0
	fi
	# Check for SlackBuild
	if [[ ! -f $PKGPATH/$PACKAGE.SlackBuild ]]; then
		echo "asbt: $PKGPATH/$PACKAGE.SlackBuild N/A"
		exit 1
	fi
	# Check for built package
	if [[ $BUILT -eq 1 ]]; then
		echo "Re-building $PACKAGE"
	else
		echo "Building $PACKAGE"
	fi
	# Fix CWD to include path to package
	sed -i 's/CWD=$(pwd)/CWD=${CWD:-$(pwd)}/' "$PKGPATH/$PACKAGE.SlackBuild" || exit 1
	# Eval buildflags for the pkg from config file
	local pkg_with_uds=$(echo "$PACKAGE" | sed 's/-/_/g')
	eval "BUILD_CONF_OPTS=\${BUILD_${pkg_with_uds}}"
	# Check if pkgdir is present (if yes, built package is saved there)
	# Build options are assumed to be set beforehand.
	if [[ -z $PKGDIR ]]; then
		pause_for_input
		sudo -i CWD="$PKGPATH" $BUILDFLAGS $BUILD_CONF_OPTS "${OPTIONS[@]}" /bin/sh "$PKGPATH/$PACKAGE.SlackBuild" || exit 1
	else
		pause_for_input
		sudo -i OUTPUT="$PKGDIR" CWD="$PKGPATH" $BUILDFLAGS $BUILD_CONF_OPTS "${OPTIONS[@]}" /bin/sh "$PKGPATH/$PACKAGE.SlackBuild" || exit 1
	fi
	# After building revert the slackbuild to original state
	sed -i 's/CWD=${CWD:-$(pwd)}/CWD=$(pwd)/' "$PKGPATH/$PACKAGE.SlackBuild"
}

install_package () {
	# install_pkg $pkg
	local pkg=$1
	local pkgpath # path of package to be installed
	local pkgf # full pkg name as specified in /var/log/packages
	local pkgver # version of current package if available
	# Check if package present
	# Some packages can have a unique version like v19_20140130 (portaudio)
	if [[ $(ls "$PKGDIR/$pkg"-[0-9]*.t?z 2> /dev/null) ]] || [[ $(ls "/tmp/$pkg"-[0-9]*.t?z 2> /dev/null) ]] || [[ $(ls "${PKGDIR}/${pkg}-${VERSION}"-*.t?z 2> /dev/null) ]] || [[ $(ls "/tmp/${pkg}-${VERSION}"-*.t?z 2> /dev/null) ]]; then
		pkgpath=$(ls -t "/tmp/$pkg"-[0-9]*.t?z "/tmp/${pkg}-${VERSION}"-*.t?z "$PKGDIR/$pkg"-[0-9]*.t?z "${PKGDIR}/${pkg}-${VERSION}"-*.t?z 2> /dev/null | head -n 1)
		# Check if package is installed
		if [[ $(ls -t "/var/log/packages/$pkg"-[0-9]* 2> /dev/null) ]]; then
			# Get version of installed package
			pkgf=$(find "/var/log/packages" -maxdepth 1 -type f -name "$pkg-[0-9]*" -printf "%f\n")
			pkgver=$(basename "$pkgf" | rev | cut -f 3 -d "-" | rev)
			# Upgrade the package
			echo -e "Upgrading $pkg($pkgver) using: \n$pkgpath\n"
			pause_for_input
			sudo /sbin/upgradepkg --reinstall "$pkgpath"
		else
			echo -e "Installing $pkg \n(from $pkgpath)\n"
			pause_for_input
			sudo /sbin/installpkg "$pkgpath"
		fi
	else
		echo "Unable to install $pkg: N/A"
		return 1
	fi
}

check_new_pkg () {
	local pkgn="$1" # Package name is first argument
	local pkgv="$2" # Package ver is second argument

	# Skip if package is in ignore list
	if echo "$IGNORE" | grep -q "$pkgn"; then
		return
	fi

	# Make an exception for virtualbox-kernel package
	if [[ $pkgn = "virtualbox-kernel" ]] || [[ $pkgn = "virtualbox-kernel-addons" ]]; then
		pkgv=$(echo "$pkgv" | cut -d "_" -f 1)
	fi

	PKGPATH=$(find -L "$REPODIR" -maxdepth 2 -type d -name "$pkgn")

	if [[ -f "$PKGPATH/$pkgn.info" ]]; then
		. "$PKGPATH/$pkgn.info"
	else
		# For packages not present in slackbuilds repo
		VERSION="$pkgv"
	fi

	if [[ ! $pkgv = "$VERSION" ]]; then
		printf "%-20s %10s -> %-10s\n" "$pkgn" "$pkgv" "$VERSION"
	fi
}

# Print the items in specified array
print_items () {
	local item
	if [[ -z $@ ]]; then
		# No items found
		return 1
	else
		# Print the items
		for item in "$@"; do
			echo "$item"
		done
	fi
}

query_installed () {
	# query_installed $pkg
	local pkg=$1
	# Get list of package items in /var/log/packages that match and print them
	local items=($(find "/var/log/packages" -maxdepth 1 -type f -iname "*$pkg*" -printf "%f\n" | sort))
	# Set count
	COUNT=${#items[@]}
	print_items "${items[@]}"
}

remove_package () {
	# remove_package $pkg
	local pkg=$1
	local rpkg
	# Check if package is installed
	if [[ $(ls "/var/log/packages/$pkg"-[0-9]* 2> /dev/null) ]]; then
		rpkg=$(ls "/var/log/packages/$pkg"-[0-9]*)
		echo "Removing $(echo "$rpkg" | cut -f 5 -d '/')"
		pause_for_input
		sudo /sbin/removepkg "$rpkg"
	elif [[ $? -eq 1 ]]; then
		echo "Package $pkg: N/A"
		exit 1
	else
		echo "Unable to remove $pkg"
		exit 1
	fi
}

search_pkg () {
	# search_pkg $pkg
	local pkg=$1
	check_config
	check_repo
	local items=($(find -L "$REPODIR" -maxdepth 2 -mindepth 2 -type d -iname "*$pkg*" -printf "%P\n" | sort))
	print_items "${items[@]}"
}

find_pkg () {
	# find_pkg $pkg
	local pkg=$1
	check_config
	check_repo
	echo "In slackbuilds repository:"
	while IFS= read -r -d '' pkgn; do
		# Get version
		. "${pkgn}"/*.info 2> /dev/null
		# Display package and version
		echo "$pkgn($VERSION)"
	done < <(find -L "$REPODIR" -mindepth 2 -maxdepth 2 -type d -iname "*$pkg*" -print0)
	echo -e "\nInstalled:"
	find "/var/log/packages" -maxdepth 1 -type f -iname "*$pkg*_SBo" -printf "%f\n"
}

display_readme () {
	check_config
	check_repo
	get_path
	[[ -f $PKGPATH/README ]] && cat "$PKGPATH/README"
	echo ""
	[[ -f $PKGPATH/README.Slackware ]] && cat "$PKGPATH/README.Slackware" && exit $?
	[[ -f $PKGPATH/README.SLACKWARE ]] && cat "$PKGPATH/README.SLACKWARE"
}

view_slackbuild () {
	check_config
	check_repo
	get_path
	if [[ $(type $EDITOR) ]]; then
		"$EDITOR" "$PKGPATH/$PACKAGE.SlackBuild"
	else
		less "$PKGPATH/$PACKAGE.Slackbuild"
	fi
}

get_description () {
	check_config
	check_repo
	get_path
	get_content "$PKGPATH/slack-desc" | grep "$PACKAGE" | cut -f 2- -d ":"
}

list_files () {
	# list_files $long
	local long=$1
	check_config
	check_repo
	get_path
	echo "($PKGPATH)"
	if [[ $long ]]; then
		ls -l "$PKGPATH"
	else
		ls "$PKGPATH"
	fi
}

track_files () {
	# track_files $pkg
	local pkg=$1
	check_config
	echo "Source:"
	find -L "$SRCDIR" -maxdepth 1 -type f -iname "$pkg*"
	echo -e "\nBuilt:"
	find -L "$PKGDIR" -maxdepth 1 -type f -iname "$pkg*"
	find "/tmp" -maxdepth 1 -type f -iname "$pkg*"
}

goto_folder () {
	check_config
	check_repo
	get_path
	if [[ $TERM = linux ]]; then
		echo "Goto on console N/A"
		exit 1
	fi
	if [[ -e /usr/bin/xfce4-terminal ]]; then
		xfce4-terminal --working-directory="$PKGPATH"
	elif [[ -e /usr/bin/konsole ]]; then
		konsole --workdir "$PKGPATH"
	elif [[ -e /usr/bin/xterm ]]; then
		xterm -e "cd $PKGPATH && /bin/bash"
	else
		echo "Could not find a suitable terminal emulator, goto N/A"
		exit 1
	fi
}

get_details () {
	# get_details $pkg
	local pkg=$1
	if [[ $(ls "/var/log/packages/$pkg"-[0-9]* 2> /dev/null) ]]; then
		less /var/log/packages/"$pkg"-[0-9]*
	else
		echo "Details of package $pkg: N/A"
		exit 1
	fi
}

update_repo () {
	check_config
	if [[ -z $GITDIR ]]; then
		echo "Git directory not specified."
		exit 1
	fi
	if [[ -d $GITDIR ]]; then
		echo "Performing git stash"
		cd "$GITDIR/.." && git stash
		echo "Updating git repo $GITDIR"
		git --git-dir="$GITDIR" --work-tree="$GITDIR/.." pull origin master || exit 1
	else
		echo "Git directory $GITDIR doesnt exist.."
		exit 1
	fi
}

display_help () {
	check_config
	if [[ -d "$REPODIR" ]]; then
		repo="$REPODIR"
	else
		repo="N/A"
	fi
	cat << EOF
Usage: asbt <option> [package]
Options-
	[search,-s]	[query,-q]	[find,-f]
	[info,-i]	[readme,-r]	[desc,-d]
	[view,-v]	[goto,-g]	[list,-l]
	[track,-t]	[longlist,-L]	[enlist,-e]
	[get,-G]	[build,-B]	[install,-I]
	[upgrade,-U]	[remove,-R]	[process,-P]
	[details,-D]	[tidy,-T]	[--update,-u]
	[--check,-c]	[--help,-h]	[--changelog,-C]
	[--version,-V]	[--setup,-S]

Using repository: $repo
For more info, see the man page and/or the README.
EOF
}

display_info () {
	check_config
	check_repo
	get_path
	get_content "$PKGPATH/$PACKAGE.info"
}

tidy_dir () {
	# tidy_dir $dir $dry_run
	local dir=$1
	local dry_run=$2
	if [[ $1 = src ]]; then
		if ! check_dir "$SRCDIR"; then
			echo "Source directory $SRCDIR does not exist!"
			exit 1
		fi
		# Now find the names of the packages (irrespective of the version) and sort it and remove non-unique entries.
		# We are assuming the format of the source as name-version.extension which could be incorrect
		for i in $(find -L "$SRCDIR" -maxdepth 1 -type f -printf "%f\n" | rev | cut -d "-" -f 2- | rev | sort -u); do
			# Remove all but the 3 latest (by date) source packages
			local rem=($(ls -td -1 "$SRCDIR/$i"-[0-9]* "$SRCDIR/$i"-v[0-9]* 2>/dev/null | tail -n +4))
			if [[ $dry_run -eq 1 ]]; then
				# Dry-run; only display packages to be deleted
				print_items "${rem[@]}"
			else
				for pkg in "${rem[@]}"; do
					rm -vf "$pkg"
				done
			fi
		done
	elif [[ $1 = pkg ]]; then
		if ! check_dir "$PKGDIR"; then
			echo "Package directory $PKGDIR does not exist!"
			exit 1
		fi
		# Now find the names of the packages (irrespective of the version) and sort it and remove non-unique entries.
		for i in $(find -L "$PKGDIR" -maxdepth 1 -type f -name "*.t?z" -printf "%f\n" | rev | cut -d "-" -f 4- | rev | sort -u); do
			# Remove all but the 3 latest (by date) source packages
			local rem=($(ls -td -1 "$PKGDIR/$i"-[0-9]* 2>/dev/null | tail -n +4))
			if [[ $dry_run -eq 1 ]]; then
				# Dry-run
				print_items "${rem[@]}"
			else
				for pkg in "${rem[@]}"; do
					rm -vf "$pkg"
				done
			fi
		done
	else
		echo "Unrecognised option for tidy. See the man page for more info."
		exit 1
	fi
}

# Program options
# (Modular approach is used by calling functions for each task)

case "$1" in
search|-s)
	check_input $#
	check_arg "$2"
	search_pkg "$2"
	;;
query|-q)
	check_input $#
	check_arg "$2"
	# Check if special options were specified
	if [[ $2 = --all ]]; then
		# Query all packages
		query_installed '*'
		echo -e "\nTotal: $COUNT"
	elif [[ $2 = --sbo ]]; then
		# Query SBo packages
		query_installed '_SBo'
		echo -e "\nTotal: $COUNT"
	else
		# Query specified package
		query_installed "$2"
	fi
	;;
find|-f)
	check_input $#
	check_arg "$2"
	find_pkg "$2"
	;;
info|-i)
	check_input $#
	check_arg "$2"
	display_info
	;;
readme|-r)
	check_input $#
	check_arg "$2"
	display_readme
	;;
view|-v)
	check_input $#
	check_arg "$2"
	view_slackbuild
	;;
desc|-d)
	check_input $#
	check_arg "$2"
	get_description
	;;
list|-l)
	check_input $#
	check_arg "$2"
	list_files
	;;
longlist|-L)
	check_input $#
	check_arg "$2"
	list_files long
	;;
enlist|-e)
	# Check arguments
	if [[ $# -gt 3 ]]; then
		echo "Invalid syntax. Correct syntax for this option is:"
		echo "asbt -e [--rev|--log|--git] <pkg>"
		exit 1
	fi
	check_config
	check_repo
	if [[ $2 = --log ]]; then
		check_arg "$3"
		# Grep the required package from the Changelog
		get_content "$REPODIR/ChangeLog.txt" | grep -w "$3" | less
	elif [[ $2 = --git ]]; then
		check_arg "$3"
		# Search the required package in the git logs.
		git --git-dir="$GITDIR" log --pretty=short --patch-with-stat --grep="$3"
	elif [[ $2 = --rev ]]; then
		check_arg "$3"
		package="$3"
		# Get the list of packages from SBo installed on the system
		from_sbo=($(query_installed 'SBo' | rev | cut -f 4- -d "-" | rev))
		# Represent them in a form in which they can be concurrently searched using grep
		# The package we are searching for is removed from this list using sed
		words=$(echo "${from_sbo[*]}" | tr ' ' '|' | sed "s/$package|//")
		# The first two pipes returns the info file paths and REQUIRES line which matches the package to be searched for;
		# The next pipe limits it to only the info file paths;
		# The next pipe greps for installed packages on the output of previous pipe,
		# ie, it checks for packages that contain the specified package in their info file, and are installed.
		# Together they a unique give list of packages which depend on specified package (reverse dependencies).
		items=($($0 -e "$package" | grep REQUIRES | cut -f 1 -d ":" | grep -E -w "$words" | uniq))
		print_items "${items[@]}"
	else
		check_arg "$2"
		# Find files which contain specified keyword
		find -L "$REPODIR" -type f -name "*.info" -exec grep -H -w "$2" {} \;
	fi
	;;
track|-t)
	check_input $#
	check_arg "$2"
	track_files "$2"
	;;
goto|-g)
	check_input $#
	check_arg "$2"
	goto_folder
	;;
get|-G)
	check_arg "$2"
	check_config
	check_repo
	shift # to get rid of the -G option
	check_options "$@" # whether to pause or not
	# Run a loop for getting all the packages
	for i in "$@"; do
		# Check for -n option
		[[ $i = -n ]] && continue
		PACKAGE=$i
		echo
		get_path
		if [[ $PAUSE = no ]]; then
			get_package
		else
			get_package "redownload"
		fi
	done
	;;
build|-B)
	check_arg "$2"
	check_config
	check_repo
	# Check arguments
	if [[ $# -gt 2 ]]; then
		shift; shift # to get rid of -B and pkg
		check_options "$@" # whether to pause or not
		for i in "$@"; do
			# Check for -n option
			[[ $i = -n ]] && continue
			OPTIONS+=($i)
		done
		# Try to check that the arguments specified do not specify multiple packages
		for opt in "${OPTIONS[@]}"; do
			pkgpath=$(find -L "$REPODIR" -maxdepth 2 -type d -name "$opt")
			if [[ -d "$pkgpath" ]]; then
				echo "Only one package can be built at a time."
				exit 1
			fi
		done
	else
		OPTIONS=""
	fi
	get_path
	build_package "rebuild"
	;;
install|-I|upgrade|-U)
	check_arg "$2"
	check_config
	shift # Get rid of -I
	check_options "$@" # whether to pause or not
	for i in "$@"; do
		# Check for -n option
		[[ $i = -n ]] && continue
		echo
		install_package "$i"
	done
	;;
remove|-R)
	check_arg "$2"
	shift # Get red of -R
	check_options "$@" # whether to pause or not
	for i in "$@"; do
		# Check for -n option
		[[ $i = -n ]] && continue
		echo
		remove_package "$i"
	done
	;;
process|-P)
	check_arg "$2"
	check_config
	check_repo
	check_options "$@" # whether to pause or not
	if [[ $2 = "--upgrade" ]] || [[ $2 = "-u" ]]; then
		# Get list of packages that need to be updated
		for pkg in $("$0" -c | cut -f 1 -d " "); do
			# Check for empty output, ie, no pkg needs to updated
			if [[ $pkg ]]; then
				# Call the script itself with new parameters
				if [[ $PAUSE = no ]]; then
					"$0" -P "$pkg" -n
				else
					"$0" -P "$pkg"
				fi
			fi
		done
		exit 0
	fi
	shift # to get rid of -P
	for i in "$@"; do
		# Check for -n option
		[[ $i = -n ]] && continue
		PACKAGE="$i"
		echo 
		get_path
		echo -e "$BOLD" "Processing $PACKAGE..." "$CLR"
		get_package || continue
		build_package || continue
		install_package "$PACKAGE"
	done
	;;
details|-D)
	check_input $#
	check_arg "$2"
	get_details "$2"
	;;
tidy|-T)
	check_config
	# Check arguments
	if [[ $# -gt 3 ]]; then
		echo "Invalid syntax. Correct syntax for this option is:"
		echo "asbt -T [--dry-run] <src> or asbt -T [--dry-run] <pkg>"
		exit 1
	fi
	if [[ $2 = --dry-run ]]; then
		flag=1
		# Shift argument left so that cleanup is handled same whether dry-run is specified or not.
		shift
	else
		flag=0
	fi
	tidy_dir "$2" $flag
	;;
--update|-u) update_repo ;;
--check|-c)
	check_input $#
	check_config
	check_repo
	# Check if --all option was specified
	if [[ $2 = all ]] || [[ $2 = --all ]]; then
		# Ignore/unset the ignore variable
		unset IGNORE
		# Check all installed packages
		for i in /var/log/packages/*; do
			package=$(basename "$i" | rev | cut -d "-" -f 4- | rev)
			pkgver=$(basename "$i" | rev | cut -d "-" -f 3 | rev)
			check_new_pkg "$package" "$pkgver"
		done
	else
		# Only SBo packages
		for i in /var/log/packages/*_SBo*; do
			package=$(basename "$i" | rev | cut -d "-" -f 4- | rev)
			pkgver=$(basename "$i" | rev | cut -d "-" -f 3 | rev)
			check_new_pkg "$package" "$pkgver"
		done
	fi
	;;
--setup|-S)
	check_config
	setup
	;;
--version|-V)
        echo "asbt version $VER" ;;
--changelog|-C)
	check_config
	check_repo
	get_content "$REPODIR/ChangeLog.txt" | less
	;;
--help|-h) display_help ;;
*)
	display_help
	exit 1
	;;
esac

# Exit with exit status of last executed statement
exit $?
