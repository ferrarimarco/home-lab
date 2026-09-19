# Home Lab Design Specifications

This directory contains design specifications for various components of the home
lab infrastructure. These specifications focus on architecture, security, and
testing rationale before code implementation.

## Specifications Directory Index

| Specification                                                               | Description                                                                                                                                              | Current Implementation Status |
| :-------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------- |
| [**Home Lab Bootstrapping**](./home-lab-bootstrapping.md)                   | Global VM installation infrastructure: Nix-native custom installer ISO, secure bootstrap key loading with Git-tracking guardrails, and `nixos-anywhere`. | **Fully Implemented**         |
| [**NixOS VMs on Proxmox**](./proxmox-vm.md)                                 | Reusable framework for NixOS VMs: the `proxmox-vm` role, host structure with Disko layouts, and the Terraform VM provisioning pattern.                   | **Fully Implemented**         |
| [**Declarative Integration Testing**](./declarative-integration-testing.md) | Design of the NixOS test generator framework (`make-test.nix`), dynamic test discovery, and parallel GHA matrix CI pipeline.                             | **Fully Implemented**         |
| [**NixOS LXC Containers on Proxmox**](./proxmox-lxc.md)                     | Reusable framework for NixOS LXC containers: the `proxmox-lxc` role, `system.build.tarball` templates, and the Terraform provisioning pattern.           | **Fully Implemented**         |
| [**NAS LXC Container**](./nas-lxc-container.md)                             | NixOS LXC containers on each Proxmox node exposing host ZFS datasets as SMB shares via bind mounts. Builds on the `proxmox-lxc` framework.               | **Fully Implemented**         |

## Specifications to write and TODOs

This section is the centralized list of future work and todo items for the whole
home lab: the Future Work section of each specification only points here. Items
are grouped by theme, and stay here until they are implemented and reflected in
the relevant specification, or explicitly discarded.

### Current focus

The items being actively worked toward, in priority order (data-loss and
reliability risks first, then security exposure, then automation):

