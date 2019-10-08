#! /bin/bash

set -e
. ./config.sh

export PKG_MGR_BIN=brew
export PKG_MGR_INSTALL_COMMAND="$PKG_MGR_BIN install"
export PKG_MGR_UPDATE_COMMAND="$PKG_MGR_BIN update"
export PKG_MGR_SUDO=false

if [ $PKG_MGR_SUDO = true ]
then
  PKG_MGR_UPDATE_COMMAND="sudo $PKG_MGR_UPDATE_COMMAND"
  PKG_MGR_INSTALL_COMMAND="suo $PKG_MGR_INSTALL_COMMAND"
fi

function pkg_mgr_install() {
	if [ $(brew list | grep "$1" | wc -l)  -lt 1 ]; then
		echo "RUNNING $PKG_MGR_INSTALL_COMMAND $1"
		$PKG_MGR_INSTALL_COMMAND $1
		echo "DONE. INSTALLED $1"
	else
		echo "ALREADY INSTALLED: $1"
	fi
}

export -f pkg_mgr_install

echo "RUNNING git submodule update --init --recursive"
git submodule update --init --recursive

echo "RUNNING $PKG_MGR_UPDATE_COMMAND"
$PKG_MGR_UPDATE_COMMAND

if [ $# -gt 0 ]; then
	for topic in $*; do
		echo "RUNNING ./$topic/install.sh"
		./$topic/install.sh
	done
else
	for topic in "${TOPICS[@]}"
	do
		echo "RUNNING ./$topic/install.sh"
		./$topic/install.sh
	done
	
	echo "DONE. RUN source $HOME/.zshrc OR OPEN A NEW SHELL."
fi

