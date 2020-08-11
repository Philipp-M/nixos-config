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
  hardware.pulseaudio.package =
    pkgs.pulseaudio.override { jackaudioSupport = true; };

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
            "https://github.com/ibhagwan/picom/archive/82ecc90b51fa2489d26ef3f08abe1f06efcb53d8.tar.gz";
          sha256 = "0pk1711kd6qqjhghrc73ldjl0m82p53yiiz5acyxvaw55hvm558h";
        };
      });

      neovim-unwrapped = super.neovim-unwrapped.overrideAttrs (old: rec {
        version = "0.5-dev";
        src = builtins.fetchTarball {
          url =
            "https://github.com/neovim/neovim/archive/94b7ff730a1914c14f347f5dc75175dc34a4b3f5.tar.gz";
          sha256 = "15fpihn2xbdzp4nb1sgni0wyr94q89y45jaxfmzh6vjbx8f76m0w";
        };
      });

      haskellPackages = with self.haskell.lib;
        super.haskellPackages.extend (hself: hsuper: {
          gi-atk = hself.gi-atk_2_0_22;
          gi-cairo = hself.gi-cairo_1_0_24;
          gi-cairo-render = overrideCabal (hsuper.gi-cairo-render) (drv: {
            src = self.fetchFromGitHub {
              owner = "thestr4ng3r";
              repo = "gi-cairo-render";
              rev = "8727c43cdf91aeedffc9cb4c5575f56660a86399";
              sha256 = "16kqh2ck0dad1l4m6q9xs5jqj9q0vgpqrzb2dc90jk8xwslmmhxd";
            };
            editedCabalFile = null;
            postUnpack = ''
              mv source all
              mv all/gi-cairo-render source
            '';
          });
          gi-dbusmenu = hself.gi-dbusmenu_0_4_8;
          gi-dbusmenugtk3 = hself.gi-dbusmenugtk3_0_4_9;
          gi-gdk = overrideSrc hsuper.gi-gdk {
            src = self.fetchurl {
              url =
                "https://hackage.haskell.org/package/gi-gdk-3.0.23/gi-gdk-3.0.23.tar.gz";
              sha256 = "18v3kb6kmryymmrz0d88nf25priwyh3yzh7raghc5ph2rv7n4w8m";
            };
            version = "3.0.23";
          };
          gi-gdkpixbuf = hself.gi-gdkpixbuf_2_0_24;
          gi-gdkx11 = overrideSrc hsuper.gi-gdkx11 {
            src = self.fetchurl {
              url =
                "https://hackage.haskell.org/package/gi-gdkx11-3.0.10/gi-gdkx11-3.0.10.tar.gz";
              sha256 = "0kfn4l5jqhllz514zw5cxf7181ybb5c11r680nwhr99b97yy0q9f";
            };
            version = "3.0.10";
          };
          gi-gio = hself.gi-gio_2_0_27;
          gi-glib = hself.gi-glib_2_0_24;
          gi-gobject = hself.gi-gobject_2_0_24;
          gi-gtk = overrideSrc hsuper.gi-gtk {
            src = self.fetchurl {
              url =
                "https://hackage.haskell.org/package/gi-gtk-3.0.36/gi-gtk-3.0.36.tar.gz";
              sha256 = "0bzb3xrax5k5r5fd6vv4by6hprmk77qrqr9mqn3dxqm6an8jwjn9";
            };
            version = "3.0.36";
          };
          gi-gtk-hs = hself.gi-gtk-hs_0_3_9;
          gi-harfbuzz = markUnbroken hsuper.gi-harfbuzz;
          gi-pango = hself.gi-pango_1_0_23;
          gi-xlib = hself.gi-xlib_2_0_9;
          haskell-gi = hself.haskell-gi_0_24_3;
          haskell-gi-base = addBuildDepend hself.haskell-gi-base_0_24_2
            self.gobject-introspection;
          taffybar = appendPatch hsuper.taffybar (self.fetchpatch {
            url =
              "https://github.com/taffybar/taffybar/pull/494/commits/a7443324a549617f04d49c6dfeaf53f945dc2b98.patch";
            sha256 = "0prskimfpapgncwc8si51lf0zxkkdghn33y3ysjky9a82dsbhcqi";
          });
        });
    })
  ];
}
