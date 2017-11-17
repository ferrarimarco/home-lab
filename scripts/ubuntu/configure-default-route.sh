#!/bin/sh

set -e

if ! TEMP="$(getopt -o vdm: --long ip-v4-gateway-ip-address: -n 'configure-volatile-default-route' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '2p')"
ip_v4_gateway_ip_address=

while true; do
  case "$1" in
    -g | --ip-v4-gateway-ip-address ) ip_v4_gateway_ip_address="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

up_event_script_path="/etc/NetworkManager/dispatcher.d/100-default-route.sh"

if [ -e "$up_event_script_path" ]; then
  echo "$up_event_script_path already exists"
else
  echo "Writing $up_event_script_path"
  grep -q -F "$interface" "$up_event_script_path" >/dev/null 2>&1 \
  || printf "\\n\
INTERFACE=\$1\\n\
EVENT=\$2\\n\
default_gateway=\"%s\"
if [ \"\$INTERFACE\" = \"%s\" ]; then\\n\
  case \"\$EVENT\" in\\n\
    up)\\n\
      logger -s \"NetworkManager Script up triggered\"\\n\
      echo \"Removing default routes from \$INTERFACE interface\"
      while default_route=\"\$(ip route | grep \"default\")\"; do
        echo \"Removing \$default_route\"
        ip route del default
      done
      echo \"Configuring the default route for \$INTERFACE interface via \$default_gateway gateway\"
      ip route add \"\$default_gateway\" dev \"\$INTERFACE\"
      ip route add default via \"\$default_gateway\" dev \"\$INTERFACE\"
      ;;\\n\
    *)\\n\
      ;;\\n\
  esac\\n\
fi\\n" \
  "$ip_v4_gateway_ip_address" \
  "$interface" >> "$up_event_script_path"
  printf "$up_event_script_path contents:\\n\
  %s\\n\\n" "$(cat "$up_event_script_path")"
  chmod a+x "$up_event_script_path"
  chmod u+rw "$up_event_script_path"
fi
