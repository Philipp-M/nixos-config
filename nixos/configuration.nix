# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;
  imports = [
    # custom home-manager
    (import "${
        (builtins.fetchGit {
          url = "https://github.com/Philipp-M/home-manager/";
          ref = "personal";
          rev = "a43cb388fdb502722a631db1c95336bfaad85da3";
        })
      }/nixos")
  ];

  # NUR and other custom packages
  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchGit {
      url = "https://github.com/nix-community/NUR/";
      ref = "master";
      rev = "5e6c5deca9fd7ef8c2151ec9b2c55c7fd3fa380f";
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
  hardware.pulseaudio.package =
    pkgs.pulseaudio.override { jackaudioSupport = true; };

  # debugging of local webservices from external devices like smartphones
  networking.firewall.allowedTCPPorts = [ 80 443 8080 8081 8000 8001 3000 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8080 8081 8000 8001 3000 ];

  networking.hosts = { "127.0.0.1" = [ "work" "www" "spa-test" ]; };

  # nginx is sandboxed and doesn't allow reading of /home
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
      "power"
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
    # clang_10 # conflicts with clang
    python3
    elixir
    gcc10
    meson
    cmake
    git
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
    haskell.compiler.ghc882
    carnix
    yarn
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

      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (old: rec {
        version = "0.5-dev";
        src = builtins.fetchGit {
          url = "https://github.com/neovim/neovim/";
          ref = "master";
          rev = "c5ceefca793b8a78cc22a553b243d66042776d5f";
        };
      });

      alacritty = super.callPackage ./alacritty.nix { };

      haskellPackages = let
        gi-cairo-render-src = self.fetchFromGitHub {
          owner = "cohomology";
          repo = "gi-cairo-render";
          rev = "051de28ff092e0be0dc28612c6acb715a8bca846";
          sha256 = "1v9kdycc91hh5s41n2i1dw2x6lxp9s1lnnb3qj6vy107qv8i4p6s";
        };
      in with self.haskell.lib;
      super.haskellPackages.extend (hself: hsuper: {
        gi-cairo-render = markUnbroken (overrideCabal (hsuper.gi-cairo-render)
          (drv: {
            src = gi-cairo-render-src;
            editedCabalFile = null;
            postUnpack = ''
              mv source all
              mv all/gi-cairo-render source
            '';
          }));
        gi-cairo-connector = markUnbroken
          (overrideCabal (hsuper.gi-cairo-connector) (drv: {
            src = gi-cairo-render-src;
            editedCabalFile = null;
            postUnpack = ''
              mv source all
              mv all/gi-cairo-connector source
            '';
          }));
        gi-dbusmenu = markUnbroken (hself.gi-dbusmenu_0_4_8);
        gi-dbusmenugtk3 = markUnbroken (hself.gi-dbusmenugtk3_0_4_9);
        gi-gdk = hself.gi-gdk_3_0_23;
        gi-gdkx11 = markUnbroken (overrideSrc hsuper.gi-gdkx11 {
          src = self.fetchurl {
            url =
              "https://hackage.haskell.org/package/gi-gdkx11-3.0.10/gi-gdkx11-3.0.10.tar.gz";
            sha256 = "0kfn4l5jqhllz514zw5cxf7181ybb5c11r680nwhr99b97yy0q9f";
          };
          version = "3.0.10";
        });
        gi-gtk-hs = markUnbroken (hself.gi-gtk-hs_0_3_9);
        gi-xlib = markUnbroken (hself.gi-xlib_2_0_9);
        gtk-sni-tray = markUnbroken (hsuper.gtk-sni-tray);
        gtk-strut = markUnbroken (hsuper.gtk-strut);
        taffybar = markUnbroken (appendPatch hsuper.taffybar (self.fetchpatch {
          url =
            "https://github.com/taffybar/taffybar/pull/494/commits/a7443324a549617f04d49c6dfeaf53f945dc2b98.patch";
          sha256 = "0prskimfpapgncwc8si51lf0zxkkdghn33y3ysjky9a82dsbhcqi";
        }));
      });
    })
  ];
}
