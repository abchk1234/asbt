#!/bin/bash
# asbt : A tool to manage packages in a local slackbuilds repository.
##
# Copyright (C) 2014 Aaditya Bagga <aaditya_gnulinux@zoho.com>
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

ver="0.9.5 (dated: 28 June 2014)" # Version

# Variables used:

repodir="/home/$USER/git/slackbuilds" # Repository for slackbuilds. Required.
#repodir="/home/$USER/slackbuilds" # Alternate repository for slackbuilds.

srcdir="/home/$USER/src" # Where the downloaded source is to be placed.
#srcdir="" # Leave blank for saving it in the same directory as the slackbuild.

outdir="/home/$USER/packages" # Where the built package will be placed.
#outdir="" # Leave it blank for putting built package(s) in /tmp.

gitdir="/home/$USER/git/slackbuilds/.git" # Slackbuilds git repo directory.
#gitdir"/home/$USER/slackbuilds/.git" # Alternate git repo directory.

config="/etc/asbt/asbt.conf" # Config file which over-rides above defaults.
#config="/home/$USER/.asbt.conf" # Alternate config file.

editor="/usr/bin/vim" # Editor for viewing/editing slackbuilds.
#editor="/usr/bin/nano" # Alternate editor

#--------------------------------------------------------------------------------------#

# Exit on error(s) - optional - as most errors are manually handled.
#set -e

# Double brackets [[ ]] are used to optimise condition checking,
# as they are a bash built-in compared to [ ] (test instruction).
# But as they can reduce portability to the bourne shell sh,
# so its used only where a function is called many times.

package="$2" # Name of package input by the user.
# Since version 0.9.5, this is default for options that take a single argument;
# else $package is modified in a loop for processing multiple packages.

# Check the no of input parameters
check-input () {
	if [[ $1 -gt 2 ]] ; then
		echo "Invalid syntax. Type asbt -h for more info."
		exit 1
	fi
}

# Check number of arguments 
check-option () {
	if [[ ! "$1" ]]; then
		echo "Additional parameter required for this option. Type asbt -h for more info."
		exit 1
	fi
}

# Check for the configuration file 
check-config () {
	if [[ -e "$config" ]]; then
		. "$config"
	fi
}

# Check the repo directory
check-repo () {
	if [[ ! -d "$repodir" ]] || [[ $(ls "$repodir" | wc -w) -eq 0 ]]; then
		echo "SlackBuild repository $repodir does not exist or is empty."
		echo "Use asbt -S to setup the tool."
		exit 1
	fi
}

edit-config () {
	echo "Enter your password to view or edit the configuration file $config"
	if [ -e $editor ]; then
	       sudo -k $editor $config
	elif [ -e /usr/bin/nano ]; then
	       sudo -k nano $config
	elif [ -e /usr/bin/vim ]; then
		sudo -k vim $config
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
	if [ "$ch2" == "n" ] || [ "ch2" == "N" ]; then
		exit 1
	else
		# A workaround has to be applied to clone the git directory as the basename of the repodir
		cd "$repodir/.." && rmdir --ignore-fail-on-non-empty $(basename "$repodir") && git clone git://slackbuilds.org/slackbuilds.git $(basename "$repodir")
		# Now check if the git repo was cloned successfully or the directory was just removed
		if [ ! -d "$repodir" ]; then
			# Again try to clone the git repo
			cd "$repodir/.." | exit 1
			git clone git://slackbuilds.org/slackbuilds.git $(basename "$repodir")
		fi
	fi
}

