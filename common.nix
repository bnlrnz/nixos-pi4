{
  lib,
  pkgs,
  ...
}:
let
  python_with_packages = (pkgs.python311.withPackages (p:
    with p; [
      pkgs.python311Packages.rpi-gpio
      pkgs.python311Packages.gpiozero
      pkgs.python311Packages.pyserial
    ]));
in
{
  nixpkgs.hostPlatform.system = "aarch64-linux";
  nixpkgs.buildPlatform.system = "x86_64-linux";
  # ! Need a trusted user for deploy-rs.
  nix.settings.trusted-users = ["@wheel"];
  system.stateVersion = "23.11";

  # don't build the NixOS docs locally
  documentation.nixos.enable = false;

  services.zram-generator = {
    enable = true;
    settings.zram0 = {
      compression-algorithm = "zstd";
      zram-size = "ram * 2";
    };
  };

  # Keep this to make sure wifi works
  hardware.enableRedistributableFirmware = lib.mkForce false;
  hardware.firmware = [pkgs.raspberrypiWirelessFirmware];

  users.groups.gpio = {};

  # services.udev.extraRules = ''
  #   SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio",MODE="0660"
  #   SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", RUN+="${pkgs.bash}/bin/bash -c 'chown root:gpio /sys/class/gpio/export /sys/class/gpio/unexport ; chmod 220 /sys/class/gpio/export /sys/class/gpio/unexport'"
  #   SUBSYSTEM=="gpio", KERNEL=="gpio*", ACTION=="add",RUN+="${pkgs.bash}/bin/bash -c 'chown root:gpio /sys%p/active_low /sys%p/direction /sys%p/edge /sys%p/value ; chmod 660 /sys%p/active_low /sys%p/direction /sys%p/edge /sys%p/value'"
  # '';

  # https://raspberrypi.stackexchange.com/questions/40105/access-gpio-pins-without-root-no-access-to-dev-mem-try-running-as-root
  services.udev.extraRules = ''
    KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/chgrp -R gpio /sys/class/gpio && ${pkgs.coreutils}/bin/chmod -R g=u /sys/class/gpio'"
    SUBSYSTEM=="gpio", ACTION=="add", PROGRAM="${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/chgrp -R gpio /sys%p && ${pkgs.coreutils}/bin/chmod -R g=u /sys%p'"
  '';

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
      timeout = 2;
    };

    # https://artemis.sh/2023/06/06/cross-compile-nixos-for-great-good.html
    # for deploy-rs
    # binfmt.emulatedSystems = [ "x86_64-linux" ];

    # Avoids warning: mdadm: Neither MAILADDR nor PROGRAM has been set.
    # This will cause the `mdmon` service to crash.
    # See: https://github.com/NixOS/nixpkgs/issues/254807
    swraid.enable = lib.mkForce false;
  };

  networking = {
    hostName = "nixpi";
    useDHCP = false;
    interfaces = {
      eth0.ipv4.addresses = [
        {
          address = "10.10.10.74";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      interface = "eth0";
      address = "10.10.10.1";
    };
    nameservers = ["1.1.1.1" "8.8.8.8"];
    firewall = {
        enable = true;
        allowedUDPPorts = [ 
          53 # DNS/adguard 
          51820 # VPN/wireguard
        ];
    };
  };

  # adguard home setup
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    allowDHCP = true;
  };

  # services.dnsmasq.enable = true;

  # Enable OpenSSH out of the box.
  services.sshd.enable = true;

  # NTP time sync.
  services.timesyncd.enable = true;

  # ! Change the following configuration
  users.users.pi = {
    isNormalUser = true;
    home = "/home/pi";
    description = "Lord Pi McPison";
    extraGroups = ["wheel" "networkmanager" "gpio" "audio"];
    # ! Be sure to put your own public key here
    openssh = {
      authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHayUPsznsg3sdyPbcVrPOtbjX+Fgw6Jga6PAjRDvkuc bnlrnz@gmail.com"
      ];
    };
  };

  # make fish default shell
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # ! Be sure to change the autologinUser.
  services.getty.autologinUser = "pi";

  # enable adguard home


  environment.systemPackages = with pkgs; [
    libraspberrypi
    raspberrypi-eeprom
    htop
    vim
    neovim
    ripgrep
    btop
    usbutils
    tmux
    git
    fish
    lsof
    bat
    eza
    dig
    tree
    bintools
    file
    ethtool
    nettools
    minicom
  ];
}
