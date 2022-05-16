{ config, lib, pkgs, nixpkgs-unstable, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
  ];

  nixpkgs.overlays = (import ../../secrets/nix-expressions/zen-overlays.nix { inherit nixpkgs-unstable; });

  fileSystems."/windows" = {
    device = "/dev/disk/by-uuid/B8EEC319EEC2CF36";
    fsType = "ntfs";
    options = [ "rw" "uid=1000" ];
  };

  # use blender from flatpak for Optix support
  nixpkgs.config.packageOverrides = pkgs: {
    blender = pkgs.blender.override { cudaSupport = true; };
  };

  boot.supportedFilesystems = [ "ntfs" "zfs" ];
  boot.zfs.requestEncryptionCredentials = false;
  boot.extraModulePackages = [ config.boot.kernelPackages.zenpower ];
  boot.kernelModules = [ "snd-seq" "snd-rawmidi" ];

  networking.hostId = "80e43ffd";
  networking.hostName = "zen";

  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "none";

  hardware.enableRedistributableFirmware = true;

  networking.interfaces.enp38s0.useDHCP = true;
  networking.interfaces.enp39s0.useDHCP = true;
  networking.interfaces.wlo1.useDHCP = true;

  virtualisation.docker.enableNvidia = true;
  systemd.enableUnifiedCgroupHierarchy = false;

  musnix = {
    enable = true;
    kernel.optimize = true;
  };
  powerManagement.cpuFreqGovernor = "performance";

  services.pipewire.config = {
    pipewire = {
      "context.properties" = {
        "link.max-buffers" = 16;
        "log.level" = 2;
        "default.clock.rate" = 96000;
        "default.clock.quantum" = 2048;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 2048;
        "core.daemon" = true;
        "core.name" = "pipewire-0";
      };
      "context.modules" = [
        {
          name = "libpipewire-module-rtkit";
          args = {
            "nice.level" = -15;
            "rt.prio" = 88;
            "rt.time.soft" = 200000;
            "rt.time.hard" = 200000;
          };
          flags = [ "ifexists" "nofail" ];
        }
        { name = "libpipewire-module-protocol-native"; }
        { name = "libpipewire-module-profiler"; }
        { name = "libpipewire-module-metadata"; }
        { name = "libpipewire-module-spa-device-factory"; }
        { name = "libpipewire-module-spa-node-factory"; }
        { name = "libpipewire-module-client-node"; }
        { name = "libpipewire-module-client-device"; }
        {
          name = "libpipewire-module-portal";
          flags = [ "ifexists" "nofail" ];
        }
        {
          name = "libpipewire-module-access";
          args = { };
        }
        { name = "libpipewire-module-adapter"; }
        { name = "libpipewire-module-link-factory"; }
        { name = "libpipewire-module-session-manager"; }
      ];
    };
    jack."jack.properties"."node.latency" = "512/96000";
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
        hourly = 48;
        monthly = 5;
        yearly = 0;
        settings = {
          frequent_period = 15;
          frequently = 8;
        };
      };
    in
    {
      enable = true;
      interval = "*:0/15";
      datasets."tank/private" = default;
      datasets."tank/backup" = default;
      datasets."tank/games" = default;
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

  systemd.services.backup-home = {
    description = "Backups home with rsync";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.writeScript "backup-home" ''
        #!${pkgs.bash}/bin/bash
        echo "Starting Backup at $(date)" >> /var/log/home-backup.log
        ${pkgs.rsync}/bin/rsync --delete -av --exclude .cache --filter=':- .gitignore' --filter=':- .npmignore' --filter=':- .ignore' /home/ /tank/backup/zen/home/ 2>&1  >> /var/log/home-backup.log
        echo "Finished Backup at $(date)" >> /var/log/home-backup.log
        echo "" >> /var/log/home-backup.log
        echo "" >> /var/log/home-backup.log
      '' }";
    };
    startAt = "*-*-* 12,18,23:07:00";
  };

  systemd.services.hd-idle = {
    description = "HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${nixpkgs-unstable.pkgs.hd-idle}/bin/hd-idle -i 180 -c ata";
    };
  };

  services.xserver = {
    dpi = 110;
    screenSection = ''
      DefaultDepth 24
      Option "RegistryDwords" "PerfLevelSrc=0x3322; PowerMizerDefaultAC=0x1"
      Option "TripleBuffer" "True"
      Option "Stereo" "0"
      Option "nvidiaXineramaInfoOrder" "DP-4, DP-2"
      Option "metamodes" "DP-2: nvidia-auto-select +3840+0 { ForceFullCompositionPipeline=On }, DP-4: nvidia-auto-select +0+0 { ForceFullCompositionPipeline=On }"
      Option "SLI" "Off"
      Option "MultiGPU" "Off"
      Option "BaseMosaic" "off"
    '';
    videoDrivers = [ "nvidia" ];
  };

  hardware.nvidia.modesetting.enable = true;

  users.users.philm.extraGroups = [ "jackaudio" ];

  home-manager.users.philm.modules.mpd.enable = true;

  nix.maxJobs = lib.mkDefault 16;
  # High-DPI console
  console.font =
    lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  environment.systemPackages = with pkgs; [
    qjackctl
    libjack2
    guitarix
    lingot
    mpc_cli
    carla
    jack2
    blender
    nvtop
    factorio
  ];
}
