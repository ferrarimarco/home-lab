#!/bin/busybox sh

# Force Defunct DNSMasq Service to Restart
# dnsmasq-script[31959]: _wlcsm_create_nl_socket:268: pid:2185 binding netlink socket error!!!
# https://www.snbforums.com/threads/wlcsm_create_nl_socket-binding-netlink-socket-error.87710

log() {
  # shellcheck disable=SC3036
  echo -e $$ "$@" | logger -st "($(basename "$0"))"
}

if ping -c 1 8.8.8.8 && ! nslookup dns.google 10.0.0.1; then
  /sbin/service restart_dnsmasq
  log "Restarting dnsmasq"
else
  log "Name resolution using the local dnsmasq instance works."
fi
