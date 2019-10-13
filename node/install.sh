#! /bin/bash

cd $DOTFILES/node/src/nvm
git checkout v0.35.0

. $DOTFILES/node/src/nvm/nvm.sh

echo RUNNING nvm install --lts
nvm install --lts

echo RUNNING nvm use --lts
nvm use --lts

