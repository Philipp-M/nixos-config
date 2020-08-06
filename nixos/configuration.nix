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
            "https://github.com/Philipp-M/home-manager/archive/ff514feb1edaa5b6c04db5e5a4e4a72058285eff.tar.gz";
          sha256 = "1wva4h440xxkd2rg2nsphnjxrlhxyyp3ygw1ffrn0rxs46k3gny7";
        })
      }/nixos")
  ];

  # NUR and other custom packages
  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/NUR/archive/5f70ea761d3a5d2eda6f2034f711f21c339a9931.tar.gz";
      sha256 = "0p7fw3s2xwzgcxbk6qykv6r6rx730vlkzal22fyr7hc01ajc730a";
    }) { inherit pkgs; };

    all-hies = import (builtins.fetchTarball {
      url =
        "https://github.com/Infinisil/all-hies/archive/4b6aab017cdf96a90641dc287437685675d598da.tar.gz";
      sha256 = "0ap12mbzk97zmxk42fk8vqacyvpxk29r2wrnjqpx4m2w9g7gfdya";
    }) { inherit pkgs; };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  boot.tmpOnTmpfs = true;

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

  hardware.opengl = {
    enable = true;
    # Enable 32-bit dri support for steam
    driSupport32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  };

  # Enable audio
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # debugging of local webservices from external devices like smartphones
  networking.firewall.allowedTCPPorts = [ 80 443 8080 8081 8000 8001 3000 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8080 8081 8000 8001 3000 ];

  networking.hosts = { "127.0.0.1" = [ "work" "www" "spa-test" ]; };

  services.nginx.enable = true;
  services.nginx.virtualHosts."work" = {
    root = "/home/philm/dev/work/";
    locations."/".extraConfig = "autoindex on;";
  };
  services.nginx.virtualHosts."www" = {
    root = "/home/philm/dev/personal/www/";
    locations."/".extraConfig = "autoindex on;";
  };
  services.nginx.virtualHosts."spa-test" =
    { # simple test for SPAs, that need to use / with normal history routing
      root = "/home/philm/dev/personal/www/spa-test";
      locations."/".extraConfig = "autoindex on;";
    };

  # List of systemwide services

  virtualisation.docker.enable = true;
  virtualisation.virtualbox.host = {
    enable = true;
    enableHardening = false;
    enableExtensionPack = true;
  };

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
    displayManager = {
      defaultSession = "none+xmonad";
      # this prevents accidentally turned on caps lock in the login manager (as it is remapped in the xmonad session to escape)
      sessionCommands = "${pkgs.xorg.xmodmap}/bin/xmodmap -e 'clear Lock'";
    };
  };

  # gtk themes (home-manager more specifically) seem to have problems without it
  services.dbus.packages = [ pkgs.gnome3.dconf ];

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
  users.extraGroups.vboxusers.members = [ "philm" ];

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
    # DEVELOPMENT
    ## compilers and dev environment
    clang_10
    python3
    elixir
    # gcc # conflicts with clang, only used in nix-shells anyway
    meson
    cmake
    git
    gitAndTools.diff-so-fancy
    gnumake
    jdk
    llvmPackages.bintools
    neovim
    ccls
    nixfmt
    flatpak-builder
    rnix-lsp
    haskellPackages.ormolu # haskell formatter
    haskell.compiler.ghc882
    (all-hies.selection { selector = p: { inherit (p) ghc882; }; })
    carnix
    nodejs_latest
    nodePackages.node2nix
    pkg-config
    rustup
    vscode
    vulkan-tools
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    cudatoolkit
    steam-run
    rcm # manage dotfiles

    # OFFICE/DOCUMENTING
    pandoc
    libreoffice
    texlive.combined.scheme-full
    zathura

    # TERMINAL/CLI
    alacritty
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
    fd
    tokei
    du-dust
    bat
    wget
    unzip
    youtube-dl
    zip

    # GRAPHICS
    blender
    krita
    gimp
    inkscape

    # AUDIO
    cantata
    bitwig-studio

    # COMMUNICATION
    discord
    v4l-utils
    zoom-us
    skype
    tdesktop

    # WEB
    chromium
    google-chrome
    firefox
    torbrowser

    # XORG/DESKTOP ENVIRONMENT
    awf
    dolphin
    dmenu
    nerdfonts
    wmctrl
    xorg.xev
    xorg.xmessage
    xorg.xkill
    xorg.xwininfo

    # GAMES
    lutris
    minecraft
    steam

    # MISC
    mprime
    patchelf
    qdirstat
    ecryptfs
    ecryptfs-helper
    keepassxc
    memtester
    docker-compose
    arion
    filezilla
    scrot
    feh # to view images in terminal
    imagemagick
    fira-code
    mpv
    source-code-pro
    transmission-gtk
    xclip
    nvtop
    adb-sync
  ];

  nixpkgs.overlays = [
    # add fancy dual kawase blur to picom
    (self: super: {
      picom = super.picom.overrideAttrs (old: {
        src = builtins.fetchTarball {
          url =
            "https://github.com/tryone144/picom/archive/209d9b6558e430033d7ccd91e8657aea1670d1c0.tar.gz";
          sha256 = "06j9vd9gbc1fvrmhvwbmqq18lyfwsvyy0gwgpqwgm8gcfplwyhfl";
        };
      });
    })
  ];
}
