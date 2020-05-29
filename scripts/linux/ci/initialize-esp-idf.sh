#!/bin/bash

set -e
set -o pipefail

INITIAL_PWD="$(pwd)"

git clone --recursive https://github.com/espressif/esp-idf.git

cd esp-idf || exit 1
./install.sh

# shellcheck disable=SC1091
. ./export.sh

echo "Changing directory back to $INITIAL_PWD"
cd "$INITIAL_PWD"
