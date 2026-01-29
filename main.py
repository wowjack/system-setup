from util import get_submodules_attributes
import installers
[install() for install in get_submodules_attributes(installers, "install")]
[customize() for customize in get_submodules_attributes(installers, "customize")]


print("\nFinishing checklist:")

print("TODO: Add ssh pub key to github:")
print("\tcat ~/.ssh/id_ed25519.pub")

print("TODO: clone obsidian_notes and select obsidian_notes/notes as vault.")

print("TODO: download and install protonvpn wireguard connection")
