#!/bin/bash
# Some test cases for asbt

# Colors
BOLD="\e[1m"
CLR="\e[0m"

check_fail () {
	if [ $? -eq 1 ]; then
		echo -e $BOLD "Test passed." $CLR
	else
		echo -e $BOLD "Test failed." $CLR
	fi
}

check_pass () {
	if [ $? -eq 0 ]; then
		echo -e $BOLD "Test passed." $CLR
	else
		echo -e $BOLD "Test failed." $CLR
	fi
}

# Help
echo "./bin/asbt.sh"
./bin/asbt.sh; check_pass; echo

# Some common options
options=('-s' '-q' '-f' '-i' '-r' '-d')
for i in ${options[*]}; do
	# Valid use cases
	echo -e "Checking success...\n"

	echo "./bin/asbt.sh $i asbt"
	./bin/asbt.sh $i asbt; check_pass; echo

	# Invalid use cases
	echo -e "Checking failure...\n"

	echo "./bin/asbt.sh $i"
	./bin/asbt.sh $i; check_fail; echo

	echo "./bin/asbt.sh $i asbtasbt"
	./bin/asbt.sh $i asbtasbt; check_fail; echo

	echo "./bin/asbt.sh $i asbt asbt"
	./bin/asbt.sh $i asbt asbt; check_fail; echo
done

# Using path instead of name
options=('-i' '-r' '-d')
for i in ${options[*]}; do
	echo -e "Checking success...\n"

	echo "./bin/asbt.sh $i ~/builds/asbt/asbt"
	./bin/asbt.sh $i ~/builds/asbt/asbt; check_pass; echo
done

# State changing operations
options=('-G' '-B' '-U')
for i in ${options[*]}; do
	echo -e "Checking success...\n"

	echo "./bin/asbt.sh $i asbt"
	./bin/asbt.sh $i asbt; check_pass; echo
done
