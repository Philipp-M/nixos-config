# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, lib, ... }:

{
  imports = [
    # pinning nixpkgs
    # (import "${
    #     (builtins.fetchTarball {
    #       url =
    #         "https://github.com/NixOS/nixpkgs/archive/8855c3a1c728a16b4a9e5e4071d7fc63ef63973a.tar.gz";
    #       sha256 = "07pfwr8cimd9cmiqxhwzaz5l4i0vdzkmjh742kylpqc1mzr2xx26";
    #     })
    #   }/nixos")
    # (import ../../desktop-environment/nixpkgs/nixos/default.nix)
    # import (builtins.fetchTarball {
    #   # Descriptive name to make the store path easier to identify
    #   name = "nixos-unstable-2020-06-17";
    #   # Commit hash for nixos-unstable as of 2018-09-12
    #   url = "https://github.com/nixos/nixpkgs/archive/ec13b27348f98e74e0fbb1ab5e5723ec3127b7a8.tar.gz";
    #   # Hash obtained using `nix-prefetch-url --unpack <url>`
    #   sha256 = "0c7lzhyl2fhfghdn6f7nrx69fk9v4pdaljzrkykxbdc18vza5i7w";
    # }) {}
    # custom home-manager
    (import "${
        (builtins.fetchGit {
          url = "https://github.com/Philipp-M/home-manager/";
          ref = "personal";
          rev = "b25e767899063b3f109680cc64dacd73228e796a";
        })
      }/nixos")
  ];

  nixpkgs.config.allowUnfree = true;
  nix.autoOptimiseStore = true;

  # Use the systemd-boot EFI boot loader.
  boot.supportedFilesystems = [ "ecryptfs" ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  boot.tmpOnTmpfs = true;

  system.stateVersion = "20.09";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IE.UTF-8";

  console.keyMap = "colemak";
  console.font = "Lat2-Terminus16";

  # Set your time zone.
  time.timeZone = "Europe/Vienna";

  hardware.opengl = {
    enable = true;
    # Enable 32-bit dri support for steam
    driSupport32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    setLdLibraryPath = true;
  };

  # Enable audio
  # Not strictly required but pipewire will use rtkit if it is present
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    # Compatibility shims, adjust according to your needs
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  # debugging of local webservices from external devices like smartphones
  networking.firewall.allowedTCPPorts = [ 80 443 8080 8081 8000 8001 3000 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8080 8081 8000 8001 3000 ];

  networking.hosts = { "127.0.0.1" = [ "work" "www" "spa-test" ]; };

  # nginx is sandboxed and doesn't allow reading from /home
  systemd.services.nginx.serviceConfig = {
    ProtectSystem = lib.mkForce false;
    ProtectHome = lib.mkForce false;
  };
  services.nginx = {
    enable = true;
    virtualHosts = {
      "work" = {
        root = "/home/philm/dev/work/";
        locations."/".extraConfig = "autoindex on;";
      };
      "www" = {
        default = true;
        root = "/home/philm/dev/personal/www/";
        locations."/".extraConfig = "autoindex on;";
      };
      "spa-test" =
        { # simple test for SPAs, that need to use / with normal history routing
          root = "/home/philm/dev/personal/www/spa-test";
          locations."/".extraConfig = ''
            try_files $uri $uri/ /index.html;
            autoindex on;
          '';
        };
    };
  };

  # List of systemwide services

  virtualisation.docker.enable = true;
  virtualisation.virtualbox.host = {
    enable = true;
    enableHardening = false;
    enableExtensionPack = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

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
      "power"
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
    ];
  };
  users.extraGroups.vboxusers.members = [ "philm" ];

  ### manage most stuff via home-manager

  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.users.philm = (import ./home);

  # All system wide packages

  programs.fish.enable = true;

  programs.adb.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryFlavor = "curses";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # DEVELOPMENT
    ## compilers and dev environment
    # clang_10 # conflicts with gcc
    python38Full
    python38Packages.pip
    python38Packages.setuptools
    elixir
    gcc10
    gdb
    meson
    cmake
    dart
    git
    git-secret
    gitAndTools.diff-so-fancy
    gnumake
    jdk
    llvmPackages.bintools
    neovim
    android-studio
    droidcam
    flatpak-builder
    # haskell.compiler.ghc882
    carnix
    php
    yarn
    deno
    nodejs_latest
    nodePackages.node2nix
    pkg-config
    rustup
    wasm-pack
    vscode
    glslang
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
    fzf
    file
    htop
    killall
    lm_sensors
    lsd
    lshw
    pciutils
    ripgrep
    fd
    tokei
    gitAndTools.gh
    du-dust
    bat
    zoxide
    bandwhich
    # grex, TODO implement support
    hyperfine
    tealdeer
    procs
    wget
    unzip
    b3sum
    jq
    youtube-dl
    zip
    unrar
    p7zip
    brotli

    # GRAPHICS
    # blender # flatpak version is used due to Optix support
    krita
    gimp
    inkscape

    # AUDIO
    cantata
    pavucontrol
    ffmpeg-full
    flacon
    bitwig-studio

    # COMMUNICATION
    thunderbird
    signal-desktop
    element-desktop
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
    dzen2
    gnome3.file-roller
    dmenu
    wmctrl
    xorg.xev
    xorg.xinit
    xorg.xmessage
    xorg.xkill
    xorg.xwininfo
    deadd-notification-center

    # GAMES
    lutris
    minecraft
    steam
    wineWowPackages.staging
    winetricks

    # MISC
    sanoid
    gsettings-desktop-schemas
    appimage-run
    ntfs3g
    woeusb
    ipfs
    acpi
    freecad
    appimage-run
    openvpn
    powertop
    usbutils
    cabextract
    patchelf
    qdirstat
    borgbackup
    electrum
    monero-gui
    ecryptfs
    ecryptfs-helper
    keepassxc
    memtester
    docker-compose
    # arion
    filezilla
    scrot
    feh # to view images in terminal
    imagemagick
    # unityhub
    fira-code
    mpv
    source-code-pro
    transmission-gtk
    deluge
    xclip
    nvtop
    adb-sync
    tree-sitter
  ];

  fonts.fonts = with pkgs; [ nerdfonts google-fonts ];

  nixpkgs.overlays = [
    # add fancy dual kawase blur to picom
    (self: super: {
      picom = super.picom.overrideAttrs (old: {
        src = builtins.fetchGit {
          url = "https://github.com/Philipp-M/picom/";
          ref = "customizable-rounded-corners";
          rev = "2b1d9faf0bf5dfad04a5acf02b34a432368de805";
        };
      });

      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (old: {
        version = "0.5-dev";
        src = builtins.fetchGit {
          url = "https://github.com/neovim/neovim/";
          ref = "master";
          rev = "c50b737d6f953e1c4240c2e24693ce49932cdaf6";
        };

        buildInputs = old.buildInputs ++ ([ pkgs.tree-sitter ]);
      });

      alacritty = super.callPackage ./alacritty.nix { };

      haskellPackages = with self.haskell.lib;
        super.haskellPackages.extend
        (hself: hsuper: { taffybar = markUnbroken hsuper.taffybar; });
    })
  ];
}
