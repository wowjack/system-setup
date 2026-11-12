# Test-only stand-in for hosts/nixos/hardware-configuration.nix.
# Lets `nix flake check` evaluate the full system before the real machine's
# hardware file exists. Never used to build a bootable system.
{
  nixpkgs.hostPlatform = "x86_64-linux";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
}
