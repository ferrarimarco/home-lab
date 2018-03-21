require 'ipaddr'

DNSMASQ_MACHINE_NAME = "europa"
DNSMASQ_MACHINE_IP = "192.168.0.5"
DOMAIN_SUFFIX = "lab.ferrarimarco.info"
DOMAIN = "." + DOMAIN_SUFFIX
GATEWAY_IP_ADDRESS = "192.168.0.1"
GATEWAY_MACHINE_NAME = "sun"
INTNET_NAME = DOMAIN_SUFFIX + ".network"
NETWORK_TYPE_DHCP = "dhcp"
NETWORK_TYPE_STATIC_IP = "static_ip"
SUBNET_MASK = "255.255.0.0"
IP_V4_CIDR = IPAddr.new(SUBNET_MASK).to_i.to_s(2).count("1")
UPSTREAM_DNS_SERVER = "8.8.8.8"
VAGRANT_X64_LINUX_BOX_ID = "bento/ubuntu-16.04"
VAGRANT_X64_WINDOWS_BOX_ID = "ferrarimarco/windows-10-x64-enterprise"

home_lab = {
  GATEWAY_MACHINE_NAME + DOMAIN => {
    :autostart => true,
    :box => VAGRANT_X64_LINUX_BOX_ID,
    :cpus => 1,
    :dns_server_address => DNSMASQ_MACHINE_IP,
    :mac_address => "0800271F9D46",
    :mem => 512,
    :ip => GATEWAY_IP_ADDRESS,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_STATIC_IP,
    :subnet_mask => SUBNET_MASK,
    :show_gui => false
  },
  DNSMASQ_MACHINE_NAME + DOMAIN => {
    :autostart => true,
    :box => VAGRANT_X64_LINUX_BOX_ID,
    :cpus => 1,
    :dns_server_address => UPSTREAM_DNS_SERVER,
    :mac_address => "0800271F9D44",
    :mem => 512,
    :ip => DNSMASQ_MACHINE_IP,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_STATIC_IP,
    :subnet_mask => SUBNET_MASK,
    :show_gui => false
  },
  "deimos" + DOMAIN => {
    :autostart => true,
    :box => VAGRANT_X64_LINUX_BOX_ID,
    :cpus => 2,
    :mac_address => "0800271F9D43",
    :mem => 512,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP,
    :show_gui => false
  },
  "mars" + DOMAIN => {
    :autostart => true,
    :box => VAGRANT_X64_WINDOWS_BOX_ID,
    :cpus => 1,
    :mac_address => "0800271F9D47",
    :mem => 2048,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP,
    :show_gui => true
  },
  "phobos" + DOMAIN => {
    :autostart => true,
    :box => VAGRANT_X64_WINDOWS_BOX_ID,
    :cpus => 1,
    :mac_address => "0800271F9D48",
    :mem => 2048,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP,
    :show_gui => false
  }
}

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  home_lab.each do |(hostname, info)|
    config.vm.define hostname, autostart: info[:autostart] do |host|
      host.vm.box = "#{info[:box]}"
      if(NETWORK_TYPE_DHCP == info[:net_type])
        host.vm.network :private_network, auto_config: info[:net_auto_config], :mac => "#{info[:mac_address]}", type: info[:net_type], virtualbox__intnet: INTNET_NAME
      elsif(NETWORK_TYPE_STATIC_IP == info[:net_type])
        host.vm.network :private_network, auto_config: info[:net_auto_config], :mac => "#{info[:mac_address]}", ip: "#{info[:ip]}", :netmask => "#{info[:subnet_mask]}", virtualbox__intnet: INTNET_NAME
      end

      host.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
        vb.customize ["modifyvm", :id, "--cpus", info[:cpus]]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--memory", info[:mem]]
        vb.customize ["modifyvm", :id, "--name", hostname]
        vb.customize ["modifyvm", :id, "--vram", "128"] # 10 MB is the minimum to enable Virtualbox seamless mode
        vb.gui = info[:show_gui]
        vb.name = hostname

        if(host.vm.box == VAGRANT_X64_WINDOWS_BOX_ID)
          vb.customize ["setextradata", "global", "GUI/MaxGuestResolution", "any"]
          vb.customize ["setextradata", "global", "GUI/SuppressMessages", "all" ]
          vb.customize ["setextradata", :id, "CustomVideoMode1", "1024x768x32"]
        end
      end

      if(host.vm.box == VAGRANT_X64_WINDOWS_BOX_ID)
        host.ssh.insert_key = false
        host.vm.communicator = "winrm"
        host.vm.guest = :windows
        host.vm.hostname = hostname.sub DOMAIN, ''
        host.windows.halt_timeout = 15
        host.vm.provision "shell", path: "scripts/windows/configure-network-zone.ps1"
      else
        host.vm.hostname = hostname

        # Remove all the interfaces in /etc/network/interfaces as a workaround for:
        # https://github.com/hashicorp/vagrant/issues/9222
        # https://github.com/chef/bento/issues/1003
        host.vm.provision "shell", path: "scripts/ubuntu/cleanup-network-interfaces.sh"

        # Let's use the upstream server in the machine that will host our DNS
        # server because we cannot start the Dnsmasq container (with the
        # integrated DNS server) if we don't first install Docker and run a
        # ferrarimarco/home-lab-dnsmasq container. The name resolution will be
        # reconfigured to use our DNS server after such server is available
        ip_v4_dns_server_address = (hostname.include? DNSMASQ_MACHINE_NAME) ? UPSTREAM_DNS_SERVER : DNSMASQ_MACHINE_IP

        host.vm.provision "shell" do |s|
          s.path = "scripts/ubuntu/configure-name-resolution.sh"
          s.args = [
            "--ip-v4-dns-nameserver", ip_v4_dns_server_address
            ]
        end

        if(hostname.include? GATEWAY_MACHINE_NAME)
          host.vm.provision "shell" do |s|
            s.path = "scripts/ubuntu/configure-gateway-network.sh"
            s.args = ["#{info[:ip]}", "#{info[:dns_server_address]}", SUBNET_MASK, DOMAIN_SUFFIX]
          end
        else
          host.vm.provision "shell" do |s|
            s.path = "scripts/ubuntu/configure-volatile-network-interface.sh"
            s.args = [
              "--ip-v4-host-address", "#{info[:ip]}",
              "--ip-v4-host-cidr", IP_V4_CIDR,
              "--network-type", "#{info[:net_type]}"
              ]
          end
          # Ensure we are temporarily going through the gateway
          host.vm.provision "shell" do |s|
            s.path = "scripts/ubuntu/configure-volatile-default-route.sh"
            s.args = [
              "--ip-v4-gateway-ip-address", GATEWAY_IP_ADDRESS
              ]
          end

          host.vm.provision "shell", path: "scripts/ubuntu/install-network-manager.sh"

          # Ensure we are going through the gateway
          host.vm.provision "shell" do |s|
            s.path = "scripts/ubuntu/configure-default-route.sh"
            s.args = [
              "--ip-v4-gateway-ip-address", GATEWAY_IP_ADDRESS
              ]
          end

          if(NETWORK_TYPE_STATIC_IP == info[:net_type])
            host.vm.provision "shell" do |s|
              s.path = "scripts/ubuntu/configure-network-manager.sh"
              s.args = [
                "--domain", DOMAIN_SUFFIX,
                "--ip-v4-dns-nameserver", ip_v4_dns_server_address,
                "--ip-v4-gateway-ip-address", GATEWAY_IP_ADDRESS,
                "--ip-v4-host-cidr", IP_V4_CIDR,
                "--ip-v4-host-address", "#{info[:ip]}",
                "--network-type", "#{info[:net_type]}"
              ]
            end
          elsif(NETWORK_TYPE_DHCP == info[:net_type])
            host.vm.provision "shell" do |s|
              s.path = "scripts/ubuntu/configure-network-manager.sh"
              s.args = [
                "--network-type", "#{info[:net_type]}"
              ]
            end
          end

          if(hostname.include? DNSMASQ_MACHINE_NAME)
            host.vm.provision "shell" do |s|
              s.path = "scripts/ubuntu/install-docker.sh"
              s.args = [
                "--user", "vagrant"
                ]
            end

            # Initialize Docker Swarm Manager
            host.vm.provision "shell" do |s|
              s.path = "scripts/ubuntu/initialize-docker-swarm-manager.sh"
              s.args = [
                "--manager-ip", DNSMASQ_MACHINE_IP
                ]
            end

            # Start DNSMASQ
            host.vm.provision "shell", path: "scripts/ubuntu/start-dnsmasq.sh"

            # Init and start ddclient
            host.vm.provision "file", source: "configuration/ddclient", destination: "/tmp/ddclient"
            host.vm.provision "shell", path: "scripts/ubuntu/init-ddclient-configuration.sh"
            host.vm.provision "shell", path: "scripts/docker/start-ddclient.sh"

            # Reconfigure name resolution to use our DNS server
            host.vm.provision "shell" do |s|
              s.path = "scripts/ubuntu/configure-name-resolution.sh"
              s.args = [
                "--ip-v4-dns-nameserver", DNSMASQ_MACHINE_IP
                ]
            end
          end
        end
      end
    end
  end
end
