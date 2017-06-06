#!/bin/bash
# to setup slackbuilds git repo

mkdir -p git
cd git
git clone --depth=1 git://git.slackbuilds.org/slackbuilds.git
cd ..

exit $?
