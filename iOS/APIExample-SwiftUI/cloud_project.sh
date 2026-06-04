#!/usr/bin/env bash

PROJECT_PATH=$PWD

if [ "$WORKSPACE" = "" ]; then
	WORKSPACE=$PWD
fi
cd ${PROJECT_PATH} && pod install || exit 1
