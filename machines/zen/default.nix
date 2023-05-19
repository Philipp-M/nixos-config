{ config, lib, pkgs, modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../configuration.nix
  ];

  nixpkgs.overlays = import ../../secrets/nix-expressions/zen-overlays.nix;

  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.production;
      modesetting.enable = true;
      powerManagement.enable = true;
      forceFullCompositionPipeline = true;
    };
  };

  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "sd_mod" ];
    initrd.checkJournalingFS = false; # fsck.f2fs is broken with extended node bitmap (needed for precious inodes)
    kernelParams = [ "nordrand" "amd_iommu=fullflush" ];
    supportedFilesystems = [ "ntfs" "zfs" ];
    zfs.requestEncryptionCredentials = false;
    zfs.enableUnstable = true;
    kernelPackages = pkgs.linuxPackages_6_1;
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    kernelModules = [ "kvm-amd" "snd-seq" "snd-rawmidi" ];
    loader.systemd-boot.consoleMode = "max";
    # Bluetooth
    extraModprobeConfig = ''
      options bluetooth disable_ertm=1
    '';
  };

  # optimize kernel for low-latency audio
  powerManagement.cpuFreqGovernor = "performance";
  musnix.enable = true;

  # disk configuration
  # root on tmpfs and persistence via impermanence

  fileSystems = {
    "/persistent" = {
      device = "/dev/disk/by-uuid/a0aab361-0865-4b5b-a556-5e2c97ea53d1";
      fsType = "f2fs";
      options = [ "compress_algorithm=lz4" "compress_chksum" "atgc" "gc_merge" "lazytime" ];
      neededForBoot = true;
    };
    # impermanence tries to unmount /nix, thus manually bind mount it here
    "/nix" = {
      device = "/persistent/nix/";
      options = [ "bind" ];
      depends = [ "/persistent" ];
      neededForBoot = true;
    };
    "/boot" = { device = "/dev/disk/by-uuid/90D9-9D03"; fsType = "vfat"; };
    "/data/music" = { device = "data/music"; fsType = "zfs"; };
    # impermanence doesn't support yet direct bind mounts (without the path prefix on the persistent device)
    "/home/philm/Music" = { device = "/data/music"; options = [ "bind" ]; depends = [ "/data/music" ]; };
    "/data/games" = { device = "data/games"; fsType = "zfs"; };
    "/data/media" = { device = "data/media"; fsType = "zfs"; };
    "/data/backup" = { device = "data/backup"; fsType = "zfs"; };
    "/data/audio" = { device = "data/audio"; fsType = "zfs"; };
    "/data/photos" = { device = "data/photos"; fsType = "zfs"; };
    "/home/philm/Photos" = { device = "/data/photos"; options = [ "bind" ]; depends = [ "/data/photos" ]; };
    # root on tmpfs
    "/" = { device = "none"; fsType = "tmpfs"; options = [ "defaults" "size=64G" "mode=755" ]; };
  };

  # persistent state

  environment.persistence."/persistent" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/blueman"
      "/var/lib/cups/ppd"
      "/var/lib/bluetooth"
      "/var/lib/systemd/coredump"
      "/var/lib/docker"
      "/var/lib/teamviewer"
      "/var/lib/NetworkManager"
      "/var/lib/flatpak"
      "/var/lib/vnstat"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/var/lib/cups/subscriptions.conf"
      "/var/lib/cups/printers.conf"
    ];
    users.philm = {
      directories = [
        "dev"
        "wallpaper"
        "screenshots"
        "Downloads"
        "Desktop"
        "Pictures"
        "Documents"
        "Videos"
        "Audio"
        "VirtualBox VMs"
        "Bitwig Studio"
        "SteamLibrary"
        "Calibre Library"
        "Unity"
        { directory = ".gnupg"; mode = "0700"; }
        { directory = ".ssh"; mode = "0700"; }
        { directory = ".local/share/keyrings"; mode = "0700"; }
        ".config/calibre"
        ".config/cantata"
        ".config/chromium"
        ".config/dconf"
        ".config/discord"
        ".config/easyeffects"
        ".config/Element"
        ".config/gtk-2.0"
        ".config/gtk-3.0"
        ".config/gtk-4.0"
        ".config/kdeconnect"
        ".config/qBittorrent"
        ".config/Signal"
        ".config/syncthing"
        ".config/yabridgectl"
        ".config/FreeCAD"
        ".config/gh"
        ".config/heroic"
        ".config/Google"
        ".config/BraveSoftware"
        ".config/tree-sitter"
        ".config/obs-studio"
        ".config/chatgpt"
        ".local/share/mpd"
        ".local/share/rofi"
        ".local/share/flatpak"
        ".local/share/zathura"
        ".local/share/nix"
        ".local/share/qBittorrent"
        ".local/share/Steam"
        ".local/share/cantata"
        ".local/share/fish"
        ".local/share/zoxide"
        ".local/share/chatgpt"
        ".local/share/TelegramDesktop"
        ".local/state/wireplumber"
        ".BitwigStudio"
        ".cache/nix" # avoid unnecessary fetching
        ".cache/Google" # Android studio takes a long time otherwise
        ".gradle"
        ".android"
        ".var/app"
        ".vst"
        ".gnome"
        ".steam"
        ".cargo"
        ".mozilla"
        ".thunderbird"
        ".wine"
        ".xmonad"
      ];
      files = [ ".cache/helix/helix.log" ".npmrc" ];
    };
  };

  swapDevices = [{ device = "/dev/disk/by-uuid/c44661f2-5dfb-4f7d-854e-4d3ebd4eabdd"; }];

  networking = {
    hostId = "80e43ffd";
    hostName = "zen";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager = {
      enable = true;
      dns = "none";
    };
    interfaces = {
      enp38s0.useDHCP = true;
      enp39s0.useDHCP = true;
      wlo1.useDHCP = false;
    };
  };


  # disable virtualbox as it has problems with the rt kernel
  virtualisation.virtualbox.host.enable = lib.mkForce false;
  virtualisation.docker.enableNvidia = true;

  services.kanata.keyboards.redox.devices = [
    "/dev/input/by-id/usb-Falbatech_The_Redox_Keyboard-event-kbd" # redox keyboard
    "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse" # mouse
  ];

  users = let philm-password = builtins.readFile ../../secrets/philm-password; in {
    mutableUsers = false;
    users.philm = {
      initialHashedPassword = philm-password;
      extraGroups = [ "jackaudio" "lpadmin" ];
    };
    users.root.initialHashedPassword = philm-password;
  };

  services.blueman.enable = true;

  # necessary for 172 and 192 kHz sample rate
  environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text = ''
    alsa_monitor.rules = { {
      matches = { { { "device.name", "matches", "alsa_card.usb-MOTU_UltraLite-mk5_UL5LFF562C-00" }, }, },
      apply_properties = {
        ["api.alsa.use-acp"] = true,
        ["api.alsa.use-ucm"] = false,
        ["api.acp.auto-profile"] = false,
        ["api.acp.pro-channels"] = 10,
        ["api.acp.probe-rate"] = 176400,
        ["device.profile"] = "pro-audio",
      },
    }, }
  '';

  # services.pipewire.config = {
  #   pipewire = {
  #     "context.properties" = {
  #       "link.max-buffers" = 16;
  #       "log.level" = 2;
  #       # "default.clock.allowed-rates" = [ 44100 48000 ];
  #       "default.clock.allowed-rates" = [ 176400 192000 ];
  #       "default.clock.rate" = 176400;
  #       # "default.clock.rate" = 44100;
  #       "default.clock.quantum" = 1024;
  #       "default.clock.min-quantum" = 16;
  #       "default.clock.max-quantum" = 2048;
  #       "core.daemon" = true;
  #       "core.name" = "pipewire-0";
  #     };
  #     "context.modules" = [
  #       {
  #         name = "libpipewire-module-rt";
  #         args = {
  #           "nice.level" = 20;
  #           "rt.prio" = 88;
  #           "rt.time.soft" = -1;
  #           "rt.time.hard" = -1;
  #         };
  #         flags = [ "ifexists" "nofail" ];
  #       }
  #       { name = "libpipewire-module-protocol-native"; }
  #       { name = "libpipewire-module-profiler"; }
  #       { name = "libpipewire-module-metadata"; }
  #       { name = "libpipewire-module-spa-device-factory"; }
  #       { name = "libpipewire-module-spa-node-factory"; }
  #       { name = "libpipewire-module-client-node"; }
  #       { name = "libpipewire-module-client-device"; }
  #       {
  #         name = "libpipewire-module-portal";
  #         flags = [ "ifexists" "nofail" ];
  #       }
  #       {
  #         name = "libpipewire-module-access";
  #         args = { };
  #       }
  #       { name = "libpipewire-module-adapter"; }
  #       { name = "libpipewire-module-link-factory"; }
  #       { name = "libpipewire-module-session-manager"; }
  #     ];
  #   };
  #   jack."jack.properties"."node.latency" = "512/96000";
  # };

  # ZFS related
  services.zfs.autoScrub = {
    interval = "Sun *-*-01..07 02:00:00";
    enable = true;
  };
  services.sanoid =
    let
      # templates not working correctly because of kinda broken sanoid config
      # (default values, which aren't overwritten by templates)
      default = {
        daily = 7;
        hourly = 1000; # > one month hourly snapshots
        monthly = 5;
        yearly = 0;
        # frequently
        # TODO with ssd enable this again including the hourly...
        # settings = {
        #   frequent_period = 15;
        #   frequently = 8;
        # };
      };
    in
    {
      enable = true;
      datasets."data/private" = default;
      datasets."data/backup" = default;
      datasets."data/games" = default;
      datasets."data/photos" = default;
      datasets."data/music" = default;
    };

  services.syncthing = {
    enable = true;
    user = "philm";
    dataDir = "/home/philm/";
    configDir = "/home/philm/.config/syncthing";
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [ hplip ];
  };
  services.avahi.enable = true;
  services.avahi.nssmdns = true;
  programs.system-config-printer.enable = true;

  networking.hosts = { "127.0.0.1" = [ "syncthing" ]; };

  services.nginx.virtualHosts."syncthing".locations."/" = {
    proxyPass = "http://localhost:8384";
    proxyWebsockets = true;
  };

  # don't backup everything in persistent,
  # as not everything is important (over a long period) (i.e. cached things or logs),
  # but may litter the backup partition (many writes)
  systemd.services.backup-persistent = {
    description = "Backups (important stuff of) persistent partition with rsync";
    startAt = "*-*-* *:50:00";
    serviceConfig.Type = "simple";
    wantedBy = [ "multi-user.target" ];
    script = ''
      printf "Started Backup at $(date)\n" >> /var/log/backup-persistent.log
      ${pkgs.rsync}/bin/rsync \
        --delete \
        -av \
        --delete-excluded \
        --exclude /var/lib/systemd \
        --exclude /var/lib/docker \
        --exclude /var/log \
        --exclude /nix \
        --exclude /home/philm/Unity \
        --exclude /home/philm/.rustup \
        --exclude /home/philm/.cache \
        --exclude /home/philm/.cargo \
        --exclude /home/philm/.gradle \
        --exclude /home/philm/.android \
        --exclude /home/philm/.npmrc \
        --exclude /home/philm/.xmonad \
        --filter=':- .gitignore' \
        --filter=':- .npmignore' \
        --filter=':- .ignore' /persistent/ \
        /data/backup/zen/ 2>&1 >> /var/log/backup-persistent.log
      printf "Finished Backup at $(date)\n\n" >> /var/log/backup-persistent.log
    '';
  };

  systemd.services.hd-idle = {
    description = "HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle -i 180 -c ata";
    };
  };

  services.xserver = { dpi = 110; videoDrivers = [ "nvidia" ]; };

  home-manager.users.philm = {
    modules.mpd.enable = true;
    services.blueman-applet.enable = true;
    home.sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
    };
  };

  # reduce jobs, as otherwise a lot of swapping occurs (which I guess slows down the building process)
  nix.settings.max-jobs = lib.mkDefault 1;
  # High-DPI console
  console.font =
    lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  environment.systemPackages = with pkgs; [
    (import ../../secrets/nix-expressions/toggle-light.nix { inherit pkgs; })
    qjackctl
    libjack2
    guitarix
    lingot
    mpc_cli
    carla
    jack2
    blender
    nvidia-vaapi-driver
    heroic
    arduino
    shntool
    flac
    cuetools
    # arduino-core
    arduino-cli
    nvtop
    factorio
  ];
}
