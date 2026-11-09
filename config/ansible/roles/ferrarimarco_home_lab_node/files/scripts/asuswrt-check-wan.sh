#!/bin/sh
# Check the WAN from an AsusWRT router and restart it when no target answers.
# The systemd unit on the monitoring host copies this script over SSH and runs
# it every few minutes: exit 0 when a target answers, 2 after a WAN restart.
# Targets come from the arguments, or from the WAN gateway and DNS servers the
# router knows plus two public resolvers; private and unspecified addresses
# (the ONT, an unset gateway) are skipped.

# No pipefail: BusyBox ash has it only in some builds, and the one pipeline
# here is the log call, which must not end the run.
set -o errexit
set -o nounset

Say() {
  echo $$ "$@" | logger -st "($(basename "$0"))" || true
}

Is_Private_Or_Unspecified() {
  case "$1" in
  10.* | 192.168.* | 127.* | 169.254.* | 0.0.0.0 | "") return 0 ;;
  172.1[6-9].* | 172.2[0-9].* | 172.3[01].*) return 0 ;;
  *) return 1 ;;
  esac
}

if [ "$#" -gt 0 ]; then
  TARGETS="$*"
else
  TARGETS="$(nvram get wan0_gateway) $(nvram get wan0_dns) 9.9.9.9 1.1.1.1"
fi

for target in $TARGETS; do
  if Is_Private_Or_Unspecified "$target"; then
    continue
  fi
  if ping -q -c 1 -W 2 -w 3 "$target" > /dev/null 2>&1; then
    Say "WAN OK: ${target} answers"
    exit 0
  fi
done

Say "WAN check failed: no target answers (${TARGETS})"
if pidof udhcpc > /dev/null; then
  Say "Renewing the WAN DHCP lease"
  killall -USR1 udhcpc || Say "Could not signal udhcpc"
fi
Say "Restarting the WAN"
if ! service restart_wan; then
  Say "The WAN restart command failed"
  exit 1
fi
exit 2
