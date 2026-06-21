#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=/dev/null
. "./scripts/common.sh"

# --- Input Validation ---
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <hostname> <expected_mac>"
  echo "Example: $0 hl02 bc:24:11:d4:f6:65"
  exit 1
fi

TARGET_HOST="${1}"
# Normalize the expected MAC to lowercase to prevent string comparison issues
EXPECTED_MAC="${2,,}"

CONNECT_HOST="${TARGET_HOST}"

echo "=================================================="
echo "🚀 Bootstrapping Host: ${TARGET_HOST}"
echo "=================================================="

echo "Checking network routing path..."

# 1. Check if the host is already available under its production name
if ssh root@"${TARGET_HOST}" exit; then
  echo "Detected ${TARGET_HOST} is already online."

# 2. If production name fails, fall back to checking the default installer hostname
elif ssh root@nixos exit; then
  CONNECT_HOST="nixos"
  echo "${TARGET_HOST} host offline, but detected a NixOS host to provision (${CONNECT_HOST})!"

# 3. If both fail, enter a polling loop waiting for either one to show up
else
  echo "Neither '${TARGET_HOST}' nor 'nixos' are responding yet. Polling network..."
  MAX_ATTEMPTS=30
  ATTEMPT=0
  FOUND=false

  while [ "${ATTEMPT}" -lt "${MAX_ATTEMPTS}" ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "Searching for target installer environment (Attempt ${ATTEMPT}/${MAX_ATTEMPTS})..."

    if ssh root@"${TARGET_HOST}" exit 2>/dev/null; then
      CONNECT_HOST="${TARGET_HOST}"
      FOUND=true
      break
    elif ssh root@nixos exit 2>/dev/null; then
      CONNECT_HOST="nixos"
      FOUND=true
      break
    fi
    sleep 3
  done

  if [ "$FOUND" = false ]; then
    echo "❌ Error: Timed out waiting for a host to configure."
    exit 1
  fi
fi

# ==============================================================================
# ARP Validation: we found a host to configure. Now, verify that the MAC address
# of its default network interface is the one we expect
# ==============================================================================
echo "Performing hardware MAC address verification..."

# Query the target machine directly over SSH for all active link/ether MAC addresses
# This works perfectly even from inside sandboxed environments like ChromeOS Crostini
if ! DETECTED_MACS=$(ssh root@"${CONNECT_HOST}" "ip link show | awk '/link\/ether/ {print \$2}'" 2>/dev/null | tr '[:upper:]' '[:lower:]'); then
  echo "❌ Hardware Validation Error: Failed to execute remote identity check over SSH."
  exit 1
fi

if [ -z "${DETECTED_MACS}" ]; then
  echo "❌ Hardware Validation Error: Target returned an empty network interface list."
  exit 1
fi

echo "   Expected MAC: ${EXPECTED_MAC}"
echo "   Detected MAC(s) on target:"
# shellcheck disable=SC2001
echo "${DETECTED_MACS}" | sed 's/^/      - /'

if [[ ! "${DETECTED_MACS}" =~ ${EXPECTED_MAC} ]]; then
  break_line
  echo "   The network endpoint '${CONNECT_HOST}' responded to SSH, but none of its"
  echo "   network interfaces match the expected MAC address [${EXPECTED_MAC}]."
  echo ""
  echo "Detected MAC addresses on ${CONNECT_HOST}:"
  echo "${DETECTED_MACS}"
  echo ""
  echo "   Aborting execution immediately to prevent accidental data overwrites!"
  break_line
  exit 1
fi

echo "MAC address verified successfully."

NIXOS_ANYWHERE_SSH_HOST="root@${CONNECT_HOST}"
FLAKE_URI="${NIX_CONFIG_DIR_PATH}/#${TARGET_HOST}"

echo "Targeting network endpoint: ${NIXOS_ANYWHERE_SSH_HOST}"
echo "Initiating nixos-anywhere deployment of: ${FLAKE_URI}"

nixos-anywhere \
  --flake "${FLAKE_URI}" \
  "${NIXOS_ANYWHERE_SSH_HOST}"

break_line
echo "Bootstrapping complete! ${TARGET_HOST} is rebooting."
break_line

# Remove the known host key for the nixos host because it will re-generated
# when starting the bootstrapping process for another host
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "nixos"

# Remove the known host key for the host to provision in case the script failed
# provisioning on a previous round, and we ran the script again
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${TARGET_HOST}"
