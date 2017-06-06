#!/bin/bash
# to setup environment for testing

INITIAL_LOC="$(pwd)"

# setup slackbuilds repo
cd $HOME
git clone --depth=1 git://git.slackbuilds.org/slackbuilds.git
cd "${INITIAL_LOC}"

# setup config
mkdir -p $HOME/.config
cp conf/asbt.conf $HOME/.config/asbt.conf

exit $?
