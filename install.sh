#! /bin/bash

set -e

git submodule update --init --recursive

sudo apt-get update

topics=(zsh tmux vim docker node)

for topic in "${topics[@]}"
do
	./$topic/install.sh
done
