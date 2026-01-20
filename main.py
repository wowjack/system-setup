from util import get_submodules_attributes
import installers
[install() for install in get_submodules_attributes(installers, "install")]
[customize() for customize in get_submodules_attributes(installers, "customize")]


print("\nFinishing checklist:")

print("Add ssh pub key to github:")
print("\tcat ~/.ssh/id_ed25519.pub")