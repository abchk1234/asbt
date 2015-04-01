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
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
##

ver="1.6 (dated: 21 Mar 2015)" # Version

# Variables used:

repodir="$HOME/git/slackbuilds" # Repository for slackbuilds. Required.
#repodir="/home/$USER/slackbuilds" # Alternate repository for slackbuilds.

srcdir="$HOME/src" # Where the downloaded source is to be placed.
#srcdir="" # Leave blank for saving it in the same directory as the slackbuild.

outdir="$HOME/packages" # Where the built package will be placed.
#outdir="" # Leave it blank for putting built package(s) in /tmp.

gitdir="$HOME/git/slackbuilds/.git" # Slackbuilds git repo directory.
#gitdir"/home/$USER/slackbuilds/.git" # Alternate git repo directory.

editor="/usr/bin/vim" # Editor for viewing/editing slackbuilds.
#editor="/usr/bin/nano" # Alternate editor

buildflags="MAKEFLAGS=-j2" # Build flags specified while building a package
#buildflags="" # No buildflags by default

pause="yes" # Pause for input when using superuser priviliges.

config="/etc/asbt/asbt.conf" # Config file which over-rides above defaults.

altconfig="$HOME/.config/asbt.conf" # Alternate config file which overrides above config.

#--------------------------------------------------------------------------------------#

package="$2" # Name of package input by the user.
# Since version 0.9.5, this is default for options that take a single argument;
# else $package is modified in a loop for processing multiple packages.

# Colors
BOLD="\e[1m"
CLR="\e[0m"

# Check the no of input parameters
check-input () {
	if [[ $1 -gt 2 ]] ; then
		echo "Invalid syntax. Type asbt -h for more info." && exit 1
	fi
}

# Check number of arguments
check-option () {
	if [[ -z $1 ]]; then
		echo "Additional parameter required for this option. Type asbt -h for more info." && exit 1
	fi
}

pause_for_input () {
	# Check for override
	if [[ ! $pause = no ]]; then
		echo -e $BOLD "Press any to continue..." $CLR && read
	fi
}

# Check for the configuration file
check-config () {
	if [[ -e $config ]]; then
		source "$config"
	fi
	# Check for alternate config
	if [[ -e $altconfig ]]; then
		source "$altconfig"
	fi
}

# Check the repo directory
check-repo () {
	if [[ ! -d $repodir ]] || [[ $(ls -L "$repodir" | wc -w) -le 1 ]]; then
		echo "SlackBuild repository $repodir does not exist or is empty."
		echo "To setup the slackbuilds repository 'asbt -S' can be used."
		exit 1
	fi
}

edit-config () {
	if [ ! -e "$altconfig" ]; then
		# Root priviliges required to edit global config file
		SUDO="sudo"
		echo "Enter your password to view or edit the configuration file $config"
	else
		# Root priviliges not required to edit config in $HOME folder
		SUDO=""
		config="$altconfig"
	fi

	if [ -e "$editor" ]; then
		$SUDO $editor $config
	elif [ -e /usr/bin/nano ]; then
		$SUDO nano $config
	elif [ -e /usr/bin/vim ]; then
		$SUDO vim $config
	else
	       echo "Unable to find editor to edit the configuration file $config"
	       exit 1
	fi
}

# Check the src and output(package) directories
check-src-dir () {
	if [ ! -d "$srcdir" ]; then
		echo "Source directory $srcdir does not exist."
		exit 1
	fi
}
check-out-dir () {
	if [ ! -d "$outdir" ]; then
		echo "Output directory $outdir does not exist."
		exit 1
	fi
}

