#!/bin/bash
# to setup environment for testing

INITIAL_LOC="$(pwd)"

# setup slackbuilds repo
cd $HOME
mkdir -p git
cd git
git clone --depth=1 git://git.slackbuilds.org/slackbuilds.git
cd "${INITIAL_LOC}"

# setup config
mkdir -p $HOME/.config
cp aadityabagga/asbt/conf/asbt.conf $HOME/.config/asbt.conf

exit $?
