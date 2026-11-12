"""Turn a wg-quick .conf file into a NetworkManager connection profile.

Usage: nm_profile.py <name>.conf <output.nmconnection>

The conversion is done by NetworkManager's own importer (the same one
`nmcli connection import type wireguard` uses), so the profile behaves exactly
like an imported one. On top of that, the profile never connects on its own,
and its UUID is derived from <name> so it stays the same across rebuilds.
"""

import os
import sys
import uuid

import gi

gi.require_version("NM", "1.0")
from gi.repository import NM  # noqa: E402

# Fixed namespace for the profile UUIDs (uuid5 of a name in it).
UUID_NAMESPACE = uuid.UUID("2f4c1d36-5b0e-4f53-9a7e-3d8c6a1b9e20")


def convert(conf_path: str) -> bytes:
    # The importer requires the file name to be "<interface name>.conf" and uses
    # that name as both the connection name and the interface name.
    connection = NM.conn_wireguard_import(conf_path)
    name = connection.get_id()
    settings = connection.get_setting_connection()
    settings.set_property(NM.SETTING_CONNECTION_AUTOCONNECT, False)
    profile_uuid = uuid.uuid5(UUID_NAMESPACE, name)
    settings.set_property(NM.SETTING_CONNECTION_UUID, str(profile_uuid))
    connection.normalize()
    keyfile = NM.keyfile_write(connection, NM.KeyfileHandlerFlags.NONE, None)
    data, _length = keyfile.to_data()
    return data.encode()


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <name>.conf <output.nmconnection>")
    conf_path, out_path = sys.argv[1:]
    data = convert(conf_path)
    # NetworkManager only loads profiles that are private to root.
    fd = os.open(out_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as out:
        out.write(data)


if __name__ == "__main__":
    main()
