{ config, lib, pkgs, ... }:

{
  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "nixos-config=/home/philm/dev/personal/dotfiles/machines/zen"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix

    (
      import (
        builtins.fetchGit {
          url = "https://github.com/musnix/musnix.git";
          ref = "master";
          rev = "f5053e85b0a578a335a78fa45517a8843154f46b";
        }
      )
    )
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
  services.sanoid = let
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

  musnix = {
    enable = true;

    kernel.optimize = true;

    alsaSeq.enable = false;

    rtirq = {
      # highList = "snd_hrtimer";
      resetAll = 1;
      prioLow = 0;
      enable = true;
      nameList = "rtc0 snd";
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
      Option "metamodes" "DP-2: nvidia-auto-select +0+0 { ForceFullCompositionPipeline=On }, DP-4: nvidia-auto-select +3840+0 { ForceFullCompositionPipeline=On }"
      Option "SLI" "Off"
      Option "MultiGPU" "Off"
      Option "BaseMosaic" "off"
    '';
    videoDrivers = [ "nvidia" ];
  };

  users.users.philm.extraGroups = [ "jackaudio" ];

  services.borgbackup.jobs.home = {
    paths = "/home";
    encryption.mode = "none";
    repo = "/tank/backup/zen/home";
    compression = "none";
    startAt = "00/1:00";
    exclude = [
      "/home/philm/dev/*/rust/*/target"
      "/home/philm/dev/**/node_modules"
      "/home/philm/Downloads"
      "/home/philm/.cache"
    ];

    prune.keep = {
      within = "1d"; # Keep all archives from the last day
      daily = 7;
      weekly = 4;
      monthly = -1; # Keep at least one archive for each month
    };
  };

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