# Setup function
setup () {
	if [ ! -d "$repodir" ]; then
		echo "Slackbuild repository not present."
	       	echo -n "Press y to set it up, or n to exit [Y/n]: "
		read -e ch
		if [ "$ch" == "n" ] || [ "$ch" == "N" ]; then
			exit 1
		else
			echo "Default Slackbuilds directory: /home/$USER/slackbuilds"
	       		echo -n "Press y use it, or n to change [Y/n]: "
			read -e ch1
			if [ "$ch1" == "n" ] || [ "$ch1" == "N" ]; then
				echo "Enter path of existing directory to use, or path of new dirctory to create: "
				read repopath
				if [ -d $repopath ]; then
					repodir="$repopath"
				else
					mkdir "$repopath" | exit 1
					repodir="$repopath"
				fi
			else
				# Default configuration
				if [ ! -d /home/$USER/slackbuilds ]; then
					mkdir /home/$USER/slackbuilds
					repodir="/home/$USER/slackbuilds"
				fi
			fi
		fi
		
		# Now create git repo from upstream
		if [ $(ls "$repodir" | wc -w) -le 0 ]; then
			echo "Slackbuild repository seems to be empty."
			create-git-repo
		fi	

		# Edit the config file to reflect above changes
		edit-config

		# Re-read the config file and check repo
		check-config
		check-repo
		
	elif [ $(ls "$repodir" | wc -w) -le 0 ]; then
		echo "Slackbuild repository seems to be empty."
		create-git-repo
	else
		edit-config || exit 1
		check-config
	fi
}

# Get the full path of a package
get-path() {
	# Check if path to package is specified instead of package name
	if [[ -d "$package" ]]; then
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
	if [[ ! -d "$path" ]]; then
		echo "Directory: $repodir/$package N/A"
		exit 1
	fi
}

