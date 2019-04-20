#!/bin/sh

set -e

echo "Updating scripts and tools..."
cd /opt/scripts/
git pull

echo "Updating Kernel..."
/opt/scripts/tools/update_kernel.sh

echo "Updating bootloader..."
/opt/scripts/tools/developers/update_bootloader.sh

uENV_path="/boot/uEnv.txt"
if [ -e "$uENV_path" ]
then
  echo "Enabling eMMC flashing..."
  sed -i '/init-eMMC-flasher-v3.sh/s/^#*//g' "$uENV_path"
else
  echo "$uENV_path does not exist"
fi
