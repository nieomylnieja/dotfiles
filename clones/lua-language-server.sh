#!/bin/bash

set -e

cd lua-language-server &&
  git pull &&
  git submodule update --depth 1 --init --recursive &&
  cd cd 3rd\luamake &&
  ./compile/install.sh &&
  cd ../.. &&
  ./3rd/luamake/luamake rebuild
