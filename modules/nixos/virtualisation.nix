# Containers and virtual machines.
{
  # Rootless Docker: the daemon runs as your user, so being able to use Docker
  # does not mean being root-equivalent (as membership in the `docker` group would).
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # QEMU/KVM through libvirt, managed with virt-manager.
  # Requires membership in the `libvirtd` group (see users.nix).
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
}
