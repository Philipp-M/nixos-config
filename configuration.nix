# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, options, lib, nixpkgs-unstable, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    autoOptimiseStore = true;
  };

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
    # Use session defined in home.nix
    windowManager = {
      session = [
        {
          name = "xmonad";
          bgSupport = true;
          start = ''
            ${pkgs.runtimeShell} $HOME/.xsession &
            waitPID=$!
          '';
        }
      ];
    };
    displayManager = {
      defaultSession = "none+xmonad";
      # this prevents accidentally turned on caps lock in the login manager (as it is remapped in the xmonad session to escape)
      sessionCommands = "${pkgs.xorg.xmodmap}/bin/xmodmap -e 'clear Lock'";
    };
  };

  systemd.user.services."setup-keyboard" = {
    enable = true;
    description = "Load my keyboard modifications";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash ${
      pkgs.writeScript "setup-keyboard.sh" ''

            #!${pkgs.stdenv.shell}

            sleep 0.2;

            # Stop previous xcape processes, otherwise xcape is launched multiple times
            # And buttons get implemented multiple times
            ${pkgs.killall}/bin/killall xcape

            # Remap Escape to 'Hyper_L' for an extra 'hybrid' modifier for xmonad and other applications that use Super
            # Caps Lock is useless anyway, so remap it to 'Escape' to provide comfort in vim...
            # Unfortunately Alacritty (or more precisely winit) has a bug with xmodmap modifier remappings...
            ${pkgs.xorg.xmodmap}/bin/xmodmap  \
                    -e 'keycode 23 = Hyper_L'  \
                    -e 'clear Lock'           \
                    -e 'keycode 66 = Escape' \
                    -e 'keycode any = Tab' \
            # Currently the service xcape in home-manager doesn't work correctly
            # (my guess is because xcape is started before the script above)
            # The following line is used for reenabling Escape if it is used on its own (single tap which takes under 500ms)
            ${pkgs.xcape}/bin/xcape -d -e 'Hyper_L=Tab'
          ''
      }";
    };
  };
  
  systemd.services."restart-setup-keyboard-after-suspend" = {
    enable = true;
    description = "restarts setup-keyboard after resume because it xcape seems to have problems sometimes";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    serviceConfig = {
      Type = "simple";
      User = "philm"; # Unfortunately this needs to be hardcoded since user services don't work for this,
                      # see: https://unix.stackexchange.com/a/492497
    };
    script = ''
      XDG_RUNTIME_DIR=/run/user/$UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID/bus ${pkgs.systemd}/bin/systemctl --no-block --user restart setup-keyboard.service
    '';
  };

  # aweful hack to enable the systemd service setup-keyboard, which maps super to tab if pressed
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ENV{LED}!="", ENV{ID_INPUT_KEYBOARD}=="1", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="setup-keyboard.service"
    SUBSYSTEM=="input", ENV{LED}!="", ENV{ID_INPUT_KEYBOARD}=="1", ACTION=="remove", TAG+="systemd", RUN+="${pkgs.killall}/bin/killall -SIGKILL xcape"
  '';

  # gtk themes (home-manager more specifically) seem to have problems without it
  services.dbus.packages = [ pkgs.gnome3.dconf ];
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
      "audio"
      "dialout"
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
    rustup
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
    unstable.yabridge
    unstable.yabridgectl
    pavucontrol
    unstable.helvum
    ffmpeg-full
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
    skype
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
    exfat-utils
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
    feh # to view images in terminal
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
  ];

  fonts.fonts = with pkgs; [ nerdfonts google-fonts ];
}
