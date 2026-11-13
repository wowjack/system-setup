# modules/nixos/wireguard/nm_profile.py converts a wg-quick file the way
# NetworkManager's importer does, with autoconnect off, a stable UUID and
# exclusive DNS (only where the file has DNS servers), and fails on a file
# NetworkManager can't import.
{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
in
pkgs.runCommand "check-wireguard-profile"
  {
    nativeBuildInputs = [
      python
      pkgs.wireguard-tools
    ];
    GI_TYPELIB_PATH = "${pkgs.networkmanager}/lib/girepository-1.0";
  }
  ''
    convert() { python3 ${../modules/nixos/wireguard/nm_profile.py} "$@"; }
    printf '[Interface]\n# Key for test\nPrivateKey = %s\nAddress = 10.2.0.2/32, 2a07:b944::2:2/128\nDNS = 10.2.0.1, 2a07:b944::2:1\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = 192.0.2.1:51820\n' \
      "$(wg genkey)" "$(wg genkey | wg pubkey)" > proton1.conf

    convert proton1.conf a.nmconnection
    test "$(stat -c %a a.nmconnection)" = 600
    for line in id=proton1 interface-name=proton1 type=wireguard autoconnect=false \
        endpoint=192.0.2.1:51820 'allowed-ips=0.0.0.0/0;::/0;' address1=10.2.0.2/32 \
        address1=2a07:b944::2:2/128 'dns=10.2.0.1;' 'dns-search=~;'; do
      grep -qxF "$line" a.nmconnection || { echo "missing: $line"; cat a.nmconnection; exit 1; }
    done
    # Exclusive DNS, in both the [ipv4] and [ipv6] section.
    test "$(grep -cxF dns-priority=-50 a.nmconnection)" = 2 || { cat a.nmconnection; exit 1; }
    convert proton1.conf b.nmconnection
    cmp a.nmconnection b.nmconnection # same UUID every time

    # Without DNS servers, other connections' DNS stays in use.
    printf '[Interface]\nPrivateKey = %s\nAddress = 10.2.0.2/32\n\n[Peer]\nPublicKey = %s\nAllowedIPs = 0.0.0.0/0\nEndpoint = 192.0.2.1:51820\n' \
      "$(wg genkey)" "$(wg genkey | wg pubkey)" > nodns.conf
    convert nodns.conf d.nmconnection
    if grep -q dns-priority d.nmconnection; then cat d.nmconnection; exit 1; fi

    printf '[Interface]\nBogus = 1\n' > bad.conf
    if convert bad.conf c.nmconnection; then echo "accepted an invalid file"; exit 1; fi
    touch $out
  ''
