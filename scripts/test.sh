#!/bin/bash
# Some test cases for asbt

#set -e

# Colors
BOLD="\e[1m"
CLR="\e[0m"
GREEN="\e[1;32m"
RED="\e[1;31m"

# Keeping count
PASS=0
FAIL=0

check_fail () {
	if [[ $? -eq 1 ]]; then
		let PASS=$PASS+1
		echo -e "$BOLD" "$GREEN" "Test passed." "$CLR"
	else
		let FAIL=$FAIL+1
		echo -e "$BOLD" "$RED" "Test failed." "$CLR"
	fi
}

check_pass () {
	if [[ $? -eq 0 ]]; then
		let PASS=$PASS+1
		echo -e "$BOLD" "$GREEN" "Test passed." "$CLR"
	else
		let FAIL=$FAIL+1
		echo -e "$BOLD" "$RED" "Test failed." "$CLR"
	fi
}

# Mode: interactive (default) or non interactive
MODE_INTERACTIVE=0

# Check cmd line args
if [ "$1" = 'na' ]; then
	MODE_INTERACTIVE=1
fi

# Help
var='./bin/asbt.sh -h'
echo "$var"
$var; check_pass; echo

# Some common options
options=('-s' '-q' '-i' '-r' '-d' '-l' '-L' '-i' '-r')
for i in "${options[@]}"; do
	# Valid use cases
	echo -e "Checking success...\n"

	var="./bin/asbt.sh $i asbt"
	echo "$var"
	$var; check_pass; echo

	# Invalid use cases
	echo -e "Checking failure...\n"

	var="./bin/asbt.sh $i"
	echo "$var"
	$var; check_fail; echo

	var="./bin/asbt.sh $i asbtasbt"
	echo "$var"
	$var; check_fail; echo

	var="./bin/asbt.sh $i asbt asbt"
	echo "$var"
	$var; check_fail; echo
done

# some special ops
if [ ${MODE_INTERACTIVE} -eq 0 ]; then
	options=('-g' '-v' '-S')
	for i in "${options[@]}"; do
		echo -e "Checking success...\n"

		var="./bin/asbt.sh $i asbt"
		echo "$var"
		$var; check_pass; echo
	done
fi

# Using path instead of name
if [ ${MODE_INTERACTIVE} -eq 0 ]; then
	options=('-d' '-G' '-B')
	for i in "${options[@]}"; do
		echo -e "Checking success...\n"

		var="./bin/asbt.sh $i $HOME/builds/MINE/asbt/asbt"
		echo "$var"
		$var; check_pass; echo
	done
fi

# Misc options
if [ ${MODE_INTERACTIVE} -eq 0 ]; then
	options=('-e' '-e --rev')
	for i in "${options[@]}"; do
		echo -e "Checking success...\n"

		var="./bin/asbt.sh $i gst-libav"
		echo "$var"
		$var; check_pass; echo
	done
fi

# Misc options 2
options=('-u' '-c')
for i in "${options[@]}"; do
	echo -e "Checking success...\n"

	var="./bin/asbt.sh $i"
	echo "$var"
	$var; check_pass; echo
done

# State changing operations
if [ ${MODE_INTERACTIVE} -eq 0 ]; then
	options=('-R' '-U' '-P -n')
	for i in "${options[@]}"; do
		echo -e "Checking success...\n"

		var="./bin/asbt.sh $i asbt"
		echo "$var"
		$var; check_pass; echo
	done
fi

# makefike test
make install DESTDIR=./test
check_pass; echo

echo
echo -e "$BOLD" "Passed:" "$GREEN" "$PASS" "$CLR"
echo -e "$BOLD" "Failed:" "$RED" "$FAIL" "$CLR"
echo
echo -e "$BOLD" "Done." "$CLR"

# exit based on failed cases
#if [ $FAIL -eq 0 ]; then
#	exit 0
#else
#	exit 1
#fi

# just exit
exit $?
