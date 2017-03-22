home_lab = {
  "pluto" => {
    :box => "boxcutter/ubuntu1604-i386",
    :cpus => 1,
    :ip => "192.168.33.13",
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
        vb.customize ["modifyvm", :id,
          "--cableconnected1", "on",
          "--cpus", info[:cpus],
          "--hwvirtex", "on",
          "--name", hostname,
          "--memory", info[:mem]
        ]
      end
    end
  end
end
