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
            "https://github.com/Philipp-M/home-manager/archive/2554ae9545104160660f1e2a0bea596d447fcac7.tar.gz";
          sha256 = "1g5fw9k4xvly3vr89zccc7lw57f06px0mpq59a4h305vbm6idza0";
        })
      }/nixos")
  ];

  # NUR and other custom packages
  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball {
      url =
        "https://github.com/nix-community/NUR/archive/54d26b858b073adca6425385ea7bb085f2676bd0.tar.gz";
      sha256 = "0d7xxrb21xim937vgb0i0nxj1bhb4k2r6kqr860alavfqf5x3ivq";
    }) { inherit pkgs; };

    all-hies = import (builtins.fetchTarball {
      url =
        "https://github.com/Infinisil/all-hies/archive/4b6aab017cdf96a90641dc287437685675d598da.tar.gz";
      sha256 = "0ap12mbzk97zmxk42fk8vqacyvpxk29r2wrnjqpx4m2w9g7gfdya";
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
    displayManager = {
      defaultSession = "none+xmonad";
      # this prevents accidentally turned on caps lock in the login manager (as it is remapped in the xmonad session to escape)
      sessionCommands = "${pkgs.xorg.xmodmap}/bin/xmodmap -e 'clear Lock'";
    };
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
    ## compilers and dev environment
    clang_10
    python3
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
    rcm # manage dotfiles

    # Document tools
    pandoc
    libreoffice
    texlive.combined.scheme-full
    zathura

    # Terminal stuff
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
    wget
    unzip
    zip

    # Graphical Editors
    blender
    krita

    # Communication
    discord
    zoom-us
    tdesktop

    # Web
    chromium
    firefox
    torbrowser

    # Desktop Environment
    dmenu
    nerdfonts
    xorg.xev
    xorg.xmessage

    # Games
    minecraft
    steam

    # Misc
    mprime
    memtester
    docker-compose
    filezilla
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
