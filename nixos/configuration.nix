# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, ... }:

{
  nixpkgs.config.allowUnfree = true;
  imports = [
    # custom home-manager
    (import "${
        (builtins.fetchTarball {
          url =
            "https://github.com/Philipp-M/home-manager/archive/7f8c5a99c4dcb1ca9475ea22101e8c4fce1d8bb4.tar.gz";
          sha256 = "1ickv182mnv8lirccga67f3g6w6dwfd4jqpsi25wcaz5fvsiwkba";
        })
      }/nixos")
  ];

  # NUR
  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/NUR/archive/54d26b858b073adca6425385ea7bb085f2676bd0.tar.gz";
      sha256 = "0d7xxrb21xim937vgb0i0nxj1bhb4k2r6kqr860alavfqf5x3ivq";
    }) { inherit pkgs; };
  };

  # Use the systemd-boot EFI boot loader.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "20.09";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;

  networking.networkmanager.enable = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  console.keyMap = "colemak";
  console.font = "Lat2-Terminus16";

  # Set your time zone.
  time.timeZone = "Europe/Vienna";

  # Enable 32-bit dri support for steam
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

  # Enable audio
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # List of systemwide services

  virtualisation.docker.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Enable the X11 windowing system.

  services.autorandr.enable = true;

  services.xserver = {
    enable = true;
    autoRepeatInterval = 15;
    autoRepeatDelay = 300;
    xkbVariant = "colemak";
    # Enable touchpad support.
    libinput.enable = true;
    # Use session defined in home.nix
    windowManager = {
      session = [{
        name = "xmonad";
        bgSupport = true;
        start = ''
          ${pkgs.runtimeShell} $HOME/.xsession &
          waitPID=$!
        '';
      }];
    };
    displayManager.defaultSession = "none+xmonad";
  };

  xdg.portal.enable = true;
  services.flatpak.enable = true;

  # allow no password for sudo (dangerous...)
  security.sudo.enable = true;
  security.sudo.extraConfig = ''
    %wheel ALL=(ALL) NOPASSWD: ALL
  '';

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.philm = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "audio"
      "networkmanager"
      "systemd-journal"
      "adbusers"
      "video"
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
    ];
  };

  ### manage most stuff via home-manager

  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.users.philm = (import ./home.nix);

  # All system wide packages

  programs.fish.enable = true;

  programs.adb.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Development
    clang_10
    cmake
    gcc
    git
    gitAndTools.diff-so-fancy
    gnumake
    jdk
    llvmPackages.bintools
    neovim
    nixfmt
    nodejs_latest
    pkg-config
    python3
    rcm # manage dotfiles
    rustup
    vscode

    # Document tools
    pandoc
    libreoffice
    texlive.combined.scheme-full
    zathura

    # Terminal stuff
    # alacritty not used because rendering issues with powerline symbols, no ligatures and issues with vim transparency
    kitty
    fasd
    file
    fish-foreign-env
    htop
    killall
    lm_sensors
    lsd
    lshw
    pciutils
    ripgrep
    wget

    # Graphical Editors
    blender
    krita

    # Communication
    discord
    tdesktop

    # Web
    chromium

    # Desktop Environment
    dmenu

    # Games
    minecraft
    steam

    # Misc
    scrot
    feh # to view images in terminal
    fira-code
    mpv
    source-code-pro
    transmission-gtk
    unityhub
    xclip
    nvtop
  ];

  nixpkgs.overlays = [
    # add fancy dual kawase blur to picom
    (self: super: {
      picom = super.picom.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          owner = "tryone144";
          repo = "picom";
          rev = "209d9b6558e430033d7ccd91e8657aea1670d1c0";
          sha256 = "06j9vd9gbc1fvrmhvwbmqq18lyfwsvyy0gwgpqwgm8gcfplwyhfl";
        };
      });
    })
  ];
}
