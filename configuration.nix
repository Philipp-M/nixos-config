# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, lib, nixpkgs-unstable, inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    # expensive since this invalidates the cache for various apps like chromium etc.
    # (final: prev: { xdg-utils = prev.xdg-utils.override { mimiSupport = true; }; })
    (final: prev: {
      xdg-utils = prev.xdg-utils.overrideAttrs (oldAttrs: {
        postInstall = oldAttrs.postInstall + ''
          # "overwrite" xdg-open with handlr
          cp ${pkgs.writeShellScriptBin "xdg-open" "${pkgs.handlr}/bin/handlr open \"$@\""}/bin/xdg-open $out/bin/xdg-open
        '';
      });
    })
  ];

  nix = {
    package = pkgs.nixUnstable;
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "root" "@wheel" ];
      substituters = [ "https://cache.nixos.org/" "https://cache.ngi0.nixos.org" "https://cache.iog.io" "https://nix-cache.mildenberger.me" ];
      trusted-public-keys = [
        "nix-cache.mildenberger.me:dcNVw3YMUReIGC5JsMN4Ifv9xjbQn7rkDF7gJIO0ZoI="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA="
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      ];
      experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    };
  };

  nixpkgs.config.permittedInsecurePackages = [
    "libdwarf-20181024"
  ];

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
    displayManager = {
      lightdm = {
        background = builtins.fetchurl {
          url = "https://github.com/DaringCuteSeal/wallpapers/raw/main/os/nix-simple/nix-simple-geometric.png";
          sha256 = "sha256:10fqxx5z0591jmllw9iya2dkck47fs45hkzc9p4vfwdbzz0b2y1b";
        };
        # this is dependent on importing the 'theme.nix' home-manager module
        greeters.gtk.theme = with config.home-manager.users.philm.theme; {
          name = base16.name;
          package = pkgs.callPackage (import "${inputs.rycee-nur-expressions}/pkgs/materia-theme") { configBase16 = base16; };
        };
      };
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
      # this prevents accidentally turned on caps lock in the login manager (as it is remapped in the xmonad session to escape)
      sessionCommands = "${pkgs.xorg.xmodmap}/bin/xmodmap -e 'clear Lock'";
    };
  };

  services.kanata = {
    enable = true;
    package = pkgs.rustPlatform.buildRustPackage {
      pname = "kanata";
      version = "1.0.8-git";
      src = inputs.kanata;
      cargoHash = "sha256-z4lVVlUx8EzhfZmaJOONFcGB4OMjMzYIHbezhMTetcQ=";
      buildFeatures = [ "cmd" ];
    };
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

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  services.flatpak.enable = true;

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

  # All system wide packages

  programs.fish.enable = true;

  programs.adb.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "curses";
  };

  programs.steam.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; let unstable = nixpkgs-unstable.pkgs; in
  [
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
    carnix
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
    unstable.youtube-dl
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
    unstable.yabridge
    unstable.yabridgectl
    pavucontrol
    unstable.helvum
    unstable.ffmpeg_5-full
    flacon
    unstable.bitwig-studio

    # COMMUNICATION
    thunderbird
    signal-desktop
    element-desktop
    qtox
    unstable.discord
    v4l-utils
    zoom-us
    skypeforlinux
    tdesktop

    # WEB
    chromium
    google-chrome
    firefox
    tor-browser-bundle-bin

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
    unstable.lutris
    minecraft
    unstable.wineWowPackages.staging
    unstable.winetricks

    # MISC
    neovide
    exfat
    rdup
    sanoid
    gsettings-desktop-schemas
    appimage-run
    ntfs3g
    unstable.woeusb
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
    unstable.monero-gui
    ecryptfs
    ecryptfs-helper
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
  ];

  fonts.fonts = with pkgs; [ font-awesome nerdfonts google-fonts ];
}
