# WireGuard VPN profiles for NetworkManager. Each profile is a wg-quick .conf
# file (as downloaded from the VPN provider), stored sops-encrypted in
# secrets/wireguard/<name>.conf (see README.md, "Secrets").
#
# On boot and whenever a profile changes, each one is decrypted, converted by
# NetworkManager's own WireGuard importer (./nm_profile.py) and loaded as an
# in-memory NetworkManager profile. Profiles never connect on their own; turn
# them on and off with `nmcli connection up/down <name>`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  profileDir = ../../../secrets/wireguard;
  profileFiles = lib.filterAttrs (file: _: lib.hasSuffix ".conf" file) (
    if builtins.pathExists profileDir then builtins.readDir profileDir else { }
  );
  profiles = config.local.wireguardProfiles;
  nm = config.networking.networkmanager.package;
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  connectionDir = "/run/NetworkManager/system-connections";
  # Prefix of the profile files this module writes, so stale ones can be removed.
  filePrefix = "sops-wireguard-";
  secretName = name: "wireguard/${name}.conf";
in
{
  options.local.wireguardProfiles = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    default = lib.mapAttrs' (
      file: _: lib.nameValuePair (lib.removeSuffix ".conf" file) (profileDir + "/${file}")
    ) profileFiles;
    defaultText = lib.literalMD "every `<name>.conf` file in `secrets/wireguard/`";
    description = ''
      sops-encrypted wg-quick files, by profile name. The name is used as the
      NetworkManager connection name and as the network interface name.
    '';
  };

  config = lib.mkIf (profiles != { }) {
    assertions = map (name: {
      # Interface names are limited to 15 characters.
      assertion = builtins.match "[a-z0-9-]{1,15}" name != null;
      message = "WireGuard profile name '${name}' must be 1-15 characters of a-z, 0-9 and '-'.";
    }) (lib.attrNames profiles);

    sops.secrets = lib.mapAttrs' (
      name: file:
      lib.nameValuePair (secretName name) {
        sopsFile = file;
        format = "binary";
        restartUnits = [ "wireguard-profiles.service" ];
      }
    ) profiles;

    systemd.services.wireguard-profiles = {
      description = "Load WireGuard profiles into NetworkManager";
      after = [ "NetworkManager.service" ];
      wants = [ "NetworkManager.service" ];
      wantedBy = [ "multi-user.target" ];
      environment.GI_TYPELIB_PATH = "${nm}/lib/girepository-1.0";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      script = ''
        mkdir -p ${connectionDir}
        rm -f ${connectionDir}/${filePrefix}*.nmconnection
      ''
      + lib.concatMapStrings (name: ''
        ${python.interpreter} ${./nm_profile.py} \
          ${config.sops.secrets.${secretName name}.path} \
          ${connectionDir}/${filePrefix}${name}.nmconnection
      '') (lib.attrNames profiles)
      + ''
        ${nm}/bin/nmcli connection reload
      '';
    };
  };
}
