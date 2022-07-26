#!/bin/bash 
set -xe

mkdir -p bin
odin build src/treewalker/ -out:bin/olox-treewalker
