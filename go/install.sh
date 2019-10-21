#! /bin/bash

echo "RUNNING curl --output /tmp/go.tar.gz https://dl.google.com/go/go1.13.3.linux-amd64.tar.gz"
curl --output /tmp/go.tar.gz https://dl.google.com/go/go1.13.3.linux-amd64.tar.gz

echo "RUNNING sudo tar -C /usr/local -xzf /tmp/go.tar.gz"
sudo tar -C /usr/local -xzf /tmp/go.tar.gz

