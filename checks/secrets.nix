# VM test of the secrets setup (modules/nixos/secrets.nix, users.nix,
# wireguard/, home/ssh.nix) with throwaway secrets made at build time, so no
# test key or test secret is stored in the repository. A second VM plays the
# VPN provider's WireGuard server, so the tunnel carries real traffic. Needs KVM.
{
  pkgs,
  sopsModule,
  homeManagerModule,
}:
let
  # An age key, a password hash, an SSH key pair and a WireGuard profile,
  # encrypted the same way as the real ones (README.md, "Secrets").
  testSecrets =
    pkgs.runCommand "test-secrets"
      {
        nativeBuildInputs = with pkgs; [
          age
          sops
          mkpasswd
          openssh
          wireguard-tools
        ];
      }
      ''
        export HOME=$TMPDIR
        mkdir -p $out/wireguard
        age-keygen -o $out/age-key.txt 2>/dev/null
        recipient=$(age-keygen -y $out/age-key.txt)
        printf %s test-password | mkpasswd -m yescrypt -s > $out/password-hash
        ssh-keygen -q -t ed25519 -N "" -C test@example -f $out/id_ed25519
        {
          printf 'user_password_hash: %s\n' "$(cat $out/password-hash)"
          printf 'ssh_id_ed25519: |\n'; sed 's/^/  /' $out/id_ed25519
          printf 'ssh_id_ed25519_pub: |\n'; sed 's/^/  /' $out/id_ed25519.pub
        } | sops encrypt --age "$recipient" --filename-override secrets.yaml /dev/stdin > $out/secrets.yaml

        # A VPN server (the `server` VM below) and a client profile for it, laid
        # out like a downloaded Proton profile.
        wg genkey > $out/server-key
        wg genkey > client-key
        wg pubkey < client-key > $out/client-pub
        printf '[Interface]\nPrivateKey = %s\nAddress = 10.2.0.2/32\nDNS = 10.2.0.1\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0\nEndpoint = 203.0.113.2:51820\n' \
          "$(cat client-key)" "$(wg pubkey < $out/server-key)" > wgtest.conf
        sops encrypt --age "$recipient" --filename-override wgtest.conf wgtest.conf > $out/wireguard/wgtest.conf
      '';
in
pkgs.testers.runNixOSTest {
  name = "secrets";

  # Stands in for a VPN provider's server: its endpoint address is not on the
  # local network, so like a real one it is reached through the default gateway.
  nodes.server = {
    networking.interfaces.eth1.ipv4.addresses = [
      {
        address = "203.0.113.2";
        prefixLength = 32;
      }
    ];
    networking.firewall.allowedUDPPorts = [ 51820 ];
    networking.wireguard.interfaces.wg0 = {
      ips = [ "10.2.0.1/24" ];
      listenPort = 51820;
      privateKeyFile = "${testSecrets}/server-key";
      # The client peer is added by the test script: its key is only known at build time.
    };
  };

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        sopsModule
        homeManagerModule
        ../modules/nixos/secrets.nix
        ../modules/nixos/wireguard
        ../modules/nixos/users.nix
      ];

      networking.networkmanager.enable = true;
      # The gateway to the "internet", where the VPN server is (see nodes.server).
      networking.defaultGateway = {
        address = "192.168.1.2";
        interface = "eth1";
      };
      # users.nix adds `user` to this group, which virtualisation.nix creates.
      users.groups.libvirtd = { };
      # Only the part of the Home Manager config under test.
      home-manager.users.user = lib.mkForce {
        imports = [ ../home/ssh.nix ];
        home.stateVersion = "26.05";
      };

      sops.defaultSopsFile = lib.mkForce "${testSecrets}/secrets.yaml";
      local.wireguardProfiles = lib.mkForce { wgtest = "${testSecrets}/wireguard/wgtest.conf"; };

      virtualisation.fileSystems."/persist" = {
        device = "tmpfs";
        fsType = "tmpfs";
        neededForBoot = true;
      };
      # Stands in for copying the key from the password manager.
      system.activationScripts = {
        testAgeKey.text = "install -D -m 600 ${testSecrets}/age-key.txt /persist/sops/age/keys.txt";
        setupSecretsForUsers.deps = [ "testAgeKey" ];
        setupSecrets.deps = [ "testAgeKey" ];
      };
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    with subtest("login password comes from the encrypted file"):
        machine.succeed('test "$(getent shadow user | cut -d: -f2)" = "$(cat ${testSecrets}/password-hash)"')

    with subtest("SSH key pair is linked into ~/.ssh, private key readable only by user"):
        machine.wait_for_unit("home-manager-user.service")
        machine.succeed("cmp /home/user/.ssh/id_ed25519 ${testSecrets}/id_ed25519")
        machine.succeed("cmp /home/user/.ssh/id_ed25519.pub ${testSecrets}/id_ed25519.pub")
        machine.succeed('test "$(stat -L -c "%U %a" /home/user/.ssh/id_ed25519)" = "user 400"')
        # ssh refuses keys with loose permissions; this loads it the same way.
        machine.succeed("su user -c 'ssh-keygen -y -f ~/.ssh/id_ed25519'")

    with subtest("WireGuard profile is loaded, private to root, and not connected"):
        machine.wait_for_unit("wireguard-profiles.service")
        machine.succeed('test "$(stat -c %a /run/NetworkManager/system-connections/sops-wireguard-wgtest.nmconnection)" = 600')
        machine.succeed('test "$(nmcli -g connection.autoconnect connection show wgtest)" = no')
        machine.succeed('test -z "$(nmcli -g GENERAL.STATE connection show wgtest)"')

    with subtest("user can turn the profile on and off; while on, all traffic goes through it"):
        server.wait_for_unit("wireguard-wg0.service")
        server.succeed("wg set wg0 peer $(cat ${testSecrets}/client-pub) allowed-ips 10.2.0.2/32")
        machine.succeed("su user -c 'nmcli connection up wgtest'")
        # Through the tunnel and past the firewall. Retried: the first packets
        # start the WireGuard handshake, which is slow without KVM.
        machine.wait_until_succeeds("ping -c1 -W2 10.2.0.1", timeout=60)
        machine.succeed("ip route get 198.51.100.1 | grep -q 'dev wgtest'")
        machine.succeed("su user -c 'nmcli connection down wgtest'")
        machine.fail("ip route get 198.51.100.1 | grep -q 'dev wgtest'")

    with subtest("changes made with nmcli --temporary are discarded when the profiles reload"):
        machine.succeed("su user -c 'nmcli connection modify --temporary wgtest ipv4.never-default yes'")
        machine.succeed('test "$(nmcli -g ipv4.never-default connection show wgtest)" = yes')
        machine.succeed('test -z "$(ls -A /etc/NetworkManager/system-connections)"')
        machine.succeed("systemctl restart wireguard-profiles.service")
        machine.succeed('test "$(nmcli -g ipv4.never-default connection show wgtest)" = no')
  '';
}
