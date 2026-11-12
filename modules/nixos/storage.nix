# Services for the btrfs disk layout in hosts/nixos/disko.nix.
{
  # Compressed swap in RAM (up to half of it). Used before the 8 GB swapfile,
  # which only takes overflow.
  zramSwap.enable = true;

  # Monthly read of all data, verifying checksums to detect silent corruption.
  services.btrfs.autoScrub.enable = true;

  # Hourly and daily snapshots of /home, on the same disk. They undo mistakes
  # (deleted or overwritten files) but don't protect against disk failure.
  # Browse them in /home/.snapshots/<number>/snapshot, or with `snapper -c home list`.
  # Deleted files keep using space until the snapshots holding them expire (7 days).
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    # Lets `user` list and browse snapshots without sudo.
    ALLOW_USERS = [ "user" ];
    SYNC_ACL = true;
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 24;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 0;
    TIMELINE_LIMIT_MONTHLY = 0;
    TIMELINE_LIMIT_QUARTERLY = 0;
    TIMELINE_LIMIT_YEARLY = 0;
  };
}
