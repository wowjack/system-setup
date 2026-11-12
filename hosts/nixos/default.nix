# Settings specific to this machine. Hardware (disks, kernel modules, CPU microcode)
# lives in ./hardware-configuration.nix, generated on the machine itself.
{
  imports = [ ../../modules/nixos ];

  networking.hostName = "nixos";

  boot.loader = {
    systemd-boot = {
      enable = true;
      # Keep /boot from filling up with old generations.
      configurationLimit = 10;
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