- Run the SMART long self-test on the raspberrypi2 data disk and decide about a
  replacement, after verifying that its restic backups are current: standing
  data-loss risk ([Issues to solve](#issues-to-solve)).
- Migrate the containers from raspberrypi2 to hl01: shrinks that host's role and
  unblocks its re-image
  ([Bootstrapping and provisioning](#bootstrapping-and-provisioning)).
- Re-image raspberrypi2 with current Raspberry Pi OS, then bump the `requests`
  pin: the host runs Debian 11 past LTS end of life, and the old system Python
  pins a dependency with a known vulnerability. Depends on the container
  migration ([Issues to solve](#issues-to-solve)).
- Deploy Prometheus Alertmanager: unblocks every alerting gap, including backup
  staleness and unexpected reboots
  ([Monitoring and alerting](#monitoring-and-alerting)).

### Bootstrapping and provisioning

- Generate a Home Lab bootstrapping keypair.
- Fully automate Terraform runs. Reference:
  [Running Terraform in automation](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform).
- Fully automate provisioning and configuration of new hosts. Currently manual
  steps:
    - Copy ESPHome secrets.
    - Configure the Ansible Vault password file and the per-host vault files.
    - Configure SSH keys.
    - Configure unattended updates for all hosts:
      [Proxmox hosts](https://forum.proxmox.com/threads/is-unattended-upgrade-package-safe-to-use.139808/)
      ([auto updates](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#system_software_updates)),
      Debian hosts
      ([UnattendedUpgrades](https://wiki.debian.org/UnattendedUpgrades)), Nix
      hosts.
    - Migrate containers from raspberrypi2 to hl01: Zigbee2MQTT depends on the
      Zigbee adapter hardware; the media stack depends on data (copy the media,
      remove the runtime data from raspberrypi2, update the endpoints in the
      Ansible configuration); deploy Syncthing and the monitoring backend on
      hl01 instead of migrating them.
    - Run Ansible.
    - Run Terraform to set up the Proxmox hosts (networking; storage: pve1 done,
      pve2 pending).

### Issues to solve

- Workload issues to solve:
    - Frigate doesn't restart because the cam3 name is not yet available.
      Restart it manually from the Frigate UI.
    - Zigbee2MQTT doesn't restart. It restarted after a long time.
    - Home Assistant doesn't connect to Zigbee2MQTT and Telegram (DNS error):
      `/etc/resolv.conf` is empty. Need to wait for the host network to be
      ready?
    - Frigate: audio out of sync.
    - Frigate: recordings don't fully capture events. References:
      [frigate#3043](https://github.com/blakeblackshear/frigate/issues/3043),
      [frigate#2270](https://github.com/blakeblackshear/frigate/issues/2270).
    - Home Assistant sometimes leaves corrupted DBs behind on restart (clean up
      if it happens). Remediation: safely restart the container by
      [shutting Home Assistant down before updating](https://community.home-assistant.io/t/shut-down-home-assistant-cleanly-before-shutdown-docker/301438).
    - The Syncthing HTTP endpoint blackbox probe is configured but fails
      (authentication, HTTPS with self-signed certificate).
- raspberrypi2 stability follow-ups (freeze investigated on 2026-09-13: hard
  lockup between 13:39 and 13:42 local time with no kernel, undervoltage,
  thermal, or memory precursors in logs or Prometheus history):
    - Run a SMART long self-test on the WD30EZRX 3TB data disk (1 pending and 1
      offline-uncorrectable sector as of 2026-09-13, ~39200 power-on hours) and
      decide whether to plan a replacement. Verify the restic backups of that
      disk are current first.
    - Upgrade the operating system: Debian 11 (bullseye) is past LTS end of
      life, the April 2023 kernel is the most plausible lockup culprit, and the
      system Python 3.9 caps `requests` below 2.33, pinning the ONT exporter
      (2026-09-14) to a release with a known security vulnerability. Decision:
      re-image with current Raspberry Pi OS, the most supported path for the
      Raspberry Pi 4 hardware (its documentation strongly discourages in-place
      upgrades, recommending a re-image instead); a NixOS migration was
      deferred, to reconsider after the planned container migration to hl01
      shrinks this host's role. After the upgrade, bump the `requests` pin and
      the CI requirements test matrix (`test-python-requirements.yaml`).
    - Optionally prove the hardware watchdog recovery path end-to-end with a
      deliberate kernel crash (`echo c > /proc/sysrq-trigger`): the host should
      self-reboot within the 15 second timeout. Induced crash with the usual
      unclean-shutdown cost, so schedule it consciously.
    - Prune the now-unreferenced `vault_raspberrypi2_monitoring_nut_*` variables
      from the raspberrypi2 Ansible vault (NUT moved to pve1; the host_vars
      references were removed on 2026-09-14).
- ONT admin interface health: the ZTE ONT's admin interface sometimes hangs
  until the ONT is rebooted (it hung from 2026-03-28 until at least 2026-09-15,
  starving the ONT exporter; a manual reboot is still pending). The ONT is a
  closed, ISP-managed device, so root-causing is likely not possible; explore
  detecting the hang from monitoring (the exporter now fails visibly when it
  happens) and eventually automating the reboot (e.g. a smart plug power cycle),
  and assess whether that automation is worth the added failure modes.
  Actionability unclear at this point.

### Reliability and resilience

- Single points of failure to mitigate:
    - Hardware: network gateway, Wi-Fi access point, network switches, network
      cables, power supply units, UPS, Zigbee antenna.
    - Software: DHCP server, DNS resolver, MQTT broker, Zigbee2MQTT. Also,
      without an internet connection the Ansible container can't be built unless
      the image is already stored on the host running Ansible.
    - Services: WAN.
- Minimize external dependencies:
    - NixOS ISO server host
    - Terraform provider registry
- Automated troubleshooting playbook: test the DNS server, test the DNS
  resolver.

### Security

- Add hashes to container images.
- Centralized user management: configure Linux system users, configure network
  shares permissions.
- Check security vulnerabilities:
  [code scanning](https://github.com/ferrarimarco/home-lab/security/code-scanning),
  [routersploit](https://github.com/threat9/routersploit).
- Ansible:
  [dev-sec hardening collection](https://github.com/dev-sec/ansible-collection-hardening/).
- Secure Debian:
  [Securing Debian manual](https://www.debian.org/doc/manuals/securing-debian-manual/index.en.html).
- Secrets: restrict access to the Frigate configuration file to root only.
- Mosquitto: configure encryption, authentication, and mTLS.
- Docker: remove users from the Docker group?; Docker socket hardening
  ([Traefik Docker API access](https://doc.traefik.io/traefik/providers/docker/#docker-api-access),
  [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy));
  don't bind ports to every host interface.
- Block internet access to local-only devices.
- [Securing Home Assistant](https://www.home-assistant.io/docs/configuration/securing/).
- [Commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification).
- qBittorrent: enable HTTPS.
- Proxmox hardening:
  [against physical attacks](https://dustri.org/b/hardening-proxmox-against-physical-attacks.html),
  [Proxmox VE 9 hardening steps](https://www.virtualizationhowto.com/2025/08/top-security-hardening-steps-for-proxmox-ve-9/).
- Encrypt disks; unlock remotely:
  [LUKS unlock via Dropbear SSH](https://www.cyberciti.biz/security/how-to-unlock-luks-using-dropbear-ssh-keys-remotely-in-linux/).
- SSH: sshd AuthorizedKeysCommand; IdentitiesOnly.

### CI/CD, infrastructure-as-code, and GitOps

- Compose:
    - Move secrets to
      [Docker Compose secrets](https://docs.docker.com/compose/use-secrets/).
    - Change restart always to restart unless-stopped (useful for migrations).
      Remaining: mosquitto, home-assistant, zigbee2mqtt, monitoring-backend
      compose templates.
    - Move environment variables to env files.
- Terraform:
    - [Configure Cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone).
    - Configure
      [GitHub repositories](https://registry.terraform.io/providers/integrations/github/latest/docs).
    - [Ansible terraform module](https://docs.ansible.com/ansible/latest/collections/community/general/terraform_module.html#ansible-collections-community-general-terraform-module).
    - Setup CI for Terraform.
- Tests to implement:
    - Samba config file validation: `testparm -s`.
    - Evaluate `dnsmasq --test` for testing the dnsmasq configuration.
    - Validate the Unbound configuration: `unbound-checkconf unbound.conf`.
    - [Home Assistant config check](https://www.home-assistant.io/common-tasks/container/#configuration-check).
    - [Docker config validation](https://github.com/moby/moby/pull/42393).
    - SSH configuration validation: `"{{ sshd_path }} -T -f %s"`.
- Ansible:
    - Get the Proxmox VMs data from the inventory instead of using the
      proxmox_vms list.
    - Move the handlers to a dedicated role and reuse that role across all
      playbooks.
    - Refactor the molecule tests to use `group_vars` and `host_vars` instead of
      redefining variables in the molecule file
      ([reference](https://ansible.readthedocs.io/projects/molecule/configuration/#molecule.provisioner.ansible.Ansible)).
    - Set the hostname (`/etc/hostname`: simple hostname).
    - Delete the leftover cron-removal task (setup-cron.yaml) now that all jobs
      are systemd timers.
    - Use the `zigbee2mqtt_data_directory_path` variable in the zigbee2mqtt
      compose file.
    - Use the `home_assistant_configuration_config_directory_path` variable in
      the home-assistant compose file.
    - Validation: check that `start_xxxx` and `stop_xxxx` don't contradict each
      other.
    - Cleanup users after switching from appending groups to creating dedicated
      users: set the "state" of users dynamically.
    - Tailscale: don't run tailscale up if the flags didn't change between runs.
- Move monitoring stack from the home_lab_node role to the home_lab_monitoring
  role.
- NixOS VMs ([NixOS VMs on Proxmox](./proxmox-vm.md)): factor the per-host
  Terraform VM resources into a shared module (or `for_each` over a host map)
  once a second NixOS VM exists, so the reference pattern is enforced by code
  rather than by convention.
- Nix tests
    - Modularize the integration-test generator: move the per-service test
      fragments (SSH, QEMU guest agent, comin, Samba, ...) out of
      `config/nix/tests/make-test.nix` — for example placing each fragment next
      to its role — so the generator stays maintainable as service coverage
      grows. Do it for all services at once to avoid a split paradigm.
    - Check that configured users are present
    - Check that configured users have their SSH keys authorized (reuse the
      existing bootstrap key check because it already does most of the stuff we
      need for this check).

### Host configuration

- Proxmox cluster (pve1, pve2): enable trim on the QEMU agent; configure
  certificates
  ([certificate management](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_certificate_management),
  [Let's Encrypt](https://www.derekseaman.com/2023/04/proxmox-lets-encrypt-ssl-the-easy-button.html)).
- Asus RT-AX86U: copy the node public key to the Asus to allow SSH access,
  configure the Asus host key as trusted in the node that connects via SSH,
  deploy the Prometheus Node Exporter.
- Set UTC as the system timezone on the Ansible-managed Debian hosts with the
  [timezone module](https://docs.ansible.com/ansible/latest/collections/community/general/timezone_module.html#ansible-collections-community-general-timezone-module)
  (NixOS hosts and cloud-init VMs are UTC already; the node role only sets the
  container TZ variable, currently Europe/London).
- raspberrypi2:
    - Enable TRIM on the external SSD
      ([reference](https://www.jeffgeerling.com/blog/2020/enabling-trim-on-external-ssd-on-raspberry-pi)).
    - Verify that UAS is enabled: it seems enabled, but `lsusb -v -d 174c:1156`
      reports SCSI
      ([reference](https://superuser.com/questions/928741/how-can-i-check-whether-usb3-0-uasp-usb-attached-scsi-protocol-mode-is-enabled)).
    - Argon One M.2 case: set up logging for the fan controller
      ([firmware updater](https://github.com/Argon40Tech/Argon40case/blob/master/src/argonone-firmwareupdate.py),
      [I2C codes](https://github.com/Argon40Tech/Argon-ONE-i2c-Codes),
      [fan software alternative](https://forum.argon40.com/t/much-better-argon-one-fan-linux-software-alternative/891)).
- Stable serial adapter assignment:
    - Create a udev rule:
      `echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", SYMLINK+="zigbee_dongle"' | sudo tee /etc/udev/rules.d/99-zigbee.rules`
    - Change the mapping in Docker
    - Logs:

        ```text
        Error response from daemon: error gathering device information while adding custom device "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20220708144056-if00": no such file or directory
        pi@raspberrypi2:~ $ ls /dev/serial/by-id
        usb-1a86_USB_Single_Serial_54DD003512-if00
        ```

### Networking

- Configure static IP addresses for servers (raspberrypi2, hl01): when the
  router reboots, dnsmasq on the gateway doesn't know the hosts until they renew
  their DHCP leases, so their names don't resolve in the meantime.
- Tailscale:
    - Configure SSH.
    - Don't accept DNS to avoid depending on Tailscale being up?
    - Update the DNS resolver IP address.
    - Configure an auth key to automate the setup.
    - Subnet routes: don't advertise routes if there are already unapproved
      routes for the same node (needs
      [tailscale#5724](https://github.com/tailscale/tailscale/issues/5724)).
    - Uninstall Tailscale from raspberrypi and from raspberrypi3.
    - References:
      [invite any user](https://tailscale.com/blog/invite-any-user/),
      [exit nodes](https://tailscale.com/kb/1103/exit-nodes/),
      [TLS certs](https://tailscale.com/blog/tls-certs/),
      [Traefik certificate resolver](https://tailscale.com/blog/traefik-certificate-resolver/),
      [Docker image](https://hub.docker.com/r/tailscale/tailscale),
      [PiKVM](https://docs.pikvm.org/tailscale/),
      [Pi-hole](https://tailscale.com/kb/1114/pi-hole/),
      [NextDNS](https://tailscale.com/kb/1218/nextdns/),
      [Funnel](https://tailscale.com/blog/introducing-tailscale-funnel/),
      [Docker guide](https://tailscale.com/blog/docker-tailscale-guide),
      [Docker KB](https://tailscale.com/kb/1282/docker),
      [Traefik certificates](https://tailscale.com/kb/1234/traefik-certificates/),
      [Kubernetes operator](https://tailscale.com/kb/1236/kubernetes-operator),
      [cloud-init](https://tailscale.com/kb/1293/cloud-init),
      [GitOps ACLs](https://tailscale.com/kb/1204/gitops-acls/),
      [Terraform provider](https://tailscale.com/kb/1210/terraform-provider/),
      [Proxmox](https://tailscale.com/kb/1133/proxmox).
- ChkWAN script: move the ExecStop command from asuswrt-chkwan.service to the
  ChkWAN.sh script; delete the /tmp/ChkWAN.sh-running file.
- Network stack
  ([reference](https://www.virtualizationhowto.com/2025/08/how-to-totally-control-dns-in-your-home-lab/)):
    - DNS server: configure the lab DNS zone.
    - DNS over TLS: dnsmasq instance on the Asus (done, but check); Unbound.
    - DHCP server:
        - Deploy a managed DHCP server, or take control of the dnsmasq instance
          on the Asus.
        - Configure the DHCP address pool as documented.
        - Understand what the dhcp-script does.
        - Deprecate the DNS resolver on the Asus, or take control of its
          configuration?
        - Deprecate the DHCP server on the Asus, or take control of its
          configuration?
        - If staying on dnsmasq, consider using a repology source and Renovate
          to automatically update dependencies:
          [Repology](https://docs.renovatebot.com/modules/datasource/repology/).
        - Configure network boot: evaluate dnsmasq proxy DHCP for PXE,
          [netboot.xyz](https://github.com/netbootxyz/netboot.xyz),
          [PXE booting into netboot.xyz](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Enable-PXE-booting-into-netboot.xyz).
        - Configure dnsmasq on the Asus router to use the recursive DNS
          resolver: find a way to edit the dnsmasq configuration in the stock
          Asuswrt firmware.
        - Forward queries to the authoritative DNS server for the main zone. If
          dnsmasq: `server=/{{ root_fqdn }}/{{ root_dns_servers[0].ipv4_address`
        - Remove the manual address assignments for servers.
        - Remove the manual address assignment for cam-1 (no longer needed).
    - Unbound: configure DNSSEC validation (trust-anchor, auto-trust-anchor);
      harden-unverified-glue.
    - Block port 53 outbound on the router WAN interface, keeping port 53
      allowed within the LAN: the router acts as a local DNS cache that
      ultimately serves from DNS-over-TLS and DNS-over-HTTPS external resolvers.
    - Deploy an ad blocking server.
    - Configure block lists for Unbound:
      [StevenBlack/hosts](https://github.com/StevenBlack/hosts).
    - Keepalived to make the DNS server, the DNS resolver, and the DHCP server
      more reliable
      ([pihole-keepalived](https://github.com/matayto/pihole-keepalived)).
    - [Exposing Docker's internal DNS with CoreDNS](https://theorangeone.net/posts/expose-docker-internal-dns/).
    - Store SSH fingerprints as DNS records?
    - DNS rebinding protection: see the dnsmasq "rebind" options.
    - Update the DNS records in `group_vars/all/main.yaml` to point to the DNS
      server, and define the DNS names there: refactor the roles so endpoint
      FQDNs in the vars file are automatically configured; reverse proxy
      (Traefik).
- 4G/5G WAN fallback.
- Disable UPnP on the gateway.

### Monitoring and alerting

- To monitor:
    - EdgeTPU: custom exporter, or
      [edgetpu-exporter](https://github.com/adaptant-labs/edgetpu-exporter).
    - [Frigate metrics](https://docs.frigate.video/configuration/metrics/).
    - Syncthing (supports Prometheus).
    - CPU C states.
    - CPU vulnerabilities.
    - [Docker engine metrics](https://docs.docker.com/engine/daemon/prometheus/).
    - The ONT login endpoint (`https://192.168.1.1/login.html`).
    - [Tailscale client metrics](https://tailscale.com/blog/client-metrics).
    - Home Assistant metrics via the Prometheus integration.
    - How to configure Prometheus Blackbox monitoring for reverse lookups?
    - [Unbound](https://github.com/letsencrypt/unbound_exporter).
    - Flaresolverr.
    - HTTPS and TLS certificate validity: ferrarimarco.info, ferrari.how.
    - Gateway: dnsmasq DNS queries and DHCP leases
      ([dnsmasq_exporter](https://github.com/google/dnsmasq_exporter)), running
      processes, and host metrics via the Prometheus Node Exporter
      ([reference](https://www.snbforums.com/threads/successfully-got-node_exporter-on-rt-ax58u.64683/)).
- Verify the authority section of public resource records.
- Setup Loki.
- Uptime Kuma.
- WoL watchdog.
- Restic exporter: move the monitoring jobs to the monitoring compose file
  because they are not started when the restic compose file is updated, or set
  them to start on changes as the other compose files do?
- Grafana: set a datasource uid to reuse across dashboards; set the unit of
  measurement in the average DNS probe panel; automate updates of the
  provisioned dashboard JSONs (PRs with updates?).
- Check the [UptimeRobot](https://uptimerobot.com/) configuration.
- Monitoring alerting: no Prometheus alerts are configured. Deploy Prometheus
  Alertmanager
  ([reference](https://gist.github.com/satwell/97678b9b47c54e455aa02c2bd30937c4)).
  Known gaps: temperature alerts (pve1 `coretemp` above 85 degrees Celsius,
  Coral TPU above 90 degrees Celsius, identified during the August 2026 thermal
  incident), staleness of node exporter textfiles (alert on
  `node_textfile_mtime_seconds`), unexpected reboots (alert on
  `node_boot_time_seconds` changing, so hardware-watchdog recoveries are noticed
  rather than silently absorbed), backups (alert if no backup was taken for too
  many days, and if the backup check fails), and Prometheus health (exporters
  down, exporters sending stale data, unreachable scrape targets).
- Validate the reworked `sense-hat-exporter` unit (venv in a systemd state
  directory, metrics file deleted on start and exit, throttled restarts; changed
  2026-09-14) whenever a host with a Sense HAT returns to service; no such host
  is currently deployed.
- Replace the `rm` ExecStartPre workaround in systemd units that write node
  exporter textfiles (e.g. monitoring-apt) with the `truncate:` variant of
  `StandardOutput` once every host runs systemd >= 248.

### Smart home

- Frigate: configure the
  [live view to use the high resolution stream](https://docs.frigate.video/configuration/live#setting-stream-for-live-ui);
  use
  [environment variables](https://docs.frigate.video/configuration/#full-configuration-reference)
  to pass credentials; tune
  [notifications](https://github.com/blakeblackshear/frigate/discussions/559).
- Smart desk:
  [dimmable LCD display](https://community.home-assistant.io/t/dimmable-pcf8574-lcd-display-with-esphome/272308),
  magnetic contact to signal actuators movement, sensor to ensure that the
  actuators are extended to the same length, actuators that report extension,
  programmable plug for the actuators power source so it can be disabled when
  not needed.
- Sense HAT:
  [temperature correction](https://github.com/initialstate/wunderground-sensehat/wiki/Part-3.-Sense-HAT-Temperature-Correction).
- Weather station:
  [Adafruit Wi-Fi weather station](https://learn.adafruit.com/wifi-weather-station-with-tft-display),
  [esp32-weather-epd](https://github.com/lmarzen/esp32-weather-epd).
- Zigbee2MQTT:
  [zigbee2mqtt#24198](https://github.com/Koenkk/zigbee2mqtt/discussions/24198).
- Automations:
    - Smart chair: contact sensor
      ([reference](https://bogdanbujdea.dev/how-i-made-my-chair-smart-with-10dollar)).
    - Closet lighting.
    - Energy: turn the studio power plug off if computers are off.
    - Safety and security: remind people to turn the alarm on when nobody is at
      home; low-battery alerts for smoke detectors and door/window sensors;
      smoke and CO2 alerts to phones and speakers; leak sensors with automatic
      water shut-off if not overridden; arm the alarm when everyone is away
      (motion notifies everyone, turns lights off, closes blinds, broadcasts on
      speakers).
    - Lights: morning wake-up fade-in, nighttime catch-all shutdown, turn Hue
      lights on when main power goes off, night red lights in the corridor,
      holiday lights, motion lights in kitchen and hallways at night,
      dusk-to-armed-night outdoor lights, kids lights-out mode after bedtime,
      bedside all-on/off button, motion plus BLE presence to turn lights off,
      movie mode, all-asleep mode dimming to 1%.
    - Voice commands: control lights.
    - Reminders and announcements: whole-home speaker announcements based on
      calendar events, school pick-up reminder based on presence, commute and
      weather briefing on work days, 17track package notifications (out for
      delivery, delivered).
    - Computers and servers: consumption thresholds (disk, CPU), notify when a
      critical device goes offline, alert if SenseHat readings report 0
      (requires physically power cycling the Raspberry Pi), UPS battery load and
      recharge.
    - Washer and dryer: voice notification when the washing cycle completes.
    - Home theater and TV: "I've got company" scene, one-button entertainment
      center power-on (may need an IR blaster), TV device as master power
      switch, mute speakers when movies play, stop speakers after 10 minutes of
      pause, time-based speaker and Chromecast volume, cap speaker volume at 20%
      on power-off.
    - Kitchen: coffee machine preheating, oven preheat status.
    - Blinds: automate blinds (sunrise/sunset offsets, close on summer sun via
      outside temperature and window lux), close when movies play.
    - Shower: exhaust fan, vanity light, preheat hair tools via smart plugs,
      house lights on, TVs off, curtains closed, heated blanket off.
    - Heating, A/C, and fans: humidity-driven exhaust fans, alert if the
      thermostat is off while heating is on (needs heater state detection), open
      door/window alerts with AC/heater shutdown and restore, wrong-mode
      detection and open-the-windows suggestions, bathroom space heater on a
      smart plug in a closed temperature loop, thermostat setpoints per
      presence, day/time, and alarm state.
    - Windows and doors: open-for-X-minutes phone alerts, leaving-home check
      with presence logic, integration with a whole-house fan.
    - [Zigbee/Z-Wave device notification blueprint](https://www.reddit.com/r/homeassistant/comments/116tk8l/psa_blueprint_to_notify_of_zigbeezwave_devices).
- Routines (ideas):
    - Good-night command: lights and TVs off, doors locked, bedroom fan on.
    - Morning: blinds up and motion lights on a schedule, with snooze buttons.
    - Wake-up button: lights, thermostat, coffee maker (only if it has water,
      otherwise announce it).
    - Bedtime button: lights off, thermostat, TV off, doors locked, bedside lamp
      at 10%.
    - Bathroom motion light, fan only above 65% humidity.
    - Night bathroom light at 10% within certain hours.
    - Pressure sensor turns on the TV when sitting down.
    - BLE beacon in the car disarms the alarm on arrival.
    - Door unlock: kitchen lights, thermostat, TV with a welcome announcement.
    - Bathroom-door contact sensor locks the outside doors.
    - Start streaming radio when the phone is detected in a zone (work).
    - Occupancy-based automations driven by alarm state instead of schedules;
      doors auto-deadbolt at a set time with a text alert.
    - Phones-charging-after-bedtime trigger: lights off, fan on, delayed TV off.
- Integrations to configure:
    - [ha-smartthinq-sensors](https://github.com/ollo69/ha-smartthinq-sensors)
    - [Syncthing](https://www.home-assistant.io/integrations/syncthing/)
    - [Local to-do](https://www.home-assistant.io/integrations/local_todo)
    - [Google Tasks](https://www.home-assistant.io/integrations/google_tasks)
    - [Feedreader](https://www.home-assistant.io/integrations/feedreader)
    - House map on dashboard
      ([ha-floorplan](https://github.com/ExperienceLovelace/ha-floorplan))
    - Family calendar
    - Toyota MyT
    - Frigate
    - [Backup](https://www.home-assistant.io/integrations/backup/)
    - [Bluetooth tracker](https://www.home-assistant.io/integrations/bluetooth_tracker/)
    - [Bluetooth LE tracker](https://www.home-assistant.io/integrations/bluetooth_le_tracker/)
    - [Certificate expiry](https://www.home-assistant.io/integrations/cert_expiry/):
      ferrari.how
    - [Google Assistant](https://www.home-assistant.io/integrations/google_assistant/)
    - Needs a Google Cloud project:
      [Google Calendars](https://www.home-assistant.io/integrations/google/),
      [Google Pub/Sub](https://www.home-assistant.io/integrations/google_pubsub/)
    - [Cloudflare](https://www.home-assistant.io/integrations/cloudflare/)
    - [Google Maps](https://www.home-assistant.io/integrations/google_maps/)
    - [Google Sheets](https://www.home-assistant.io/integrations/google_sheets)
    - [Google Travel Time](https://www.home-assistant.io/integrations/google_travel_time/)
    - [Energy monitoring](https://www.home-assistant.io/docs/energy/): overall
      consumption, set energy costs,
      [utility meter](https://www.home-assistant.io/integrations/utility_meter)
    - Gas consumption monitoring
    - [Mobile app](https://www.home-assistant.io/integrations/mobile_app/)
    - Water consumption monitoring
    - [Whois](https://www.home-assistant.io/integrations/whois): ferrari.how
      (this TLD is not currently supported)
    - [Speedtest.net](https://www.home-assistant.io/integrations/speedtestdotnet)
- Dashboard.

### Backup

- Cross-host workloads backup.
- Storage replication: prefer "one-way replication where the direction reverses
  sometimes" over two-way replication, which is harder to implement. Filesystem
  level: ZFS replication.
- Immich to copy data from phones to the NAS.
- Restic: enable the full-read check on a schedule. A plain restic check already
  runs with the backup unit; the
  [--read-data variant](https://restic.readthedocs.io/en/latest/045_working_with_repos.html#checking-integrity-and-consistency)
  exists behind RESTIC_ENABLE_REPOSITORY_CHECK_ALL_DATA in the restic
  entrypoint, but no unit enables it.
- To backup:
    - Proxmox hosts
      ([Proxmox Cluster File System (pmxcfs)](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#chapter_pmxcfs)).
    - Docker Compose volumes: qBittorrent volumes.
    - Move to network storage: ebooks, comics, photos.
    - Media: movies, shows, ebooks, comics, game saves, software and drivers.
    - Needs disk encryption: passwords, 2 factor authentication secrets, backup
      access codes, Ansible secrets (vault.yaml files, the
      home-lab-node-ssh-key.pub public key file), ESPHome secrets, gateway
      configuration, photos (RAWs, Lightroom library), GitHub (private and
      public repositories and gists), Google accounts data.
- Destinations:
    - Offsite backup: deploy an offsite host, configure Tailscale, network
      shares, and the backup (repository, schedule, scheduled restic check,
      retention).
    - Cloud backup: cloud sync via Rclone if the provider is not supported by
      Restic
      ([VFS caching](https://rclone.org/commands/rclone_mount/#vfs-file-caching)
      to keep retrieval costs down); providers to evaluate: Google Cloud,
      Backblaze, Amazon Glacier, Google Drive; then configure the backup
      (repository, schedule, scheduled restic check, retention).

### NAS

Related specification: [NAS LXC Container](./nas-lxc-container.md).

- **NFS support**: Re-introduce NFS sharing alongside SMB. Evaluate
  `nfs-kernel-server` in a privileged container versus the user-space
  NFS-Ganesha server, which can run in an unprivileged container.
- **Automated template upload**: Replace the local-file push
  (`proxmox_virtual_environment_file` pointing at the local build artifact, per
  the framework pattern) with `proxmox_virtual_environment_download_file`
  pulling the template from a published URL, removing the need for a locally
  built artifact at `terraform apply` time.
- **Samba performance tuning**: Benchmark before adding any tuning to the `nas`
  role. Modern Samba enables AIO by default, and the classic knobs interact (a
  non-zero `aio write size` disables `min receivefile size`), so tuning without
  measurement is at best a no-op.
- **GitOps requires the `comin` role per host**: comin needs a hostname at build
  time, so it cannot ride in the shared, hostname-less bootstrap template (see
  [template generation](./proxmox-lxc.md#5-lxc-template-generation)). Each NAS
  host's `configuration.nix` must therefore import the `comin` role itself,
  which is installed by the one-time `nixos-rebuild switch` handoff. True
  zero-touch first-boot GitOps would require working around comin's build-time
  hostname model.
- **Samba password automation**: Replace the imperative `smbpasswd` step
  ([SMB user management](./nas-lxc-container.md#72-imperative-part-one-time-setup))
  with a mechanism/material split that keeps secrets out of the public
  repository (committing encrypted secrets — e.g. `sops-nix` ciphertext — was
  considered and rejected: this repository's policy keeps even encrypted secrets
  untracked, and public Git history is immortal). Design: the `nas` role ships a
  oneshot systemd unit that, on every activation, reads a password file from a
  well-known path and pipes it into `smbpasswd -s -a ferrarimarco`; the Ansible
  layer that already manages the Proxmox nodes writes that file (root-only,
  `0600`) to `/var/lib/samba-state/nas-pveN/smb-password` from a vaulted
  (untracked) variable, so the container's existing `/var/lib/samba` bind mount
  delivers it. Container recreation then self-heals the password database,
  rotation is an Ansible run plus a unit restart, and disaster recovery reduces
  to the local Ansible vault, as for every other secret in the lab.
- **SMB service discovery**: Enable Samba's WS-Discovery or Avahi for automatic
  share browsing on Windows and macOS clients.
- **Static IP migration**: Transition from DHCP to static IP assignments defined
  in the NixOS configuration once the network spec is written.
- **Terraform-managed ZFS pools (evaluated 2026-08, deferred)**: the
  `bpg/proxmox` provider (since 0.111.x) offers
  [`proxmox_node_disk_zfs`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/node_disk_zfs)
  for node ZFS pool lifecycle. Transitioning the pool layer of the `setup_disks`
  role (see
  [dataset mount points](./nas-lxc-container.md#111-zfs-dataset-mount-points-on-the-host))
  to it was evaluated and rejected for now: its pool attributes (`devices`,
  `raidlevel`, `ashift`, `compression`) are write-only, so the Terraform config
  would be the same unverified documentation the `zfs_pools` inventory already
  is, with no drift detection; the provider manages pools only, so datasets and
  mount-point ownership would stay in Ansible, splitting the ZFS layer across
  two tools; and with the local Terraform state backend, losing state would
  invert the deliberate "pools are asserted, never created" stance into a
  pool-creation attempt on data-bearing devices at the next apply. Revisit when
  the provider gains readable pool attributes (real drift detection) or dataset
  management, or when a durable remote state backend is in place.
- **Single source of truth for shares**: Derive the Samba share exports (NixOS),
  the bind mounts (Terraform), and the host datasets (Ansible `zfs_datasets`,
  [dataset mount points](./nas-lxc-container.md#111-zfs-dataset-mount-points-on-the-host))
  from one data structure — for example a Nix attrset emitted to `tfvars` via
  `nix eval` — so each share is declared once and the three halves cannot drift
  (see [per-host shares](./nas-lxc-container.md#51-adding-per-host-shares)).

### Cloud environment

- Configure a cloud environment on Google Cloud: create the resource hierarchy.
- Set quotas to match the caps of the free tier when possible
  ([capping usage](https://cloud.google.com/docs/quota#capping_usage),
  [disable billing to stop usage](https://cloud.google.com/billing/docs/how-to/notify#cap_disable_billing_to_stop_usage)).

### Documentation

- Documentation automation: generate the endpoints list, the monitoring checks,
  the inventory, the list of Home Assistant automations, and the list of cron
  jobs from the configuration instead of maintaining them by hand.
