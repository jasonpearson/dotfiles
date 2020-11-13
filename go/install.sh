#!/bin/bash

if ! command -v brew &> /dev/null
then
  echo "RUNNING go install script"
  curl -L https://golang.org/dl/go1.15.4.darwin-amd64.tar.gz --output /tmp/go.tar.gz
  tar -C /usr/local -xzf /tmp/go.tar.gz
else
  echo "SKIPPING go (already installed)"
fi
