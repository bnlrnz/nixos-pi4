# Building a NixOS SD image for a Raspberry Pi 4

0. Host setup in `configuration.nix`

```nix
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  nix.settings.extra-platforms = config.boot.binfmt.emulatedSystems;
```

1. Update `common.nix`

In particular, don't forget:
- to configure your network
- to change the admin user able to connect through ssh
- add hosts public ssh key to connect without password

2. Build the image

```sh
nix build -L .#nixosConfigurations.pi4.config.system.build.sdImage
```

3. Copy the image in your sd card

```sh
DEVICE=/dev/sdd # Whatever your sd card reader or usb device is
sudo dd if=result/sd-image/pi.img of=$DEVICE bs=1M conv=fsync status=progress
```

4. Boot your Pi

5. From another machine, rebuild the system:

For Pi 4:

```sh
nix --extra-experimental-features nix-command --extra-experimental-features flakes run --system aarch64-linux github:serokell/deploy-rs .#pi4 -- --ssh-user pi --hostname 10.10.10.74
```

## Notes

- Various features are much better supported on the Pi 4 than on the Zero 2 W because the Pi 4 has a `nixos-hardware` profile.
  - Note that `nixos-rebuild --target-host` would work instead of using `deploy-rs`. but as `nixos-rebuild` is not available on Darwin, I'm using `deploy-rs` that works both on NixOS and Darwin.
- the `sdImage.extraFirmwareConfig` option is not ideal as it cannot update `config.txt` after it is created in the sd image.

## See also
- [this issue](https://github.com/NixOS/nixpkgs/issues/216886)
- [this gist](https://gist.github.com/plmercereau/0c8e6ed376dc77617a7231af319e3d29)

