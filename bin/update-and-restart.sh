#!/bin/zsh

cd /web/stormy
git clean -fdq
git checkout .
git pull
GIT_SSL_NO_VERIFY=true bundle install
rake minify
./bin/restart.sh
