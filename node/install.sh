#! /bin/bash

pkg_mgr_install nvm
mkdir -p $HOME/.nvm
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"

echo RUNNING nvm install --lts
nvm install --lts

echo RUNNING nvm use --lts
nvm use --lts

