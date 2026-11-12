# System-level (root-owned) configuration, shared by any host that imports it.
{
  imports = [
    ./nix.nix
    ./storage.nix
    ./secrets.nix
    ./desktop.nix
    ./wireguard
    ./virtualisation.nix
    ./gaming.nix
    ./users.nix
  ];
}
