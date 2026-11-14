# VM test of hosts/desktop/disko.nix, using disko's test harness: formats a
# virtual disk with the layout (and destroys/recreates it to check that works),
# boots a minimal system from it, then checks the mounts, mount options, the
# snapshots subvolume and the swapfile. Needs KVM.
{ pkgs, diskoLib }:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "disko-layout";
  # The harness replaces the device with a 4 GB virtual disk, too small for the
  # real 8 GB swapfile, so only the swapfile is shrunk for the test.
  disko-config =
    pkgs.lib.recursiveUpdate (import ../hosts/desktop/disko.nix { device = "/dev/vdb"; })
      {
        disko.devices.disk.main.content.partitions.root.content.subvolumes."/swap".swap.swapfile.size =
          "1G";
      };
  # The harness registers the booted VM with `driver.machines.append(...)`, but
  # the nixpkgs test driver's `machines` is a property returning a fresh list, so
  # the driver never stops that VM and the build hangs after the test passes.
  # Stop it here, whether or not the assertions pass.
  extraTestScript = ''
    try:
        for m in ["/", "/boot", "/home", "/nix", "/persist", "/var/log", "/swap"]:
            machine.succeed(f"mountpoint {m}")
        for m in ["/", "/home", "/nix", "/persist", "/var/log"]:
            machine.succeed(f"findmnt -no OPTIONS {m} | grep -q compress=zstd")
            machine.succeed(f"findmnt -no OPTIONS {m} | grep -q noatime")
        machine.succeed("btrfs subvolume show /home/.snapshots")
        machine.succeed("swapon --show=NAME --noheadings | grep -qx /swap/swapfile")
    finally:
        machine.release()
  '';
}
