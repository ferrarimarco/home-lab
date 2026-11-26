#!/usr/bin/env bash

# Puts a removal in the upgrade plan of the test instance, in the shape of a
# library package that a rename replaces: the installed hl-test-keep 1.0
# depends on hl-test-victim, and its version 2.0, in a local repository,
# depends on hl-test-new, which conflicts with hl-test-victim.

set -o errexit
set -o nounset
set -o pipefail

REPOSITORY_DIRECTORY="/opt/update-os-packages-test/repository"
# The names APT gives the lists of a repository at that path
REPOSITORY_LISTS_PREFIX="/var/lib/apt/lists/_opt_update-os-packages-test_repository_"
BUILD_DIRECTORY="$(mktemp -d)"
trap 'rm -rf -- "${BUILD_DIRECTORY}"' EXIT

# build_package <name> <version> [<control field line>...]
build_package() {
  package_directory="${BUILD_DIRECTORY}/${1}-${2}"
  mkdir -p "${package_directory}/DEBIAN"
  {
    echo "Package: ${1}"
    echo "Version: ${2}"
    echo "Architecture: all"
    echo "Maintainer: Home lab tests <root@localhost>"
    echo "Description: Test package of the OS packages playbook"
    if [ "${#}" -gt 2 ]; then
      printf '%s\n' "${@:3}"
    fi
  } >"${package_directory}/DEBIAN/control"
  dpkg-deb --build "${package_directory}" "${REPOSITORY_DIRECTORY}/${1}_${2}_all.deb" >/dev/null
}

# What a previous run of the test left: the installed packages, and the lists
# of the repository, without which only a refresh shows the upgrade
dpkg --purge hl-test-keep hl-test-new hl-test-victim
rm -f -- "${REPOSITORY_LISTS_PREFIX}"*

mkdir -p "${REPOSITORY_DIRECTORY}"

build_package hl-test-victim 1.0
build_package hl-test-keep 1.0 "Depends: hl-test-victim"
dpkg --install \
  "${REPOSITORY_DIRECTORY}/hl-test-victim_1.0_all.deb" \
  "${REPOSITORY_DIRECTORY}/hl-test-keep_1.0_all.deb"
apt-mark auto hl-test-victim

build_package hl-test-new 1.0 "Conflicts: hl-test-victim" "Replaces: hl-test-victim"
build_package hl-test-keep 2.0 "Depends: hl-test-new"

cd "${REPOSITORY_DIRECTORY}"
dpkg-scanpackages --multiversion . >Packages

echo "deb [trusted=yes] file:${REPOSITORY_DIRECTORY} ./" >/etc/apt/sources.list.d/update-os-packages-test.list
