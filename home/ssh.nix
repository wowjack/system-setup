# SSH key pair. Both files are sops secrets (modules/nixos/secrets.nix),
# decrypted into /run/secrets on boot and on every switch; ~/.ssh links to them.
{ config, ... }:
let
  secret = name: config.lib.file.mkOutOfStoreSymlink "/run/secrets/${name}";
in
{
  home.file = {
    ".ssh/id_ed25519".source = secret "ssh_id_ed25519";
    ".ssh/id_ed25519.pub".source = secret "ssh_id_ed25519_pub";
  };
}
