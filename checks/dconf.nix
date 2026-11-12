# Validate Home Manager's dconf settings against the GSettings schemas they target.
{
  pkgs,
  hmLib,
  settings,
}:
let
  inherit (pkgs) lib;

  # Rendered exactly as Home Manager renders it for `dconf load` (modules/misc/dconf.nix).
  keyfile = pkgs.writeText "dconf-settings.ini" (
    lib.generators.toINI {
      mkKeyValue = key: value: "${key}=${toString (hmLib.gvariant.mkValue value)}";
    } settings
  );

  # Packages that ship the schemas these settings target.
  schemaPackages = with pkgs; [
    gsettings-desktop-schemas
    gtk3
    gtk4
    mutter
    nautilus
  ];

  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
in
pkgs.runCommand "check-dconf-settings"
  {
    nativeBuildInputs = [
      python
      pkgs.glib
      pkgs.gobject-introspection
    ];
  }
  ''
    mkdir schemas
    for dir in ${lib.concatMapStringsSep " " pkgs.glib.getSchemaPath schemaPackages}; do
      cp "$dir"/*.xml schemas/
    done
    glib-compile-schemas --strict schemas
    python3 ${./check_dconf.py} ${keyfile} schemas
    touch $out
  ''
