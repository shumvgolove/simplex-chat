#!/bin/bash

set -e

trap "rm apps/multiplatform/local.properties 2> /dev/null || true; rm local.properties 2> /dev/null || true; rm /tmp/simplex.keychain" EXIT
scripts/desktop/build-lib-mac.sh
cd apps/multiplatform
./gradlew packageDmg
