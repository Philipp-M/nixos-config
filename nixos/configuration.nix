# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, lib, ... }:

{
  imports = [
    # custom home-manager
    (import "${
        (builtins.fetchGit {
          url = "https://github.com/Philipp-M/home-manager/";
          ref = "personal";
          rev = "1dbd3d56c817d7f6646514a906e16c3237e4a5be";
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
  };

  # Enable audio
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;
  hardware.pulseaudio.package =
    pkgs.pulseaudio.override { jackaudioSupport = true; };

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
    python3
    elixir
    gcc10
    gdb
    meson
    cmake
    git
    git-secret
    gitAndTools.diff-so-fancy
    gnumake
    jdk
    llvmPackages.bintools
    neovim
    ccls
    omnisharp-roslyn
    nixfmt
    flatpak-builder
    rnix-lsp
    haskellPackages.ormolu # haskell formatter
    # haskell.compiler.ghc882
    carnix
    php
    yarn
    deno
    nodejs_latest
    nodePackages.node2nix
    pkg-config
    rustup
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

    # GRAPHICS
    blender
    krita
    gimp
    inkscape

    # AUDIO
    cantata
    pavucontrol
    ffmpeg
    flacon
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
    dzen2
    gnome3.file-roller
    dmenu
    wmctrl
    xorg.xev
    xorg.xmessage
    xorg.xkill
    xorg.xwininfo

    # GAMES
    lutris
    minecraft
    steam
    wineWowPackages.staging
    winetricks

    # MISC
    acpi
    powertop
    usbutils
    mprime
    cabextract
    patchelf
    qdirstat
    borgbackup
    electrum
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
