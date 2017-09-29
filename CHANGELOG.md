# Change Log

## [Unreleased](https://github.com/ferrarimarco/home-lab/tree/HEAD)

**Implemented enhancements:**

- Set network name prefix using the DOMAIN variable in Vagrantfile [\#56](https://github.com/ferrarimarco/home-lab/issues/56)
- Move "Remove default users" task in ferrarimarco.home-lab-node Ansible role [\#55](https://github.com/ferrarimarco/home-lab/issues/55)
- Configure a Windows 10 Vagrant VM [\#51](https://github.com/ferrarimarco/home-lab/issues/51)
- Create a user to run docker containers [\#46](https://github.com/ferrarimarco/home-lab/issues/46)
- Update to ferrarimarco.docker 1.4.1 ansible role [\#45](https://github.com/ferrarimarco/home-lab/issues/45)
- Don't use pluto as a docker engine host [\#43](https://github.com/ferrarimarco/home-lab/issues/43)
- Create an administrative user [\#42](https://github.com/ferrarimarco/home-lab/issues/42)
- Move home-lab-dnsmasq to a dedicated project [\#41](https://github.com/ferrarimarco/home-lab/issues/41)
- Configure DNS services on Europa after starting the DNS server [\#40](https://github.com/ferrarimarco/home-lab/issues/40)
- Automatically start all instances of the development environment [\#39](https://github.com/ferrarimarco/home-lab/issues/39)
- Build Dnsmasq image and run it on boot when starting the dev environment [\#38](https://github.com/ferrarimarco/home-lab/issues/38)
- Streamline network configuration scripts [\#37](https://github.com/ferrarimarco/home-lab/issues/37)
- Configure nameservers for DHCP clients in the dev environment [\#35](https://github.com/ferrarimarco/home-lab/issues/35)
- Configure a default gateway sitting on 192.168.0.1 [\#34](https://github.com/ferrarimarco/home-lab/issues/34)
- Do not remove APT packages with autoremove if not asked [\#33](https://github.com/ferrarimarco/home-lab/issues/33)
- Add a group containing all the hosts managed by Ansible in inventory [\#32](https://github.com/ferrarimarco/home-lab/issues/32)
- Serve Ubuntu Server 16.04 i386 boot option [\#31](https://github.com/ferrarimarco/home-lab/issues/31)
- Base home-lab-dnsmasq docker image on ferrarimarco/pxe:1.2.0 when available [\#30](https://github.com/ferrarimarco/home-lab/issues/30)
- Use a single dnsmasq instance [\#29](https://github.com/ferrarimarco/home-lab/issues/29)
- Enable query logging in dnsmasq [\#28](https://github.com/ferrarimarco/home-lab/issues/28)
- Raise DHCP server range start from .10 to .50 [\#26](https://github.com/ferrarimarco/home-lab/issues/26)
- Configure a virtualized development environment [\#24](https://github.com/ferrarimarco/home-lab/issues/24)
- Configure a DHCP server [\#22](https://github.com/ferrarimarco/home-lab/issues/22)
- Configure a DNS server for local queries [\#21](https://github.com/ferrarimarco/home-lab/issues/21)
- Provide a Dockerfile for Ansible [\#20](https://github.com/ferrarimarco/home-lab/issues/20)
- Implement a PXE with Memtest86+ and Ubuntu 16.04 boot options [\#19](https://github.com/ferrarimarco/home-lab/issues/19)
- Add Raspi and the Beaglebone to the inventory [\#18](https://github.com/ferrarimarco/home-lab/issues/18)
- Assign host names via DHCP [\#17](https://github.com/ferrarimarco/home-lab/issues/17)
- Add europa to the development environment [\#16](https://github.com/ferrarimarco/home-lab/issues/16)
- Implement a playbook for all hosts to use as a baseline [\#15](https://github.com/ferrarimarco/home-lab/issues/15)
- Use deimos as control machine [\#13](https://github.com/ferrarimarco/home-lab/issues/13)
- Disable /vagrant shared directory [\#12](https://github.com/ferrarimarco/home-lab/issues/12)
- Add ganymede to the inventory [\#10](https://github.com/ferrarimarco/home-lab/issues/10)
- Use pluto as a control-machine [\#9](https://github.com/ferrarimarco/home-lab/issues/9)
- Use europa instead of pluto as a torrentbox [\#8](https://github.com/ferrarimarco/home-lab/issues/8)
- Add pluto machine to Vagrantfile [\#7](https://github.com/ferrarimarco/home-lab/issues/7)
- Write a multi-machine ready Vagrantfile [\#6](https://github.com/ferrarimarco/home-lab/issues/6)
- Add a pxe-servers group to inventory [\#5](https://github.com/ferrarimarco/home-lab/issues/5)
- Add Vagrant artifacts to .gitignore [\#4](https://github.com/ferrarimarco/home-lab/issues/4)
- Deploy public SSH keys in managed hosts [\#2](https://github.com/ferrarimarco/home-lab/issues/2)
- Create an inventory to list the hosts to manage [\#1](https://github.com/ferrarimarco/home-lab/issues/1)

**Fixed bugs:**

- Default route is not persisted after a reboot [\#53](https://github.com/ferrarimarco/home-lab/issues/53)
- Fix name resolution for DHCP clients [\#36](https://github.com/ferrarimarco/home-lab/issues/36)
- Configure nameservers for DHCP clients in the dev environment [\#35](https://github.com/ferrarimarco/home-lab/issues/35)
- Use a single dnsmasq instance [\#29](https://github.com/ferrarimarco/home-lab/issues/29)
- Fix syntax in Vagrantfile [\#11](https://github.com/ferrarimarco/home-lab/issues/11)



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
