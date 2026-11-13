# User accounts, and Home Manager for each of them.
{ config, ... }:
{
  # Accounts and passwords come only from this configuration: `passwd` changes
  # are overwritten on the next switch. To change the password, change its hash
  # in secrets/secrets.yaml (see README.md, "Secrets").
  users.mutableUsers = false;

  users.users.user = {
    isNormalUser = true;
    description = "Jack";
    hashedPasswordFile = config.sops.secrets.user_password_hash.path;
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # manage network connections without a password prompt
      "libvirtd" # manage system VMs with virt-manager
    ];
  };

  home-manager = {
    # Use the system's nixpkgs (and its unfree allowlist) instead of a second copy.
    useGlobalPkgs = true;
    # Install user packages into /etc/profiles/per-user instead of ~/.nix-profile.
    useUserPackages = true;
    # If a file Home Manager wants to manage already exists, move it aside
    # (e.g. ~/.bashrc -> ~/.bashrc.hm-backup) instead of failing the switch.
    backupFileExtension = "hm-backup";
    users.user = import ../../home;
  };
}
