#!/bin/bash

set -e

scripts/desktop/build-lib-mac.sh
cd apps/multiplatform
./gradlew packageDmg
