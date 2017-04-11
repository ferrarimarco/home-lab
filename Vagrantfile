home_lab = {
  "deimos.ferrari.home-dev" => {
    :box => "boxcutter/ubuntu1604",
    :cpus => 2,
    :ip => "192.168.33.10",
    :mem => 512
  },
  "europa.ferrari.home-dev" => {
    :box => "boxcutter/ubuntu1604",
    :cpus => 1,
    :ip => "192.168.33.11",
    :mem => 512
  },
  "pluto.ferrari.home-dev" => {
    :box => "boxcutter/ubuntu1604-i386",
    :cpus => 1,
    :ip => "192.168.33.12",
    :mem => 512
  }
}

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  home_lab.each_with_index do |(hostname, info), index|
    config.vm.define hostname do |cfg|
      cfg.vm.provider :virtualbox do |vb, override|
        config.vm.box = "#{info[:box]}"
        override.vm.hostname = hostname
        override.vm.network :private_network, ip: "#{info[:ip]}"
        vb.name = hostname
        vb.customize ["modifyvm", :id, "--cableconnected1", "on"]
        vb.customize ["modifyvm", :id, "--cpus", info[:cpus]]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--name", hostname]
        vb.customize ["modifyvm", :id, "--memory", info[:mem]]
        config.vm.synced_folder '.', '/vagrant', disabled: true
      end
    end
  end
end
