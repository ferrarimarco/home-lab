#!/bin/bash

set -e
set -o pipefail

clone_git_repository_if_not_cloned_already() {
    destination_dir="$1"
    git_repository_url="$2"

    if [ -z "$destination_dir" ]; then
        echo "ERROR while cloning the $git_repository_url git repository: The destination_dir variable is not set, or set to an empty string"
        exit 1
    fi

    if [ -d "$destination_dir" ]; then
        echo "$destination_dir already exists. Pulling the latest changes..."

        echo "Updating $git_repository_url in $destination_dir"
        git -C "$destination_dir" pull --ff-only
    else
        mkdir -p "$destination_dir"
        echo "Cloning $git_repository_url in $destination_dir"
        git clone --recursive "$git_repository_url" "$destination_dir"
    fi
    unset destination_dir
    unset git_repository_url
}

ESP_IDF_PATH="$(pwd)/esp-idf"
echo "Setting up ESP-IDF in $ESP_IDF_PATH..."

clone_git_repository_if_not_cloned_already "$ESP_IDF_PATH" "https://github.com/espressif/esp-idf.git"

echo "Running the ESP-IDF installation script..."
"$ESP_IDF_PATH"/install.sh
