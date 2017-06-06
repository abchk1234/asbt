#!/bin/bash
# to setup environment for testing

# setup slackbuilds repo
cd $HOME
mkdir -p git
cd git
git clone --depth=1 git://git.slackbuilds.org/slackbuilds.git
cd ..

# setup config
mkdir -p $HOME/.config
cp conf/asbt.conf $HOME/.config/asbt.conf

exit $?
