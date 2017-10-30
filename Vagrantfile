DNSMASQ_MACHINE_NAME = "europa"
DNSMASQ_MACHINE_IP = "192.168.0.5"
DOMAIN_SUFFIX = "ferrari.home"
DOMAIN = "." + DOMAIN_SUFFIX
GATEWAY_IP_ADDRESS = "192.168.0.1"
GATEWAY_MACHINE_NAME = "sun"
INTNET_NAME = DOMAIN_SUFFIX + ".network"
NETWORK_INTERFACE_NAME = "enp0s8"
NETWORK_TYPE_DHCP = "dhcp"
NETWORK_TYPE_STATIC_IP = "static_ip"
SUBNET_MASK = "255.255.0.0"
UPSTREAM_DNS_SERVER = "8.8.8.8"
VAGRANT_X64_LINUX_BOX_ID = "bento/ubuntu-16.04"
VAGRANT_X86_LINUX_BOX_ID = "bento/ubuntu-16.04-i386"

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
    :autostart => false,
    :box => "senglin/win-10-enterprise-vs2015community",
    :cpus => 1,
    :mac_address => "0800271F9D47",
    :mem => 1024,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP,
    :show_gui => true
  }
}

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  home_lab.each do |(hostname, info)|
    config.vm.define hostname, autostart: info[:autostart] do |host|
      host.vm.box = "#{info[:box]}"
      if(NETWORK_TYPE_DHCP == info[:net_type])
        host.vm.network :private_network, auto_config: info[:net_auto_config], :mac => "#{info[:mac_address]}", type: NETWORK_TYPE_DHCP, virtualbox__intnet: INTNET_NAME
      elsif(NETWORK_TYPE_STATIC_IP == info[:net_type])
        host.vm.network :private_network, auto_config: info[:net_auto_config], :mac => "#{info[:mac_address]}", ip: "#{info[:ip]}", :netmask => "#{info[:subnet_mask]}", virtualbox__intnet: INTNET_NAME
      end

      host.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--cpus", info[:cpus]]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--memory", info[:mem]]
        vb.customize ["modifyvm", :id, "--name", hostname]
        vb.gui = info[:show_gui]
        vb.name = hostname
      end

      if(host.vm.box.downcase.include? "win")
        host.vm.hostname = hostname.sub DOMAIN, ''
      else
        host.vm.hostname = hostname
        # Configure network for hosts with static IPs
        if(NETWORK_TYPE_STATIC_IP == info[:net_type])
          host.vm.provision "shell" do |s|
            s.path = "scripts/configure_network.sh"
            s.args = [NETWORK_INTERFACE_NAME, "#{info[:ip]}", "#{info[:dns_server_address]}", GATEWAY_IP_ADDRESS, SUBNET_MASK, DOMAIN_SUFFIX]
          end
        elsif(NETWORK_TYPE_DHCP == info[:net_type])
          host.vm.provision "shell" do |s|
            s.path = "scripts/configure_network.sh"
            s.args = [NETWORK_INTERFACE_NAME, NETWORK_TYPE_DHCP, GATEWAY_IP_ADDRESS]
          end
        end
        if(hostname.include? DNSMASQ_MACHINE_NAME)
          # Let's use the upstream server for now because we cannot start
          # the Dnsmasq container (with the integrated DNS server) if we don't
          # first install Docker and run a ferrarimarco/home-lab-dnsmasq container
          # The name resolution will be reconfigured after the container starts
          host.vm.provision "shell" do |s|
            s.path = "scripts/configure_name_resolution.sh"
            s.args   = [UPSTREAM_DNS_SERVER, DOMAIN_SUFFIX]
          end
          host.vm.provision "shell", path: "scripts/install_docker.sh"
          host.vm.provision "shell", path: "scripts/start_dnsmasq.sh"
        end
        # Configure network name resolution for all hosts
        host.vm.provision "shell" do |s|
          s.path = "scripts/configure_name_resolution.sh"
          s.args = [DNSMASQ_MACHINE_IP, DOMAIN_SUFFIX]
        end
      end
    end
  end
end
