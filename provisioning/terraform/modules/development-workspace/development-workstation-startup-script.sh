#!/usr/bin/env sh

set -e

clone_git_repository_if_not_cloned_already() {
  destination_dir="$1"
  git_repository_url="$2"

  if [ -z "$destination_dir" ]; then
    echo "ERROR while cloning the $git_repository_url git repository: The destination_dir variable is not set, or set to an empty string"
    exit 1
  fi

  if [ -d "$destination_dir/.git" ]; then
    echo "$destination_dir already exists and is a Git repository. Pulling the latest changes..."

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

# shellcheck disable=SC2154 # The value comes from Terraform.
DEVELOPMENT_WORKSTATION_USERNAME="${development_workstation_username}"
echo "Development workstations username: $DEVELOPMENT_WORKSTATION_USERNAME"

apt-get update
apt-get -y install \
  git

DEVELOPMENT_WORKSTATION_USER_HOME_DIRECTORY_PATH=$( getent passwd "$DEVELOPMENT_WORKSTATION_USERNAME" | cut -d: -f6 )
echo "Development workstation user home directory path: $DEVELOPMENT_WORKSTATION_USER_HOME_DIRECTORY_PATH"

WORKSPACES_DIRECTORY_PATH="$DEVELOPMENT_WORKSTATION_USER_HOME_DIRECTORY_PATH/workspaces"
echo "Creating the workspaces directory in $WORKSPACES_DIRECTORY_PATH"

DOTFILES_DIRECTORY_PATH="$WORKSPACES_DIRECTORY_PATH"/dotfiles
# shellcheck disable=SC2154 # The value comes from Terraform.
clone_git_repository_if_not_cloned_already "$DOTFILES_DIRECTORY_PATH" "${dotfiles_repository_url}"

echo "Changing ownership of $DEVELOPMENT_WORKSTATION_USER_HOME_DIRECTORY_PATH and its contents..."
chown "$DEVELOPMENT_WORKSTATION_USERNAME":"$DEVELOPMENT_WORKSTATION_USERNAME" "$DEVELOPMENT_WORKSTATION_USER_HOME_DIRECTORY_PATH"
chown -R "$DEVELOPMENT_WORKSTATION_USERNAME":"$DEVELOPMENT_WORKSTATION_USERNAME" "$DEVELOPMENT_WORKSTATION_USER_HOME_DIRECTORY_PATH/"*

echo "Contents of $WORKSPACES_DIRECTORY_PATH: $(ls -alh "$WORKSPACES_DIRECTORY_PATH")"

echo "Initializing dotfiles..."
cd "$DOTFILES_DIRECTORY_PATH" || exit 1
sudo -H -u "$DEVELOPMENT_WORKSTATION_USERNAME" sh -c 'bin/setup-dotfiles.sh debian && make'