get-info () {
	# Source the .info file to get the package details
	if [[ -f "$path/$package.info" ]]; then
		. "$path/$package.info"
		echo "asbt: $path/$package.info sourced."
	else
		echo "asbt: $path/$package.info N/A"
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

# Get info about the source of the package
get-source-data () {
	get-info
	# Check special cases where the package has a separate download for x86_64
	if [[ $(uname -m) == "x86_64" ]] && [[ -n "$DOWNLOAD_x86_64" ]] && [[ -n "$MD5SUM_x86_64" ]]; then
		link="$DOWNLOAD_x86_64"
		arch="x86_64"
	else
		link="$DOWNLOAD"
	fi

	src=$(basename "$link")	# Name of source file

	# Check if src contains PRGNAM in the name
	if [ ! $(echo "$src" | grep "$PRGNAM") ]; then
		# Append PRGNAM to the beginning
		if [ -e "$path/$PRGNAM-$src" ]; then
			md5=$(md5sum "$path/$PRGNAM-$src" | cut -f 1 -d " ")
			pkgnam="$PRGNAM-$src"
			src="$pkgnam"
		elif [ -f "$srcdir/$PRGNAM-$src" ]; then
			md5=$(md5sum "$srcdir/$PRGNAM-$src" | cut -f 1 -d " ")
			pkgnam="$PRGNAM-$src"
			src="$pkgnam"
		# Check src without PRGNAM also
		elif [ -e "$path/$src" ]; then
			md5=$(md5sum "$path/$src" | cut -f 1 -d " ")
		elif [ -f "$srcdir/$src" ]; then
			md5=$(md5sum "$srcdir/$src" | cut -f 1 -d " ")
		fi
	else
		#src alrady contains PRGNAM in the name
		if [ -e "$path/$src" ]; then
			md5=$(md5sum "$path/$src" | cut -f 1 -d " ")
		elif [ -f "$srcdir/$src" ]; then
			md5=$(md5sum "$srcdir/$src" | cut -f 1 -d " ")
		fi
	fi
}

check-source () {
	get-source-data
	# Check if source has already been downloaded
	if [ -e "$path/$src" ]; then
		# Check validity of downloaded source
		if [ "$arch" == "x86_64" ]; then
			if [ "$md5" == "$MD5SUM_x86_64" ]; then
				valid=1
				echo "asbt: md5sum matched."
			else
				valid=0	
			fi
		else
			# Normal package for all arch
			if [ "$md5" == "$MD5SUM" ]; then
				valid=1
				echo "asbt: md5sum matched."
			else
				valid=0
			fi
		fi

	# Check if source present but not linked
	elif [ -f "$srcdir/$src" ]; then
		# Check validity of downloaded source
		if [ "$arch" == "x86_64" ]; then
			if [ "$md5" == "$MD5SUM_x86_64" ]; then
				ln -svf "$srcdir/$src" "$path" && valid=1
			else
				valid=0
			fi
		else
			if [ "$md5" == "$MD5SUM" ]; then
				ln -svf "$srcdir/$src" "$path" && valid=1
			else
				valid=0
			fi
		fi
	else
		valid=0
	fi
}

download-source () {
	echo "Downloading $src"
	# Check if srcdir is specified (if yes, download is saved there)
	if [ -z "$srcdir" ]; then
		wget --tries=5 --directory-prefix="$path" -N "$link" || exit 1
	else
		wget --tries=5 --directory-prefix="$srcdir" -N "$link" || exit 1
		# Check if downloaded package contains the package name or not
		if [ ! $(echo "$src" | grep "$PRGNAM") ] && [ $(echo "$src" | wc -c) -le 15 ]; then
			# Rename it and link it
			mv "$srcdir/$src" "$srcdir/$PRGNAM-$src"
			ln -sf "$srcdir/$PRGNAM-$src" "$path" || exit 1
		else
			# Only linking required
			ln -sf "$srcdir/$src" "$path" || exit 1
		fi
	fi
}

get-package () {
	check-source
	if [ $valid -ne 1 ]; then
		# Download the source
		download-source
	else
		echo "Source: $src present."
	fi
}

check-built-package () {
	# Source the .info file to get the package version 
	if [ -f "$path/$package.info" ]; then
		. "$path/$package.info"
	else
		VERSION="UNKNOWN"
	fi
	# Check if package has already been built
	if [ -f "/tmp/$package"*-"$VERSION"* ] 2>/dev/null || [ -f "$outdir/$package"*-"$VERSION"* ] 2>/dev/null; then
		built=1
		echo "Package: $package($VERSION) already built."
	else
		built=0
	fi
}

process-built-package () {
	# This process-built-package function is used with the process option
	check-built-package
	if [ $built -eq 0 ]; then
		build-package
	fi
}

build-package () {
	check-built-package	
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
	if [ $built -eq 1 ]; then
		echo "Re-building $package"
	else	
		echo "Building $package"
	fi
	# Fix CWD to include path to package
	sed -i 's/CWD=$(pwd)/CWD=${CWD:-$(pwd)}/' "$path/$package.SlackBuild" || exit 1
	# Check if outdir is present (if yes, built package is saved there)
	if [ -z "$outdir" ]; then
		sudo -k CWD="$path" $OPTIONS "$path/$package.SlackBuild" || exit 1
	else
		sudo -k OUTPUT="$outdir" CWD="$path" $OPTIONS "$path/$package.SlackBuild" || exit 1
	fi 
	# After building revert the slackbuild to original state
	sed -i 's/CWD=${CWD:-$(pwd)}/CWD=$(pwd)/' "$path/$package.SlackBuild"
}

install-package () {
	# Check if package present
	if [[ $(ls "$outdir/$package"* 2> /dev/null) ]] || [[ $(ls "/tmp/$package"* 2> /dev/null) ]]; then
		pkgpath=$(ls -t "/tmp/$package"* "$outdir/$package"* 2> /dev/null | head -n 1)
		# Check if package is installed 
		if [[ $(ls -t "/var/log/packages/$package"* 2> /dev/null) ]]; then
			echo "(Re)installing $package"
			sudo -k /sbin/upgradepkg --reinstall "$pkgpath"
		else
			echo "Installing $package"
			sudo -k /sbin/installpkg "$pkgpath"
		fi
	else
		echo "Package $package: N/A"
		#exit 1
	fi 
}

upgrade-package () {
	# Check if package present
	if [[ `ls "$outdir/$package"* 2> /dev/null` ]] || [[ `ls "/tmp/$package"* 2> /dev/null` ]]; then
		pkgpath=`ls -t "/tmp/$package"* "$outdir/$package"* 2> /dev/null | head -n 1`
		echo "Upgrading $package"
		sudo -k /sbin/upgradepkg "$pkgpath"
	else
		echo "Package $package: N/A"
		#exit 1
	fi 
}

# Program options
# Modular approach is used by calling functions for each task
case "$1" in
search|-s)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	find -L "$repodir" -maxdepth 2 -mindepth 1 -type d -iname "*$package*" -printf "%P\n"
	;;
