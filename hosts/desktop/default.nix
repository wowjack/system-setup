# Settings specific to this machine. The disk layout is in ./disko.nix; other
# hardware (kernel modules, CPU microcode) is in ./hardware-configuration.nix,
# generated on the machine itself.
{
  imports = [
    ../../modules/nixos
    # The disk is only chosen (and erased) when installing; afterwards filesystems
    # are found by partition label, so this device path is never used.
    (import ./disko.nix { device = "/dev/disk/by-id/chosen-at-install"; })
  ];

  networking.hostName = "desktop";

  boot.loader = {
    systemd-boot = {
      enable = true;
      # Keep /boot from filling up with old generations.
      configurationLimit = 10;
      # No editing of kernel parameters from the boot menu: `init=/bin/sh` there
      # would give a root shell without a password (SECURITY.md, "Disk").
      editor = false;
    };
    efi.canTouchEfiVariables = true;
  };

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  # The NixOS release this machine was first installed with. It controls the
  # defaults for stateful data (databases, etc.), NOT the package versions.
  # Do not change it after installation.
  system.stateVersion = "26.05";
}
