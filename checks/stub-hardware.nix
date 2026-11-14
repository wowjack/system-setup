# Test-only stand-in for hosts/<host>/hardware-configuration.nix.
# Lets `nix flake check` evaluate the full system before the real machine's
# hardware file exists. Filesystems come from hosts/<host>/disko.nix, as they do
# on the real machine (its hardware file is generated with --no-filesystems).
{
  nixpkgs.hostPlatform = "x86_64-linux";
}
