# Configure network shares

To allow access to Samba network shares, do the following:

1. Create a Linux system user.
1. Add the user to the Samba database:

   ```shell
   sudo smbpasswd -a "${USER}"
   ```