query|-q)
	check-input "$#"
	check-option "$2"
	find "/var/log/packages" -maxdepth 1 -type f -iname "*$package*" -printf "%f\n" | sort
	;;
find|-f)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	echo -e "In slackbuilds repository:"
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
	get-content "$path/README"
	[ -f "$path/README.Slackware" ] && cat "$path/README.Slackware"
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
	ls $path
	;;
longlist|-L)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	ls -l $path
	;;
enlist|-e)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	echo -e "Grepping for $package in the slackbuild repository...\n"
	for i in $(find -L "$repodir" -type f -name "*.info"); do 
		(grep "$package" $i && printf "@ $i\n\n"); 
	done
	;;
track|-t)
	check-input "$#"
	check-option "$2"
	check-config
	echo "Source:"
	find "$srcdir" -maxdepth 1 -type f -iname "$package*"
	echo -e "\nBuilt:"
	find "$outdir" -maxdepth 1 -type f -iname "$package*"
	find "/tmp" -maxdepth 1 -type f -iname "$package*"
	;;
goto|-g)
	check-input "$#"
	check-option "$2"
	check-config
	check-repo
	get-path
	if [ "$TERM" == "linux" ]; then
		echo "Goto: N/A"
		exit 1
	fi
	if [ -e /usr/bin/xfce4-terminal ]; then
        	xfce4-terminal --working-directory="$path"
	elif [ -e /usr/bin/konsole ]; then
		konsole --workdir "$path"
	elif [ -e /usr/bin/xterm ]; then
		xterm -e 'cd "$path" && /bin/bash'
	else
		echo "Goto: N/A"
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
		get-package
		if [ $valid -eq 1 ]; then
			echo -n "Re-download? [y/N]: "
			read -e choice
			if [ "$choice" == y ] || [ "$choice" == Y ]; then
				download-source
			fi
		fi
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
				echo "Only one package can be built at a time."
				exit 1
			fi
		done
		# Revert package name, as it could have been changed while checking the arguments.
		package="$pname"
	else
		OPTIONS=""
	fi
	get-path
	build-package
	;;
install|-I)
	check-option "$2"
	check-config
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo
		install-package
	done
	;;
upgrade|-U)
	check-option "$2"
	check-config
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo
		upgrade-package
	done
	;; 
remove|-R)
	check-option "$2"
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo
		# Check if package is installed 
		if [ -f "/var/log/packages/$package"* ]; then
			echo "Removing $package"
			rpkg=`ls "/var/log/packages/$package"*`
			sudo -k /sbin/removepkg "$rpkg"
		elif [ $? -eq 1 ]; then
			echo "Package $i: N/A"
		else
			echo "Unable to remove $i"
			#exit 1
		fi
	done
	;;
process|-P)
	check-option "$2"
	check-config
	check-repo
	for i in $(echo $* | cut -f 2- -d " "); do
		package="$i"
		echo 
		get-path
		echo "Processing $package..."
		get-package || exit 1
		process-built-package || exit 1
		# Check if package is already installed
		if [[ -f "/var/log/packages/$package"* ]]; then
			upgrade-package
		elif [[ ! -f "/var/log/packages/$package"* ]]; then
			install-package
		else
			echo "Failed to install $i"
			#exit 1
		fi
	done
	;;
