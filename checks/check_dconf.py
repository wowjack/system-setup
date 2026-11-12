"""Validate a dconf keyfile against GSettings schemas.

dconf itself is untyped: `dconf load` (which Home Manager uses) stores whatever
GVariant each value parses to, and GSettings silently ignores a stored value
whose type differs from the schema's. A typo'd key is silently ignored too.
This script fails if any key in the keyfile:

- is under a path that no schema in SCHEMA_DIR owns,
- is not a key of that schema,
- parses (without a type hint, as `dconf load` does) to a different GVariant
  type than the schema declares, or
- is outside the schema's allowed range or choices.

Usage: python3 check_dconf.py KEYFILE SCHEMA_DIR
SCHEMA_DIR must contain a compiled gschemas.compiled.
"""

import configparser
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402


def schemas_by_path(schema_dir: str) -> dict[str, Gio.SettingsSchema]:
    source = Gio.SettingsSchemaSource.new_from_directory(schema_dir, None, False)
    non_relocatable, _relocatable = source.list_schemas(False)
    by_path = {}
    for schema_id in non_relocatable:
        schema = source.lookup(schema_id, False)
        by_path[schema.get_path()] = schema
    return by_path


def check(keyfile: str, schema_dir: str) -> list[str]:
    by_path = schemas_by_path(schema_dir)

    parser = configparser.ConfigParser(interpolation=None, delimiters=("=",))
    parser.optionxform = str  # dconf keys are case-sensitive
    with open(keyfile, encoding="utf-8") as f:
        parser.read_file(f)

    errors = []
    for section in parser.sections():
        path = f"/{section}/"
        schema = by_path.get(path)
        if schema is None:
            errors.append(f"{path}: no installed schema owns this path")
            continue
        for key, text in parser.items(section):
            where = f"{path}{key} ({schema.get_id()})"
            if not schema.has_key(key):
                errors.append(f"{where}: no such key")
                continue
            schema_key = schema.get_key(key)
            expected = schema_key.get_value_type().dup_string()
            try:
                value = GLib.Variant.parse(None, text, None, None)
            except GLib.Error as e:
                errors.append(f"{where}: cannot parse {text!r}: {e.message}")
                continue
            actual = value.get_type_string()
            if actual != expected:
                errors.append(
                    f"{where}: {text!r} has type '{actual}' "
                    f"but the schema expects '{expected}'"
                )
            elif not schema_key.range_check(value):
                errors.append(f"{where}: {text!r} is outside the allowed range")
    return errors


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    keyfile, schema_dir = sys.argv[1:]
    errors = check(keyfile, schema_dir)
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    if errors:
        return 1
    print(f"ok: every key in {keyfile} matches its schema")
    return 0


if __name__ == "__main__":
    sys.exit(main())