# Clone git repository from slackbuilds.org (SBo)
create-git-repo () {
	echo -n "Clone the Slackbuild repository from www.slackbuilds.org? [Y/n]: "
	read -e ch2
	if [ "$ch2" = n ] || [ "$ch2" = N ]; then
		exit 1
	else
		# A workaround has to be applied to clone the git directory as the basename of the repodir
		cd "$repodir/.." && rmdir --ignore-fail-on-non-empty "$(basename "$repodir")" && git clone git://slackbuilds.org/slackbuilds.git "$(basename "$repodir")"
		# Now check if the git repo was cloned successfully or the directory was just removed
		if [ ! -d "$repodir" ]; then
			# Again try to clone the git repo
			cd "$repodir/.." || exit 1
			git clone git://slackbuilds.org/slackbuilds.git "$(basename "$repodir")"
		fi
	fi
}

# Get the full path of a package
get-path() {
	# Check if path to package is specified instead of package name
	if [[ -d $package ]]; then
		path=$(readlink -f "$package")
		# Get the name of the package
		if [ -f "$path"/*.SlackBuild ]; then
			package=$(find "$path" -name "*.SlackBuild" -printf "%P\n" | cut -f 1 -d ".")
		else
			echo "asbt: Unable to process $package; SlackBuild not found."
			exit 1
		fi
	else
		# Search in the slackbuilds repo
		path=$(find -L "$repodir" -maxdepth 2 -type d -name "$package")
	fi
	# Check path (if directory exists)
	if [[ ! -d $path ]]; then
		echo "$package in $repodir N/A"
		exit 1
	fi
}

get-info () {
	# Source the .info file to get the package details
	if [[ -f "$path/$package.info" ]]; then
		. "$path/$package.info"
		echo "asbt: $path/$package.info sourced."
	else
		echo "asbt: $package.info in $path N/A"
		exit 1
	fi
}

get-content () {
	if [[ -f "$1" ]]; then
		# Return the content of the argument passed.
		cat "$1"
	else
		echo "File: $1 N/A"
		exit 1
	fi
}

# Setup function
setup () {
	if [ ! -d "$repodir" ]; then
		echo "Slackbuild repository $repodir not present."
	       	echo -n "Press y to set it up, or n to exit [Y/n]: "
		read -e ch
		if [ "$ch" = n ] || [ "$ch" = N ]; then
			exit 1
		else
			echo "Selected Slackbuilds directory: $repodir"
	       		echo -n "Press y use it, or n to change [Y/n]: "
			read -e ch1
			if [ "$ch1" = n ] || [ "$ch1" = N ]; then
				echo "Enter path of existing directory to use, or path of new dirctory to create: "
				read -e repopath
				if [ -d "$repopath" ]; then
					repodir="$repopath"
				else
					mkdir -p "$repopath" || exit 1
					repodir="$repopath"
				fi
			else
				# Use what was set before
				if [ ! -d "$repodir" ]; then
					mkdir -p "$repodir"
				fi
			fi
		fi
		# Edit the config file to reflect above changes
		if [ -e "$altconfig" ]; then
			sed -i "s|repodir=.*|repodir=\"${repodir}\"|" "$altconfig"
		else
			sed "s|repodir=.*|repodir=\"${repodir}\"|" "$config" >> "$altconfig"
		fi
		# Now create git repo from upstream
		if [ $(ls -L "$repodir" | wc -w) -le 1 ]; then
			echo "Slackbuild repository seems to be empty."
			create-git-repo
		fi
		# Re-read the config file and check repo
		check-config
		check-repo
	elif [ $(ls -L "$repodir" | wc -w) -le 1 ]; then
		echo "Slackbuild repository $repodir seems to be empty."
		create-git-repo
	else
		edit-config || exit 1
		check-config
	fi
}

# Get info about the source of the package
get-source-data () {
	get-info
	# Check special cases where the package has a separate download for x86_64
	if [[ $(uname -m) == "x86_64" ]] && [[ $DOWNLOAD_x86_64 ]]; then
		arch="x86_64"
		link=($DOWNLOAD_x86_64)
		MD5=($MD5SUM_x86_64)
	else
		link=($DOWNLOAD)
		MD5=($MD5SUM)
	fi
	# Since links can be multi line, so use a src array..
	for linki in ${link[*]}; do
		src+=($(basename "$linki"))	# Name of source files
	done
	# Calculate md5sum of downloaded source
	# Check for source in various locations
	for srci in ${src[*]}; do
		if [[ -f "$srcdir/$srci" ]]; then
			md5+=($(md5sum "$srcdir/$srci" | cut -f 1 -d " "))
		elif [[ -f "$srcdir/$PRGNAM-$srci" ]]; then
			md5+=($(md5sum "$srcdir/$PRGNAM-$srci" | cut -f 1 -d " "))
		elif [[ -e "$path/$srci" ]]; then
			md5+=($(md5sum "$path/$srci" | cut -f 1 -d " "))
		elif [[ -e "$path/$PRGNAM-$srci" ]]; then
			md5+=($(md5sum "$path/$PRGNAM-$srci" | cut -f 1 -d " "))
		fi
	done
}

check-source () {
	local srci=$1	# Source item passed as argument
	local MD5=$2	# MD5 of src item
	local md5i=$3	# Calculated md5sum
	valid=0		# Guilty untill proven otherwise ;)
	# Check if source has already been downloaded
	if [[ -e "$path/$srci" ]]; then
		# Check validity of downloaded source
		if [[ "$md5i" == "$MD5" ]]; then
			valid=1
		fi
	elif [[ -f "$srcdir/$srci" ]]; then
		# Check if source present but not linked
		if [[ "$md5i" == "$MD5" ]]; then
			ln -svf "$srcdir/$srci" "$path" && valid=1
		fi
	elif [[ -f "$srcdir/$PRGNAM-$srci" ]]; then
		# When src was renamed while saving
		if [[ "$md5i" == "$MD5" ]]; then
			ln -svf "$srcdir/$PRGNAM-$srci" "$path/$srci" && valid=1
		fi
	fi
}

download-source () {
	local srci=$1	# Source item passed as argument
	local linki=$2	# Link of src item
	# Check for unsupported url
	if [[ "$linki" == "UNSUPPORTED" ]] || [[ "$linki" == "UNTESTED" ]]; then
		echo "Unsupported source in info file"
		exit 1
	fi
	echo "Downloading $srci"
	# Check if srcdir is specified (if yes, download is saved there)
	if [ -z "$srcdir" ]; then
		wget --tries=5 --directory-prefix="$path" -N "$linki" || exit 1
	else
		wget --tries=5 --directory-prefix="$srcdir" -N "$linki" || exit 1
	fi
	# Check if downloaded src package(s) contains the package name or not
	# Rename only if src item does not contain program name and is short
	if [ ! $(echo "$srci" | grep "$PRGNAM") ] && [ $(echo "$srci" | wc -c) -le 15 ]; then
		# Rename it and link it
		echo "Renaming $srci"
		mv -v "$srcdir/$srci" "$srcdir/$PRGNAM-$srci"
		ln -sf "$srcdir/$PRGNAM-$srci" "$path/$srci" || exit 1
		echo  # Give a line break
	else
		# Only linking required
		ln -sf "$srcdir/$srci" "$path" || exit 1
	fi
}

get-package () {
	local re=$1	# Whether to re-download or not passed as arg
	get-source-data
	for ((i=0; i<${#src[*]}; i++)); do
		# Check source for each source item
		check-source ${src[$i]} ${MD5[$i]} ${md5[$i]}
		if [ $valid -ne 1 ]; then
			# Download the source
			download-source ${src[$i]} ${link[$i]}
		else
			echo "Source: ${src[$i]} present and md5sum matched."
			# Check if re-download arg was specified
			if [[ -n "$re" ]]; then
				echo -n "Re-download? [y/N]: "
				read -e choice
				if [ "$choice" == y ] || [ "$choice" == Y ]; then
					download-source ${src[$i]} ${link[$i]}
				fi
			fi
		fi
	done
	# Some variables will need to be unset if this function is to be called again
	unset src md5
}

check-built-package () {
	# Source the .info file to get the package version
	if [ -f "$path/$package.info" ]; then
		. "$path/$package.info"
	else
		VERSION="UNKNOWN"
	fi
	# Check if package has already been built
	if [[ $(ls -t "/tmp/$package"-"$VERSION"*.t?z 2> /dev/null) ]] || [[ $(ls -t "$outdir/$package"-"$VERSION"*.t?z 2> /dev/null) ]]; then
		built=1
		echo "Package: $package($VERSION) already built."
	else
		built=0
	fi
}

build-package () {
	local rebuild=$1	# Whether to rebuild or not passed as argument
	check-built-package
	# Check if package was already built and if we dont need to rebuild
	if [[ $built -eq 1 ]] && [[ -z "$rebuild" ]]; then
		return 0
	fi
	# Check for SlackBuild
	if [ -f "$path/$package.SlackBuild" ]; then
		chmod +x "$path/$package.SlackBuild"
		if [ $? -eq 1 ]; then
		# Chmod as normal user failed
			echo "Enter your password to take ownership of the slackbuild." && sudo -k chown $USER "$path/$package.SlackBuild" && chmod +x "$path/$package.SlackBuild" || exit 1
		fi
	else
		echo "asbt: $path/$package.SlackBuild N/A"
		exit 1
	fi
	# Check for built package
	if [[ $built -eq 1 ]]; then
		echo "Re-building $package"
	else
		echo "Building $package"
	fi
	# Fix CWD to include path to package
	sed -i 's/CWD=$(pwd)/CWD=${CWD:-$(pwd)}/' "$path/$package.SlackBuild" || exit 1
	# Check if outdir is present (if yes, built package is saved there)
	if [ -z "$outdir" ]; then
		pause_for_input
		sudo -i CWD="$path" $buildflags $OPTIONS "$path/$package.SlackBuild" || exit 1
	else
		pause_for_input
		sudo -i OUTPUT="$outdir" CWD="$path" $buildflags $OPTIONS "$path/$package.SlackBuild" || exit 1
	fi
	# After building revert the slackbuild to original state
	sed -i 's/CWD=${CWD:-$(pwd)}/CWD=$(pwd)/' "$path/$package.SlackBuild"
}

install-package () {
	# Check if package present
	if [[ $(ls "$outdir/$package"-[0-9]*.t?z 2> /dev/null) ]] || [[ $(ls "/tmp/$package"-[0-9]*.t?z 2> /dev/null) ]]; then
		pkgpath=$(ls -t "/tmp/$package"-[0-9]*.t?z "$outdir/$package"-[0-9]*.t?z 2> /dev/null | head -n 1)
		# Check if package is installed
		if [[ $(ls -t "/var/log/packages/$package"-[0-9]* 2> /dev/null) ]]; then
			# Get version of installed package
			local pkg=$(find "/var/log/packages" -maxdepth 1 -type f -name "$package-[0-9]*" -printf "%f\n")
			local pkg_ver=$(basename $pkg | rev | cut -f 3 -d "-" | rev)
			# Upgrade the package
			echo -e "Upgrading $package($pkg_ver) using: \n$pkgpath\n"
			pause_for_input
			sudo /sbin/upgradepkg --reinstall "$pkgpath"
		else
			echo -e "Installing $package \n(from $pkgpath)\n"
			pause_for_input
			sudo /sbin/installpkg "$pkgpath"
		fi
	else
		echo "Unable to install $package: N/A"
		return 1
	fi
}

check-new-pkg () {
	pkgn="$1" # Package name is first argument
	pkgv="$2" # Package ver is second argument

	# Skip if package is in ignore list
	if [[ "$(echo "$ignore" | grep $pkgn)" ]]; then
		return
	fi

	# Make an exception for virtualbox-kernel package
	if [[ $pkgn = "virtualbox-kernel" ]] || [[ $pkgn = "virtualbox-kernel-addons" ]]; then
		pkgv=$(echo $pkgv | cut -d "_" -f 1)
	fi

	path=$(find -L "$repodir" -maxdepth 2 -type d -name "$pkgn")

	if [[ -f "$path/$pkgn.info" ]]; then
		. "$path/$pkgn.info"
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
	array=$* # array is passed as argument
	if [ -z "$array" ]; then
		# No items found
		return 1
	else
		# Print the array
		for i in ${array[*]}; do
			echo $i
		done
	fi
}

query-installed () {
	local pkg=$1	# pkg to be searched for
	# Get list of package items in /var/log/packages that match and print them
	local items=($(find "/var/log/packages" -maxdepth 1 -type f -iname "*$pkg*" -printf "%f\n" | sort))
	print_items ${items[@]}
}

# Program options
# (Modular approach is used by calling functions for each task)

case "$1" in
search|-s)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	items=($(find -L "$repodir" -maxdepth 2 -mindepth 1 -type d -iname "*$package*" -printf "%P\n" | sort))
	print_items ${items[*]}
	;;
query|-q)
	check-input "$#"
	check-option "$2"
	# Check if special options were specified
	if [ "$2" == "--all" ]; then
		# Query all packages
		query-installed '*'
		echo -e "\nTotal: ${#items[@]}"
	elif [ "$2" == "--sbo" ]; then
		# Query SBo packages
		query-installed '_SBo'
		echo -e "\nTotal: ${#items[@]}"
	else
		# Query specified package
		query-installed "$package"
	fi
	;;
find|-f)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	echo "In slackbuilds repository:"
	for i in $(find -L "$repodir" -mindepth 2 -maxdepth 2 -type d -iname "*$package*" -printf "%P\n"); do
		# Get version
		. "$repodir/$i"/*.info 2> /dev/null
		# Display package and version
		echo "$i($VERSION)"
	done
	echo -e "\nInstalled:"
	find "/var/log/packages" -maxdepth 1 -type f -iname "*$package*_SBo" -printf "%f\n"
	;;
info|-i)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	get-content "$path/$package.info"
	;;
readme|-r)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	[ -f "$path/README" ] && cat "$path/README"
	echo ""
	[ -f "$path/README.Slackware" ] && cat "$path/README.Slackware" && exit
	[ -f "$path/README.SLACKWARE" ] && cat "$path/README.SLACKWARE" && exit
	;;
view|-v)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	if [ -e $editor ]; then
		$editor "$path/$package.SlackBuild"
	else
		less "$path/$package.Slackbuild"
	fi
	;;
desc|-d)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	get-content "$path/slack-desc" | grep "$package" | cut -f 2- -d ":"
	;;
list|-l)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	# Echo path too so thats its easier to navigate if required
	echo "($path)"
	ls $path
	;;
longlist|-L)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	# Echo path too so thats its easier to navigate if required
	echo "($path)"
	ls -l $path
	;;
enlist|-e)
	# Check arguments
	if [ $# -gt 3 ]; then
		echo "Invalid syntax. Correct syntax for this option is:"
		echo "asbt -e [--rev] <pkg>"
		exit 1
	fi
	check-config
	check-repo
	if [[ "$2" == "--rev" ]]; then
		check-option "$3"
		package="$3"
		# Get the list of packages from SBo installed on the system
		from_sbo=$(query-installed 'SBo' | rev | cut -f 4- -d "-" | rev)
		# Represent them in a form in which they can be concurrently searched using grep
		# The package we are searching for is removed from this list using sed
		words=$(echo ${from_sbo[*]} | tr ' ' '|' | sed "s/$package|//")
		# The first pipe returns the info file paths and contents which matches the package to be searched for;
		# The second pipe limits it to only the info file paths;
		# The third pipe greps for installed packages on the output of second pipe,
		# ie, it checks for packages that contain the specified package in their info file, and are installed.
		# Together they give list of packages which depend on specified package (reverse dependencies)
		items=($($0 -e $package | cut -f 1 -d ":" | grep -E -w $words))
		print_items ${items[*]}
	else
		check-option "$2"
		# The case for the package itself is skipped using -not -name in find
		for i in $(find -L "$repodir" -type f -name "*.info" -not -name "$package.info"); do
			grep -H "$package" "$i"
		done
	fi
	;;
track|-t)
	check-input "$#"
	check-option "$2"
	check-config
	echo "Source:"
	find -L "$srcdir" -maxdepth 1 -type f -iname "$package*"
	echo -e "\nBuilt:"
	find -L "$outdir" -maxdepth 1 -type f -iname "$package*"
	find "/tmp" -maxdepth 1 -type f -iname "$package*"
	;;
goto|-g)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	if [ "$TERM" == "linux" ]; then
		echo "Goto on console N/A"
		exit 1
	fi
	if [ -e /usr/bin/xfce4-terminal ]; then
        	xfce4-terminal --working-directory="$path"
	elif [ -e /usr/bin/konsole ]; then
		konsole --workdir "$path"
	elif [ -e /usr/bin/xterm ]; then
		xterm -e 'cd "$path" && /bin/bash'
	else
		echo "Could not find a suitable terminal emulator, goto N/A"
		exit 1
	fi
	;;
get|-G)
	check-option "$2"
	check-config
	check-repo
	# Run a loop for getting all the packages
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo
		get-path
		get-package "redownload"
	done
	;;
build|-B)
	check-option "$2"
	check-config
	check-repo
	# Check arguments
	if [ $# -gt 2 ]; then
		OPTIONS=$(echo $@ | cut -d " " -f 3-) # Build options
		# Save package name for later.
		pname="$package"
		# Try to check that the arguments specified do not specify multiple packages
		for i in $(echo $* | cut -f 3- -d " "); do
			package="$i"
			#get-path
			path=$(find -L "$repodir" -maxdepth 2 -type d -name "$package")
			if [[ -d "$path" ]]; then
				echo "Only one package can be built at a time." && exit 1
			fi
		done
		# Revert package name, as it could have been changed while checking the arguments.
		package="$pname"
	else
		OPTIONS=""
	fi
	get-path
	build-package "rebuild"
	;;
install|-I|upgrade|-U)
	check-option "$2"
	check-config
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo
		install-package
	done
	;;
remove|-R)
	check-option "$2"
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo
		# Check if package is installed
		if [ -f "/var/log/packages/$package"-[0-9]* ]; then
			rpkg=$(ls "/var/log/packages/$package"-[0-9]*)
			echo "Removing $(echo $rpkg | cut -f 5 -d '/')"
			pause_for_input
			sudo /sbin/removepkg "$rpkg"
		elif [ $? -eq 1 ]; then
			echo "Package $i: N/A"
		else
			echo "Unable to remove $i"
		fi
	done
	;;
process|-P)
	check-option "$2"
	check-config
	check-repo
	if [[ $2 = "--upgrade" ]] || [[ $2 = "-u" ]]; then
		# Call the script itself with new parameters
		for i in $("$0" -c | cut -f 1 -d " "); do
			# The above command checks for outdated packages
			if [[ -n "$i" ]]; then
				"$0" -P "$i"
			fi
		done
		exit 0
	fi
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo 
		get-path
		echo -e $BOLD "Processing $package..." $CLR
		get-package || continue
		build-package || continue
		install-package
	done
	;;
details|-D)
	check-input "$#"
	check-option "$2"
	if [ -f /var/log/packages/$package-[0-9]* ]; then
		less /var/log/packages/$package-[0-9]*
	else
		echo "Details of package $package: N/A"
		exit 1
	fi
	;;
tidy|-T)
	check-config
	# Check arguments
	if [ $# -gt 3 ]; then
		echo "Invalid syntax. Correct syntax for this option is:"
		echo "asbt -T [--dry-run] <src> or asbt -T [--dry-run] <pkg>"
		exit 1
	fi

	if [ "$2" = "--dry-run" ]; then
		flag=1
		# Shift argument left so that cleanup is handled same whether dry-run is specified or not.
		shift
	else
		flag=0
	fi

	if [ "$2" = src ]; then
		check-src-dir
		# Now find the names of the packages (irrespective of the version) and sort it and remove non-unique entries
		# We are assuming the format of the source as name-version.extension which could be incorrect
		for i in $(find -L "$srcdir" -maxdepth 1 -type f -printf "%f\n" | rev | cut -d "-" -f 2- | rev | sort -u); do
			# Remove all but the 3 latest (by date) source packages
			if [ "$flag" -eq 1 ]; then
				# Dry-run; only display packages to be deleted
				ls -td -1 "$srcdir/$i"* | tail -n +4
			else
				rm -vf $(ls -td -1 "$srcdir/$i"* | tail -n +4) 2>/dev/null
			fi
		done
	elif [ "$2" = pkg ]; then
		check-out-dir
		for i in $(find -L "$outdir" -maxdepth 1 -type f -name "*.t?z" -printf "%f\n" | rev | cut -d "-" -f 4- | rev | sort -u); do
			if [ "$flag" -eq 1 ]; then
				# Dry-run
				ls -td -1 "$outdir/$i-"[0-9]* 2>/dev/null | tail -n +4
			else
				rm -vf $(ls -td -1 "$outdir/$i-"[0-9]* 2>/dev/null | tail -n +4) 2>/dev/null
			fi
		done
	else
		echo "Unrecognised option for tidy. See the man page for more info."
		exit 1
	fi
	;;
--update|-u)
	check-config
	if [[ -z "$gitdir" ]]; then
		echo "Git directory not specified."
		exit 1
	fi
	if [[ -d "$gitdir" ]]; then
		echo "Performing git stash"
		cd "$gitdir/.." && git stash
		echo "Updating git repo $gitdir"
		git --git-dir="$gitdir" --work-tree="$gitdir/.." pull origin master || exit 1
	else
		echo "Git directory $gitdir doesnt exist.."
		exit 1
	fi
	;;
--check|-c)
	check-input "$#"
	check-config
	check-repo
	# Check if --all option was specified
	if [[ "$2" == "all" ]] || [[ "$2" == "--all" ]]; then
		# Ignore/unset the ignore variable
		unset ignore
		# Check all installed packages
		for i in /var/log/packages/*; do
			package=$(basename "$i" | rev | cut -d "-" -f 4- | rev)
			pkgver=$(basename "$i" | rev | cut -d "-" -f 3 | rev)
			check-new-pkg $package $pkgver
		done
	else
		# Only SBo packages
		for i in /var/log/packages/*_SBo*; do
			package=$(basename "$i" | rev | cut -d "-" -f 4- | rev)
			pkgver=$(basename "$i" | rev | cut -d "-" -f 3 | rev)
			check-new-pkg $package $pkgver
		done
	fi
	;;
--setup|-S)
	check-config
	setup
	;;
--version|-V)
        echo "asbt version $ver" ;;
--changelog|-C)
	check-config
	check-repo
	if [ -f "$repodir/ChangeLog.txt" ]; then
		less "$repodir/ChangeLog.txt"
	else
		echo "$repodir/ChangeLog.txt N/A"
		exit 1
	fi
	;;
--help|-h|*)
	check-config
	if [[ -d "$repodir" ]]; then
		repo="$repodir"
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
       ;;
esac

# Exit with exit status of last executed statement
exit $?
