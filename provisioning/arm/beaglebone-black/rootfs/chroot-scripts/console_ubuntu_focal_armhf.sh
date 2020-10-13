#!/bin/sh

set -e

export LC_ALL=C

#contains: rfs_username, release_date
if [ -f /etc/rcn-ee.conf ]; then
  # shellcheck disable=SC1091
  . /etc/rcn-ee.conf
fi

if [ -f /etc/oib.project ]; then
  # shellcheck disable=SC1091
  . /etc/oib.project
fi

export HOME=/home/${rfs_username?}
export USER=${rfs_username}
export USERNAME=${rfs_username}

echo "env: [$(env | sort)]"

is_this_qemu() {
  unset warn_qemu_will_fail
  if [ -f /usr/bin/qemu-arm-static ]; then
    warn_qemu_will_fail=1
  fi
}

qemu_warning() {
  if [ "${warn_qemu_will_fail}" ]; then
    echo "Log: (chroot) Warning, qemu can fail here... (run on real armv7l hardware for production images)"
    echo "Log: (chroot): [${qemu_command}]"
  fi
}

git_clone() {
  mkdir -p "${git_target_dir}" || true
  qemu_command="git clone ${git_repo} ${git_target_dir} --depth 1 || true"
  qemu_warning
  git clone "${git_repo}" "${git_target_dir}" --depth 1 || true
  chown -R 1000:1000 "${git_target_dir}"
  sync
  echo "${git_target_dir} : ${git_repo}" >>/opt/source/list.txt
}

git_clone_branch() {
  mkdir -p "${git_target_dir}" || true
  qemu_command="git clone -b ${git_branch} ${git_repo} ${git_target_dir} --depth 1 || true"
  qemu_warning
  git clone -b "${git_branch}" "${git_repo}" "${git_target_dir}" --depth 1 || true
  chown -R 1000:1000 "${git_target_dir}"
  sync
  echo "${git_target_dir} : ${git_repo}" >>/opt/source/list.txt
}

git_clone_full() {
  mkdir -p "${git_target_dir}" || true
  qemu_command="git clone ${git_repo} ${git_target_dir} || true"
  qemu_warning
  git clone "${git_repo}" "${git_target_dir}" || true
  chown -R 1000:1000 "${git_target_dir}"
  sync
  echo "${git_target_dir} : ${git_repo}" >>/opt/source/list.txt
}

setup_system() {
  {
    echo ""
    echo "#USB Gadget Serial Port"
    echo "ttyGS0"
  } >>/etc/securetty
}

install_git_repos() {
  if [ -f /usr/bin/make ]; then
    echo "Installing pip packages"
    git_repo="https://github.com/adafruit/adafruit-beaglebone-io-python.git"
    git_target_dir="/opt/source/adafruit-beaglebone-io-python"
    git_clone
    if [ -f ${git_target_dir}/.git/config ]; then
      cd ${git_target_dir}/
      sed -i -e 's:4.1.0:3.4.0:g' setup.py || true
      sed -i -e "s/strict-aliasing/strict-aliasing', '-Wno-cast-function-type', '-Wno-format-truncation', '-Wno-sizeof-pointer-memaccess', '-Wno-stringop-overflow/g" setup.py || true
      if [ -f /usr/bin/python3 ]; then
        python3 setup.py install || true
      fi
      git reset HEAD --hard || true
    fi
  fi

  git_repo="https://github.com/strahlex/BBIOConfig.git"
  git_target_dir="/opt/source/BBIOConfig"
  git_clone

  git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
  git_target_dir="/opt/source/dtb-4.14-ti"
  git_branch="v4.14.x-ti"
  git_clone_branch

  git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
  git_target_dir="/opt/source/dtb-4.19-ti"
  git_branch="v4.19.x-ti-overlays"
  git_clone_branch

  git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
  git_target_dir="/opt/source/dtb-5.4-ti"
  git_branch="v5.4.x-ti-overlays"
  git_clone_branch

  git_repo="https://github.com/beagleboard/BeagleBoard-DeviceTrees"
  git_target_dir="/opt/source/dtb-5.4"
  git_branch="v5.4.x"
  git_clone_branch

  git_repo="https://github.com/beagleboard/bb.org-overlays"
  git_target_dir="/opt/source/bb.org-overlays"
  git_clone

  if [ -f /usr/lib/librobotcontrol.so ]; then
    git_repo="https://github.com/StrawsonDesign/librobotcontrol"
    git_target_dir="/opt/source/librobotcontrol"
    git_clone

    git_repo="https://github.com/mcdeoliveira/rcpy"
    git_target_dir="/opt/source/rcpy"
    git_clone
    if [ -f ${git_target_dir}/.git/config ]; then
      cd ${git_target_dir}/
      if [ -f /usr/bin/python3 ]; then
        /usr/bin/python3 setup.py install
      fi
    fi

    git_repo="https://github.com/mcdeoliveira/pyctrl"
    git_target_dir="/opt/source/pyctrl"
    git_clone
    if [ -f ${git_target_dir}/.git/config ]; then
      cd ${git_target_dir}/
      if [ -f /usr/bin/python3 ]; then
        /usr/bin/python3 setup.py install
      fi
    fi
  fi

  git_repo="https://github.com/mvduin/py-uio"
  git_target_dir="/opt/source/py-uio"
  git_clone
}

