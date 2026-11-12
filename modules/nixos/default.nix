# System-level (root-owned) configuration, shared by any host that imports it.
{
  imports = [
    ./nix.nix
    ./storage.nix
    ./desktop.nix
    ./virtualisation.nix
    ./gaming.nix
    ./users.nix
  ];
}
