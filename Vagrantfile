home_lab = {
  "deimos.ferrari.home-dev" => {
    :box => "boxcutter/ubuntu1604",
    :cpus => 2,
    :ip => "192.168.0.10",
    :mem => 512
  },
  "europa.ferrari.home-dev" => {
    :box => "boxcutter/ubuntu1604",
    :cpus => 1,
    :ip => "192.168.0.11",
    :mem => 512
  },
  "pluto.ferrari.home-dev" => {
    :box => "boxcutter/ubuntu1604-i386",
    :cpus => 1,
    :ip => "192.168.0.12",
    :mem => 512
  }
}

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  home_lab.each do |(hostname, info)|
    config.vm.define hostname do |host|
      host.vm.box = "#{info[:box]}"
      host.vm.synced_folder '.', '/vagrant', disabled: true
      host.vm.hostname = hostname
      host.vm.network :private_network, ip: "#{info[:ip]}"
      host.vm.provider :virtualbox do |vb|
        vb.name = hostname
        vb.customize ["modifyvm", :id, "--cableconnected1", "on"]
        vb.customize ["modifyvm", :id, "--cpus", info[:cpus]]
        vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
        vb.customize ["modifyvm", :id, "--name", hostname]
        vb.customize ["modifyvm", :id, "--memory", info[:mem]]
      end
    end
  end
end
