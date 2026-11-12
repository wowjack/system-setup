# Secrets, stored sops-encrypted in secrets/ (see README.md, "Secrets").
# On boot and on every switch, sops-nix decrypts them into /run/secrets (kept
# in RAM, never on disk) with the master age key. That key is never in this
# repository: it is copied from the password manager to the path below.
{
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
