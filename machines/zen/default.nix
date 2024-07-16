{ config, lib, pkgs, modulesPath, ... }:
let
  persistent = "/persistent";
in
{
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
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      modesetting.enable = true;
      powerManagement.enable = true;
      forceFullCompositionPipeline = true;
    };
  };


  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "sd_mod" ];
    initrd.checkJournalingFS = false; # fsck.f2fs is broken with extended node bitmap (needed for precious inodes)
    kernelParams = [
      "nordrand"
      "amd_iommu=fullflush"
      "preempt=full"
      "nvidia.NVreg_EnableGpuFirmware=0"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      "initcall_blacklist=simpledrm_platform_driver_init"
    ];
    supportedFilesystems = [ "ntfs" "zfs" ];
    zfs.requestEncryptionCredentials = false;
    zfs.package = pkgs.zfs_unstable;
    # kernelPackages = pkgs.linuxPackages_6_1;
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    kernelModules = [ "kvm-amd" "snd-seq" "snd-rawmidi" "snd-virmidi" ];
    blacklistedKernelModules = [ "snd-pcsp" "snd-hda-intel" ]; # don't use anything else than the audio interface, this just adds up noise...
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
    "${persistent}" = {
      device = "/dev/disk/by-uuid/a0aab361-0865-4b5b-a556-5e2c97ea53d1";
      fsType = "f2fs";
      options = [ "compress_algorithm=lz4" "compress_chksum" "atgc" "gc_merge" "lazytime" ];
      neededForBoot = true;
    };
    # impermanence tries to unmount /nix, thus manually bind mount it here
    "/nix" = {
      device = "${persistent}/nix/";
      options = [ "bind" ];
      depends = [ "${persistent}" ];
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

  environment.persistence."${persistent}" = {
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
        # tmp folder, persistent, but not backed up
        "tmp"
        "wallpaper"
        "screenshots"
        "windows-11"
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
        "Arduino"
        { directory = ".gnupg"; mode = "0700"; }
        { directory = ".ssh"; mode = "0700"; }
        { directory = ".local/share/keyrings"; mode = "0700"; }
        ".config/calibre"
        ".config/cantata"
        ".config/chromium"
        ".config/cosmic"
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
        ".config/Slack"
        ".config/BraveSoftware"
        ".config/Renoise"
        ".config/loopers"
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
        ".local/share/Midinous"
        ".local/state/wireplumber"
        ".BitwigStudio"
        ".cache/nix" # avoid unnecessary fetching
        ".cache/nvidia" # avoid unnecessary computation
        ".cache/Google" # Android studio takes a long time otherwise
        ".cache/cantata" # avoid redownloading covers
        ".gradle"
        ".android"
        ".var/app"
        ".vst"
        ".vst3"
        ".gnome"
        ".steam"
        ".cargo"
        ".mozilla"
        ".thunderbird"
        ".wine"
        ".xmonad"
      ];
      files = [ ".cache/helix/helix.log" ".npmrc" ".nvidia-settings-rc" ];
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

  services.samba = {
    enable = true;
    nsswins = true;
    enableWinbindd = true;
  };

  # disable virtualbox as it has problems with the rt kernel
  virtualisation.virtualbox.host.enable = lib.mkForce false;
  virtualisation.docker.enableNvidia = true;
  virtualisation.spiceUSBRedirection.enable = true;

  services.openssh.hostKeys = [
    { path = "${persistent}/etc/ssh/ssh_host_rsa_key"; bits = 4096; type = "rsa"; }
    { path = "${persistent}/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
  ];

  services.kanata.keyboards.default.devices = [
    "/dev/input/by-id/usb-Falbatech_The_Redox_Keyboard-event-kbd" # redox keyboard
    "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse" # mouse
    "/dev/input/by-id/usb-Gaming_KB_Gaming_KB-event-kbd"
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

  services.pipewire = {
    extraConfig = {
      pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 192000;
          "default.clock.quantum" = 512;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 4096;
        };
        "context.modules" = [
          {
            "name" = "libpipewire-module-rt";
            "args" = {
              "rt.prio" = 88;
              "rlimits.enabled" = true;
              "rtportal.enabled" = true;
              "rtkit.enabled" = true;
            };
            "flags" = [ "ifexists" "nofail" ];
          }
          { "name" = "libpipewire-module-portal"; }
          { "name" = "libpipewire-module-spa-node-factory"; }
          { "name" = "libpipewire-module-link-factory"; }
        ];
      };
      jack."92-low-latency" = {
        "jack.properties" = {
          "rt.prio" = 88;
          "node.latency" = "512/192000";
          "jack.show-monitor" = true;
          "jack.merge-monitor" = true;
          "jack.show-midi" = true;
          "jack.fix-midi-events" = true;
        };
      };
    };
    wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/50-ultralite-pro-audio-176khz-alsa.conf" ''
        monitor.alsa.rules = [ {
          matches = [ { device.name = "alsa_card.usb-MOTU_UltraLite-mk5_UL5LFF562C-00" } ]
          actions = {
            update-props = {
              api.alsa.use-acp = true,
              api.alsa.use-ucm = false,
              api.alsa.period-size   = 512,
              api.acp.probe-rate = 192000,
              api.acp.auto-profile = false
              api.acp.pro-channels = 10,
              device.profile = "pro-audio"
            }
          }
        } ]
      '')
    ];
  };

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
  services.avahi.nssmdns4 = true;
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
        --filter=':- .ignore' ${persistent}/ \
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

  services.xserver = {
    dpi = 110;
    videoDrivers = [ "nvidia" ];
    deviceSection = ''
      Option "TripleBuffer" "on"
    '';
  };

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
    (import ../../secrets/nix-expressions/toggle-bright-light.nix { inherit pkgs; })
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
    nvtopPackages.full
    factorio
  ];
}