details|-D)
	check-input "$#"
	check-option "$2"
	if [ -f /var/log/packages/$package* ]; then
		less /var/log/packages/$package*
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

	if [ "$2" == "--dry-run" ]; then
		flag=1
		# Shift argument left so that cleanup is handled same whether dry-run is specified or not.
		shift
	else
		flag=0
	fi

	if [ "$2" == "src" ]; then
		check-src-dir
		# Now find the names of the packages (irrespective of the version) and sort it and remove non-unique entries
		for i in $(find "$srcdir" -maxdepth 1 -type f -printf "%f\n" | rev | cut -d "-" -f 2- | rev | sort -u); do
			# Remove all but the 3 latest (by date) source packages
			if [ $flag -eq 1 ]; then
				# Dry-run; only display packages to be deleted
				ls -td -1 "$srcdir/$i"* | tail -n +4
			else
				rm -v $(ls -td -1 "$srcdir/$i"* | tail -n +4) 2>/dev/null
			fi
		done
	elif [ "$2" == "pkg" ]; then
		check-out-dir
		for i in $(find "$outdir" -maxdepth 1 -type f -printf "%f\n" | rev | cut -d "-" -f 4- | rev | sort -u); do
			if [ $flag -eq 1 ]; then
				# Dry-run
				ls -td -1 "$outdir/$i"* | tail -n +4
			else
				rm -vf $(ls -td -1 "$outdir/$i"* | tail -n +4) 2>/dev/null
			fi
		done
	else
		echo "Unrecognised option for tidy. See the man page for more info."
		exit 1
	fi
	;;
--update|-u)
	check-config
	if [ -z "$gitdir" ]; then
		echo "Git directory not specified."
		exit 1
	fi
	if [ -d "$gitdir" ]; then
		echo "Updating git repo $gitdir"
		cd "$gitdir/.." && git stash save --quiet
		git --git-dir="$gitdir" --work-tree="$gitdir/.." pull origin master || exit 1
	else
		echo "Git directory $gitdir doesnt exist.."
		exit 1
	fi
	;;
--all|-a)
	find "/var/log/packages" -name "*_SBo*" -printf "%f\n" 
	echo -ne "\nTotal: "
	find "/var/log/packages" -name "*_SBo*" -printf "%f\n" | wc -l
	;;
--check|-c)
	check-config
	check-repo
	for i in /var/log/packages/*_SBo*; do
		package=$(basename "$i" | rev | cut -d "-" -f 4- | rev)
		pkgver=$(basename "$i" | rev | cut -d "-" -f 3 | rev)
		# Make an exception for virtualbox-kernel package
		if [[ "$package" == "virtualbox-kernel" ]] || [[ "$package" == "virtualbox-kernel-addons" ]]; then
 			pkgver=$(echo $pkgver | cut -d "_" -f 1)
		fi
		
		path=$(find -L "$repodir" -maxdepth 2 -type d -name "$package")
		
		if [[ -f "$path/$package.info" ]]; then
			. "$path/$package.info"
		else
			# For packages not present in slackbuilds repo
			VERSION="$pkgver"
		fi
		
		if [[ ! "$pkgver" == "$VERSION" ]]; then
			printf "$package:\t$pkgver -> $VERSION\n"
		fi
	done
	;;
--setup|-S)
	check-config
	setup
	;;
--version|-V)
        echo -e "asbt version-$ver" ;;
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
	if [ -d "$repodir" ]; then
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
	[--check,-c]	[--all,-a]	[--changelog,-C]
	[--version,-V]	[--setup,-S]	[--help,-h]
	
Using repository: $repo
For more info, see the man page and/or the README.
EOF
	unset repo
       ;;
esac

# Cleanup
unset repodir
unset package
unset path
unset srcdir
unset outdir
unset pkgname
unset pkgpath
unset link
unset arch
unset conf
unset src
unset pkgnam
unset md5
unset valid
unset built
unset editor
unset choice
exit 0

