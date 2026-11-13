# Secrets, stored sops-encrypted in secrets/ (see README.md, "Secrets").
# On boot and on every switch, sops-nix decrypts them into /run/secrets (kept
# in RAM, never on disk) with the master age key. That key is never in this
# repository: it is copied from the password manager to the path below.
{ pkgs, ... }:
let
  # The repository is public, so every file under secrets/ must be sops-encrypted.
  # Built with the system (so `nh os switch` refuses a plaintext file before it is
  # committed) and by `nix flake check` (checks.secrets-encrypted). sops-nix's own
  # validation doesn't cover this: it accepts any parseable YAML.
  secretsEncrypted =
    pkgs.runCommand "secrets-encrypted"
      {
        nativeBuildInputs = [ pkgs.sops ];
        secrets = ../../secrets;
      }
      ''
        failed=0
        while IFS= read -r -d "" file; do
          # Prints {"encrypted":true} for a sops file; fails on one it can't parse.
          if [ "$(sops filestatus "$file" 2>/dev/null)" != '{"encrypted":true}' ]; then
            echo "not sops-encrypted: secrets/''${file#"$secrets"/}" >&2
            failed=1
          fi
        done < <(find "$secrets" -type f -print0)
        [ "$failed" -eq 0 ]
        touch $out
      '';
in
{
  system.checks = [ secretsEncrypted ];
  system.build.secretsEncrypted = secretsEncrypted;

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/persist/sops/age/keys.txt";

    secrets = {
      # Login password hash for `user` (modules/nixos/users.nix).
      user_password_hash.neededForUsers = true;
      # SSH key pair, linked into ~/.ssh by home/ssh.nix. The public key is here
      # too so its comment (user/host name) stays out of the public repository.
      ssh_id_ed25519 = {
        owner = "user";
        mode = "0400";
      };
      ssh_id_ed25519_pub = {
        owner = "user";
        mode = "0444";
      };
    };
  };

  # Secrets are decrypted early in boot, before ordinary filesystems are
  # mounted, so the filesystem holding the key has to be mounted in the initrd.
  fileSystems."/persist".neededForBoot = true;
}
