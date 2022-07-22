#!/bin/bash 
set -xe

mkdir -p bin
odin build src/ -out:bin/olox 
