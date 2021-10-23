{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix
  ];

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
  hardware.pulseaudio.daemon.config = {
    default-sample-format = "s32le";
    default-sample-rate = 44100;
    avoid-resampling = "yes";
  };

  networking.interfaces.enp38s0.useDHCP = true;
  networking.interfaces.enp39s0.useDHCP = true;
  networking.interfaces.wlo1.useDHCP = true;

  virtualisation.docker.enableNvidia = true;

  # ZFS related
  services.zfs.autoScrub.enable = true;
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

  services = {
    syncthing = {
      enable = true;
      user = "philm";
      dataDir = "/home/philm/";
      configDir = "/home/philm/.config/syncthing";
    };
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      # TODO use systemd service instead of cronjob?
      "7 * * * *      root    ${pkgs.writeScript "backup-home" ''
        #!/usr/bin/env bash
        echo "" >> /var/log/home-backup.log
        echo "" >> /var/log/home-backup.log
        echo "Starting Backup at $(date)" >> /var/log/home-backup.log
        rsync --delete -av --filter=':- .gitignore' --filter=':- .npmignore' --filter=':- .ignore' /home/ /tank/backup/zen/home/ 2>&1  >> /var/log/home-backup.log
      '' }"
    ];
  };

  services.xserver = {
    dpi = 110;
    screenSection = ''
      DefaultDepth 24
      Option "RegistryDwords" "PerfLevelSrc=0x3322; PowerMizerDefaultAC=0x1"
      Option "TripleBuffer" "True"
      Option "Stereo" "0"
      Option "nvidiaXineramaInfoOrder" "DP-4, DP-2"
      Option "metamodes" "DP-2: nvidia-auto-select +0+0 { ForceFullCompositionPipeline=On }, DP-4: nvidia-auto-select +3840+0 { ForceFullCompositionPipeline=On }"
      Option "SLI" "Off"
      Option "MultiGPU" "Off"
      Option "BaseMosaic" "off"
    '';
    videoDrivers = [ "nvidia" ];
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    modesetting.enable = true;
  };

  users.users.philm.extraGroups = [ "jackaudio" ];

  home-manager.users.philm.services.mpd = {
    enable = true;
    musicDirectory = "~/Music";
    extraConfig = ''
      audio_output {
              type            "pulse"
              name            "pulse audio"
      }
      playlist_plugin {
          name "cue"
          enabled "false"
      }
    '';
  };

  nix.maxJobs = lib.mkDefault 16;
  # High-DPI console
  console.font =
    lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  environment.systemPackages = with pkgs; [ qjackctl libjack2 jack2 ];
}
