DEIMOS_MACHINE_NAME = "deimos"
DNSMASQ_MACHINE_NAME = "europa"
DOMAIN = ".ferrari.home"
GATEWAY_MACHINE_NAME = "sun"
INTNET_NAME = "ferrari.home.network"
NETWORK_TYPE_DHCP = "dhcp"
NETWORK_TYPE_STATIC_IP = "static_ip"
SUBNET_MASK = "255.255.0.0"

home_lab = {
  DEIMOS_MACHINE_NAME + DOMAIN => {
    :autostart => false,
    :box => "boxcutter/ubuntu1604",
    :cpus => 2,
    :mac_address => "0800271F9D43",
    :mem => 512,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP,
    :show_gui => false
  },
  DNSMASQ_MACHINE_NAME + DOMAIN => {
    :autostart => true,
    :box => "boxcutter/ubuntu1604",
    :cpus => 1,
    :mac_address => "0800271F9D44",
    :mem => 512,
    :ip => "192.168.0.5",
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_STATIC_IP,
    :subnet_mask => SUBNET_MASK,
    :show_gui => false
  },
  GATEWAY_MACHINE_NAME + DOMAIN => {
    :autostart => true,
    :box => "boxcutter/ubuntu1604",
    :cpus => 1,
    :mac_address => "0800271F9D46",
    :mem => 512,
    :ip => "192.168.0.1",
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_STATIC_IP,
    :subnet_mask => SUBNET_MASK,
    :show_gui => false
  },
  "pluto" + DOMAIN => {
    :autostart => false,
    :box => "clink15/pxe",
    :cpus => 1,
    :mac_address => "0800271F9D45",
    :mem => 512,
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
      host.vm.hostname = hostname
      if(NETWORK_TYPE_DHCP == info[:net_type]) then
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

      if(hostname.include? DNSMASQ_MACHINE_NAME) then
        host.vm.provision "shell", path: "scripts/configure_europa_network.sh"
        host.vm.provision "shell", path: "scripts/install_docker.sh"
        host.vm.provision "shell", path: "scripts/build_ansible_image.sh"
      end

      if(hostname.include? DEIMOS_MACHINE_NAME) then
        host.vm.provision "shell", path: "scripts/configure_deimos_network.sh"
      end

      if(hostname.include? GATEWAY_MACHINE_NAME) then
        host.vm.provision "shell", path: "scripts/configure_gateway_network.sh"
      end
    end
  end
end
