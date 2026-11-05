{
  pkgs,
  netboot,
  ...
}:

# The Raspberry Pi boot path. The bootloader sends a PXE-class DHCP discover
# and looks for a reply carrying the "Raspberry Pi Boot" vendor option, whose
# server address is the TFTP server it then fetches its boot files from,
# under the per-host directory its EEPROM prefix names.
{
  pxeServices = [ "0,\"Raspberry Pi Boot\"" ];

  # Replaces the image's own: 64-bit mode, the Lite kernel with the initramfs
  # that mounts the NFS root, and the serial console for a headless rescue.
  renderBootConfig =
    { hostName, kernelParameters }:
    pkgs.runCommand "netboot-boot-config-${hostName}" { } ''
      mkdir "$out"
      cat > "$out/config.txt" <<'CONFIG'
      arm_64bit=1
      enable_uart=1
      kernel=kernel8.img
      initramfs initramfs8 followkernel
      CONFIG
      printf '%s\n' 'console=serial0,115200 console=tty1 ${kernelParameters}' > "$out/cmdline.txt"
    '';

  publish =
    {
      hostName,
      bootFilesDir,
      bootConfig,
    }:
    "${netboot} publish ${hostName} ${bootFilesDir} ${bootConfig}";

  withdraw = { hostName }: "${netboot} withdraw ${hostName}";
}
