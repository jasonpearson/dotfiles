#! /bin/bash

if test "$(uname)" = "Darwin"
then
	echo "RUNNING curl --output /tmp/go.tar.gz https://dl.google.com/go/go1.13.3.darwin-amd64.tar.gz"
	curl --output /tmp/go.tar.gz https://dl.google.com/go/go1.13.3.darwin-amd64.tar.gz
elif test "$(expr substr $(uname -s) 1 5)" = "Linux"
then
	echo "RUNNING curl --output /tmp/go.tar.gz https://dl.google.com/go/go1.13.3.linux-amd64.tar.gz"
	curl --output /tmp/go.tar.gz https://dl.google.com/go/go1.13.3.linux-amd64.tar.gz
fi

echo "RUNNING sudo tar -C /usr/local -xzf /tmp/go.tar.gz"
sudo tar -C /usr/local -xzf /tmp/go.tar.gz