is_this_qemu

setup_system

if [ -f /usr/bin/git ]; then
  git config --global user.email "${rfs_username}@example.com"
  git config --global user.name "${rfs_username}"
  install_git_repos
  git config --global --unset-all user.email
  git config --global --unset-all user.name
  chown "${rfs_username}":"${rfs_username}" /home/"${rfs_username}"/.gitconfig
fi

echo "Log: (chroot): Enabling connman service..."
systemctl enable connman

echo "Log: (chroot): Creating connman configuration directory..."
mkdir -p /etc/connman || true
chown root:root /etc/connman
chmod 0755 /etc/connman

echo "Log: (chroot): Creating connman service configuration directory..."
mkdir -p /var/lib/connman || true
chown root:root /var/lib/connman
chmod 0755 /var/lib/connman

echo "Log: (chroot): Creating network interfaces configuration directory..."
mkdir -p /etc/network/interfaces.d || true
chown root:root /etc/network/interfaces.d
chmod 0755 /etc/network/interfaces.d

DPKG_ARCHITECTURE="$(dpkg --print-architecture)"
echo "Log: (chroot): CPU architecture as reported by dpkg: ${DPKG_ARCHITECTURE}..."

DISTRO_RELEASE="$(lsb_release -cs)"
echo "Log: (chroot): Distribution release as reported by lsb_release: ${DISTRO_RELEASE}"

# Workaround for https://github.com/docker/for-linux/issues/1035
# There's currently no armhf package available for Ubuntu focal
if [ "${DISTRO_RELEASE}" = "focal" ] && [ "${DPKG_ARCHITECTURE}" = "armhf" ]; then
  DISTRO_RELEASE_DOCKER_WORKAROUND="bionic"
  echo "Log: (chroot): There's currently no armhf package available for Ubuntu ${DISTRO_RELEASE}. Setting distribution release to ${DISTRO_RELEASE_DOCKER_WORKAROUND}..."
  DISTRO_RELEASE="${DISTRO_RELEASE_DOCKER_WORKAROUND}"
fi

echo "Log: (chroot): Installing Docker..."

APT_REPOSITORY_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
echo "Log: (chroot): Adding APT repository key from ${APT_REPOSITORY_KEY_URL}..."
curl -fsSL "${APT_REPOSITORY_KEY_URL}" | apt-key add -

APT_REPOSITORY_ID="deb [arch=${DPKG_ARCHITECTURE}] https://download.docker.com/linux/ubuntu ${DISTRO_RELEASE} stable"
echo "Log: (chroot): Adding APT repository: ${APT_REPOSITORY_ID}..."
add-apt-repository "${APT_REPOSITORY_ID}"

echo "Installing Docker packages..."
apt-get update
apt-get -y install \
  containerd.io \
  docker-ce \
  docker-ce-cli

echo "Removing unneeded APT packages..."
apt-get -y purge \
  '^apache2.*' \
  bb-wl18xx-firmware \
  bluetooth \
  bluez \
  '^dnsmasq.*' \
  '^git.*' \
  nodejs \
  udhcpd \
  '^vim.*'
