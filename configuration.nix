# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.musnix.nixosModules.default
    inputs.hyprland.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
  ];

  nixpkgs.config = import ./nixpkgs-config.nix;

  nixpkgs.overlays = [
    inputs.rust-overlay.overlays.default
    # "overwrite" xdg-open with handlr
    (final: prev: {
      # very expensive since this invalidates the cache for a lot of (almost all) graphical apps.
      xdg-utils = prev.xdg-utils.overrideAttrs (oldAttrs: {
        postInstall = oldAttrs.postInstall + ''
          # "overwrite" xdg-open with handlr
          cp ${prev.writeShellScriptBin "xdg-open" "${prev.handlr}/bin/handlr open \"$@\""}/bin/xdg-open $out/bin/xdg-open
        '';
      });
    })
    (final: prev: {
      shntool = prev.shntool.overrideAttrs (
        old: {
          version = "24-bit";
          patches = [
            (builtins.fetchurl {
              url = "https://salsa.debian.org/debian/shntool/-/raw/57efcd7b34c2107dd785c11d79dfcd4520b2bc41/debian/patches/950803.patch?inline=false";
              sha256 = "sha256:0rlybjm6qf3ydqr44ns4yg4hwi4jhq237a5p6ph2v7s0630c90i9";
            })
          ];
        }
      );
      # firefox = prev.wrapFirefox
      #   (prev.firefox-unwrapped.overrideAttrs (
      #     old: {
      #       patches = old.patches ++ [
      #         (builtins.fetchurl {
      #           url = "https://phabricator.services.mozilla.com/D164578?download=true";
      #           sha256 = "sha256:0g576pjsh6shd53414ram44b7vyd4r9h1y3cah2dgzgf3hx4kvpx";
      #         })
      #       ];
      #     }
      #   ))
      #   { };
      rofi-wayland-unwrapped = prev.rofi-wayland-unwrapped.overrideAttrs
        (old: {
          src = prev.fetchFromGitHub {
            owner = "lbonn";
            repo = "rofi";
            rev = "f8bec1453c94a114f366efbfab12fb3b7856a1ab";
            fetchSubmodules = true;
            sha256 = "sha256-+aLQjLPRaJY2+/Ilc76u52U561pI2Ta0GvfirhLJP8U=";
          };
          version = "1.7.6+wayland1-git";
        });
    })
    (final: prev: {
      youtube-dl = prev.youtube-dl.overrideAttrs (
        old: {
          src = prev.fetchFromGitHub {
            owner = "ytdl-org";
            repo = "youtube-dl";
            rev = "fe7e13066c20b10fe48bc154431440da36baec53";
            sha256 = "sha256-suGzr/R0FbYrIS+aKAaQ9E8C6ssUZIIM7mq3QXiC1s4=";
          };
          patches = [ ];
          postInstall = "";
          version = "git";
        }
      );
    })
    (final: prev: {
      bitwig-studio = prev.bitwig-studio.overrideAttrs (
        old: {
          version = "5.0.11";
          src = builtins.fetchurl {
            url = "https://downloads.bitwig.com/5.0%20Beta%2011/bitwig-studio-5.0-beta-11.deb";
            sha256 = "sha256:1nidazcav73mg1naavi0par6cj0ada7l77ca3yhkd7sy98gmkz36";
          };
        }
      );
    })
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix = {
    package = pkgs.nixUnstable;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      auto-optimise-store = true;
      keep-failed = true;
      trusted-users = [ "root" "@wheel" ];
      substituters = [ "https://nix-cache.mildenberger.me" "https://cache.nixos.org/" "https://hyprland.cachix.org" "https://cache.ngi0.nixos.org" "https://cache.iog.io" ];
      trusted-public-keys = [
        "nix-cache.mildenberger.me:dcNVw3YMUReIGC5JsMN4Ifv9xjbQn7rkDF7gJIO0ZoI="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA="
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      ];
      experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
  boot.kernelModules = [ "v4l2loopback" ];

  system.stateVersion = "22.11";

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
  networking.firewall.allowedTCPPorts = [ 80 443 8080 8081 8000 8001 3000 6600 7201 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8080 8081 8000 8001 3000 6600 7201 ];
  networking.firewall.allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
  networking.firewall.allowedUDPPortRanges = [{ from = 1714; to = 1764; }];

  networking.hosts = { "127.0.0.1" = [ "work" "www" "spa-test" ]; };

  # nginx is sandboxed and doesn't allow reading from /home
  systemd.services.nginx.serviceConfig = {
    ProtectSystem = lib.mkForce false;
    ProtectHome = lib.mkForce false;
  };
  services.nginx = {
    user = "philm"; # because all content is served locally in home for testing
    enable = true;
    recommendedGzipSettings = true;
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
      "spa-test" = {
        # simple test for SPAs, that need to use / with normal history routing
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
    settings.PermitRootLogin = "yes";
  };

  services.udisks2.enable = true;

  # Enable the X11 windowing system.

  services.autorandr.enable = true;
  hardware.pulseaudio.enable = false;

  services.vnstat.enable = true;

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    EDITOR = "${config.home-manager.users.philm.programs.helix.package}/bin/hx";
  };

  services.xserver = {
    enable = true;
    autoRepeatInterval = 15;
    autoRepeatDelay = 300;
    xkbVariant = "colemak";
    # Enable touchpad support.
    libinput.enable = true;
    displayManager.gdm.enable = true;
    displayManager.gdm.debug = true;

    displayManager = {
      sessionPackages = [ config.home-manager.users.philm.modules.gui.desktop-environment.hyprland-session-wrapper ];
      # Use session defined in home.nix
      session = [{
        name = "xmonad";
        manage = "window";
        bgSupport = true;
        start = ''
          ${pkgs.runtimeShell} $HOME/.xsession &
          waitPID=$!
        '';
      }];
      defaultSession = "none+xmonad";
    };
  };

  services.kanata = {
    enable = true;
    # package = pkgs.rustPlatform.buildRustPackage {
    #   pname = "kanata";
    #   version = "1.3.0-git";
    #   src = inputs.kanata;
    #   cargoHash = "sha256-IW+TjVROjzllQuk5SMCq4O06c1+hAlfRQlRRJ2MFFl0=";
    #   buildFeatures = [ "cmd" ];
    # };
    keyboards.redox = {
      # devices are configured in each /machines/<machine>/default.nix
      # TODO extend kanata to automatically recognize input devices, autorestart/map devices if they connect/disconnect etc.
      config = ''
        (defsrc
          mlft mrgt mmid mfwd
          esc  1    2    3    4    5    6    7    8    9    0    -    =    bspc
          tab  q    w    f    p    g    j    l    u    y    ;    [    ]    \
          caps a    r    s    t    d    h    n    e    i    o    '    ret
          lsft z    x    c    v    b    k    m    ,    .    /    rsft
          lctl lmet lalt           spc            ralt rmet cmp rctl
        )
        (deflayer colemak
          mlft mrgt mmid @metaextra
          esc  1    2    3    4    5    6    7    8    9    0    -    =    bspc
          @xcp q    w    f    p    g    j    l    u    y    ;    [    ]    \
          caps a    r    s    t    d    h    n    e    i    o    '    ret
          lsft z    x    c    v    b    k    m    ,    .    /    rsft
          lctl lmet lalt           spc            ralt rmet cmp rctl
        )
        (defalias xcp (tap-hold-press 300 300 tab lmet))
        (defalias metaextra (tap-hold-press 300 300 mfwd lmet))
      '';
    };
  };

  systemd.user.services."sync-nix-cache" = {
    path = [ config.programs.ssh.package ];
    enable = true;
    script = "${config.nix.package}/bin/nix copy -s --to ssh://nix-cache.mildenberger.me /run/current-system";
    startAt = "hourly";
  };

  # gtk themes (home-manager more specifically) seem to have problems without it
  services.dbus.packages = [ pkgs.dconf ];
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true; # necessary? as hyprland has its own xdg-portal based on wlr
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-kde
      (inputs.xdph.packages.${pkgs.hostPlatform.system}.default.override {
        hyprland-share-picker = inputs.xdph.packages.${pkgs.hostPlatform.system}.hyprland-share-picker.override { hyprland = config.home-manager.users.philm.wayland.windowManager.hyprland.package; };
      })
    ];
  };

  services.flatpak.enable = true;
  services.teamviewer.enable = true;
  programs.command-not-found.enable = false;

  # allow no password for sudo (dangerous...)
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.philm = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "input"
      "uinput"
      "audio"
      "dialout"
      "networkmanager"
      "systemd-journal"
      "adbusers"
      "realtime"
      "video"
      "power"
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
    ];
  };
  users.extraGroups.vboxusers.members = [ "philm" ];

  # configure home-manager
  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.users.philm = {
    imports = builtins.attrValues inputs.self.homeManagerModules ++ [ inputs.nix-index-database.hmModules.nix-index ];
    programs.home-manager.enable = true;
    nixpkgs.config = import ./nixpkgs-config.nix;
    xdg.configFile."nixpkgs/config.nix".source = ./nixpkgs-config.nix;
    home.stateVersion = "22.05";
    modules.cli.enable = true;
    modules.gui.enable = true;
    modules.create-directories.enable = true;
  };

  # All system wide packages

  programs.fish.enable = true;

  programs.adb.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "curses";
  };

  programs.steam.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;
  programs.seahorse.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # DEVELOPMENT
    ## compilers and dev environment
    # clang_10 # conflicts with gcc
    python3Full
    python3Packages.pip
    python3Packages.setuptools
    poetry
    elixir
    gcc10
    gdb
    meson
    cmake
    dart
    git
    gti
    git-secret
    git-crypt
    gitAndTools.diff-so-fancy
    pijul
    gnumake
    jdk
    ghc
    llvmPackages.bintools
    neovim
    kakoune
    android-studio
    droidcam
    flatpak-builder
    # haskell.compiler.ghc882
    nixpkgs-review
    php
    yarn
    deno
    nodejs_latest
    nodePackages.node2nix
    pkg-config
    # rustup
    sqlitebrowser
    zig
    wasm-pack
    vscode
    glslang
    vulkan-tools
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    steam-run
    rcm # manage dotfiles

    # OFFICE/DOCUMENTING
    pandoc
    calibre
    exiv2
    libreoffice
    texlive.combined.scheme-full
    zathura

    # TERMINAL/CLI
    fasd
    fzf
    file
    progress
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
    grex
    hyperfine
    tealdeer
    procs
    wget
    unzip
    b3sum
    yq
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
    exiftool

    # AUDIO
    cantata
    yabridge
    yabridgectl
    pavucontrol
    helvum
    ffmpeg_5-full
    flacon
    bitwig-studio
    playerctl
    reaper

    # COMMUNICATION
    thunderbird
    signal-desktop
    element-desktop
    qtox
    discord
    slack
    v4l-utils
    zoom-us
    skypeforlinux
    fractal
    tdesktop

    # WEB
    chromium
    google-chrome
    firefox
    firefox-beta-bin
    (brave.override { vulkanSupport = true; })
    tor-browser-bundle-bin
    ff2mpv

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
    minecraft
    wineWowPackages.staging
    winetricks
    protontricks

    # MISC
    scrcpy
    neovide
    xorg.xhost
    nix-du
    nix-tree
    nix-query-tree-viewer
    inputs.comma.packages.${pkgs.system}.default
    inputs.devenv.packages.${pkgs.system}.devenv
    # colmapWithCuda
    colmap
    exfat
    rdup
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
    openvpn3
    powertop
    usbutils
    cabextract
    patchelf
    qdirstat
    borgbackup
    electrum
    monero-gui
    keepassxc
    memtester
    docker-compose
    # arion
    filezilla
    scrot
    feh # to view images in terminal wrapped in home.packages with a script for svg support
    gwenview
    smartmontools
    rdfind
    rage
    imagemagick
    # unityhub
    fira-code
    mpv
    source-code-pro
    transmission-gtk
    qbittorrent
    xclip
    adb-sync
    udiskie
    tree-sitter
    rust-bin.nightly.latest.default
    rust-bin.nightly.latest.rust-analyzer
    cargo-flamegraph
  ];

  # TODO put these in home-manager?
  fonts = {
    fontconfig.enable = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      font-awesome
      emojione
      nerdfonts
      google-fonts
      material-symbols
    ];
  };
}
