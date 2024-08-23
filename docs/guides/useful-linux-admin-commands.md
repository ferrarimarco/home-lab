# Useful Linux administration notes

## Debian

### OS package management

- Get the versions that are available to install of a package: `apt-cache madison <package-name>`
- Install a specific package version: `apt-get install <package-name>=<package-version-number>`
- The package update logs are in `/var/log/apt/history.log`

## Networking

- Get the list of open ports on a system (with superuser privileges, it also
  returns process information): `sudo netstat -nlp`
