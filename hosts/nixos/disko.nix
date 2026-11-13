# Disk layout: one GPT disk with an EFI system partition and a btrfs partition
# divided into subvolumes. It is used in two ways:
#
# - At install time, disko ERASES the chosen disk and creates this layout
#   (see README.md):
#     disko --mode destroy,format,mount --argstr device /dev/disk/by-id/<disk> hosts/nixos/disko.nix
# - The NixOS configuration (./default.nix) imports it to generate the
#   filesystem and swap entries. Those refer to partitions by label
#   (disk-main-ESP, disk-main-root), so the installed system doesn't need to
#   know which disk was chosen.
#
# The subvolumes are laid out for impermanence (wiping / on every boot) later:
# everything that must survive such a wipe lives outside the /root subvolume.
#
# `...` is required: the disko CLI calls this function with all of its own
# arguments (lib, mode, diskoFile, ...) in addition to `device`.
{ device, ... }:
let
  mountOptions = [
    "compress=zstd" # transparent compression
    "noatime" # don't write access times on every read
  ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              # The system root. Impermanence would recreate it empty on every boot.
              "/root" = {
                mountpoint = "/";
                inherit mountOptions;
              };
              "/home" = {
                mountpoint = "/home";
                inherit mountOptions;
              };
              # Where snapper keeps /home's snapshots (modules/nixos/storage.nix).
              "/home/.snapshots" = { };
              # The Nix store: rebuilt-from-config software, must never be wiped.
              "/nix" = {
                mountpoint = "/nix";
                inherit mountOptions;
              };
              # Empty for now. With impermanence, the state to keep across
              # boots (network connections, Bluetooth pairings, VMs, ...) lives here.
              "/persist" = {
                mountpoint = "/persist";
                inherit mountOptions;
              };
              # System logs, kept across future root wipes.
              "/log" = {
                mountpoint = "/var/log";
                inherit mountOptions;
              };
              # Overflow swap behind zram (modules/nixos/storage.nix).
              "/swap" = {
                mountpoint = "/swap";
                swap.swapfile.size = "8G";
              };
            };
          };
        };
      };
    };
  };
}
