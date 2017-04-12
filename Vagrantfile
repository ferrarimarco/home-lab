ANSIBLE_CONTROL_MACHINE_NAME = "deimos"
DOMAIN = ".ferrari.home"
INTNET_NAME = "ferrari.home.network"
NETWORK_TYPE_DHCP = "dhcp"
NETWORK_TYPE_STATIC_IP = "static_ip"
SUBNET_MASK = "255.255.0.0"

home_lab = {
  ANSIBLE_CONTROL_MACHINE_NAME + DOMAIN => {
    :box => "boxcutter/ubuntu1604",
    :cpus => 2,
    :mem => 512,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP
  },
  "europa" + DOMAIN => {
    :box => "boxcutter/ubuntu1604",
    :cpus => 1,
    :mem => 512,
    :ip => "192.168.0.5",
    :net_auto_config => true,
    :net_type => NETWORK_TYPE_STATIC_IP,
    :subnet_mask => SUBNET_MASK
  },
  "pluto" + DOMAIN => {
    :box => "boxcutter/ubuntu1604-i386",
    :cpus => 1,
    :mem => 512,
    :net_auto_config => false,
    :net_type => NETWORK_TYPE_DHCP,
  }
}

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  home_lab.each do |(hostname, info)|
    config.vm.define hostname do |host|
      host.vm.box = "#{info[:box]}"
      host.vm.hostname = hostname
      if(NETWORK_TYPE_DHCP == info[:net_type]) then
        host.vm.network :private_network, auto_config: info[:net_auto_config], type: NETWORK_TYPE_DHCP, virtualbox__intnet: INTNET_NAME
      elsif(NETWORK_TYPE_STATIC_IP == info[:net_type])
        host.vm.network :private_network, auto_config: info[:net_auto_config], ip: "#{info[:ip]}", :netmask => "#{info[:subnet_mask]}", virtualbox__intnet: INTNET_NAME
      end
      host.vm.provider :virtualbox do |vb|
        vb.name = hostname
        vb.customize ["modifyvm", :id, "--cpus", info[:cpus]]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--memory", info[:mem]]
        vb.customize ["modifyvm", :id, "--name", hostname]
      end
      if(hostname.include? ANSIBLE_CONTROL_MACHINE_NAME) then
        host.vm.provision "shell", path: "scripts/install_docker.sh"
      end
    end
  end
end
