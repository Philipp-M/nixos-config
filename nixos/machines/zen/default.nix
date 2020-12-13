{ config, lib, pkgs, ... }:

{
  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "nixos-config=/home/philm/dev/personal/dotfiles/nixos/machines/zen"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  imports = [
    ./hardware-configuration.nix
    ../../configuration.nix

    (import "${(builtins.fetchTarball {
      url =
        "https://github.com/musnix/musnix/archive/6c3f31772c639f50f893c25fb4ee75bb0cd92c98.tar.gz";
      sha256 = "07wwaxcilj2xi0j0a0kra1q65vb3ynddhxk72rvvnr9x144vqzvr";
    })}")
  ];

  boot.supportedFilesystems = [ "zfs" ];
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
      Option "nvidiaXineramaInfoOrder" "DP-2, DP-0"
      Option "metamodes" "DP-0: nvidia-auto-select +0+0 { ForceFullCompositionPipeline=On }, DP-2: nvidia-auto-select +3840+0 { ForceFullCompositionPipeline=On }"
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
  };

  home-manager.users.philm.systemd.user.services.jackdbus = {
    Unit = {
      Description = "JACK 2 with pulseeffects support";
      Requires = [ "dbus.socket" "pulseaudio.service" ];
      After = [ "pulseaudio.service" ];
    };

    Install = { WantedBy = [ "graphical-session.target" ]; };

    Service = with pkgs; {
      Type = "dbus";
      BusName = "org.jackaudio.service";

      ExecStartPre = "-${killall}/bin/killall -9 jackdbus";

      ExecStart = "${jack2}/bin/jackdbus auto";

      # ExecStartPost = ''
      ExecStartPost = [
        "${coreutils}/bin/sleep 1"
        "${jack2}/bin/jack_control ds alsa"
        "${jack2}/bin/jack_control dps device hw:USB"
        "${jack2}/bin/jack_control dps period 256"
        "${jack2}/bin/jack_control dps nperiods 2"
        "${jack2}/bin/jack_control dps rate 96000"
        "${jack2}/bin/jack_control dps midi-driver alsarawmidi"
        "${jack2}/bin/jack_control eps driver alsa"
        "${jack2}/bin/jack_control eps realtime True"
        "${jack2}/bin/jack_control eps realtime-priority 95"
        "${jack2}/bin/jack_control start"
        "-${pulseaudio}/bin/pacmd set-default-sink jack_out"
        "-${pulseaudio}/bin/pacmd set-default-source jack_in"
        "-${pulseaudio}/bin/pacmd suspend-sink jack_out 0"
        "-${pulseaudio}/bin/pacmd suspend-source jack_in 0"
      ];

      ExecStop = "${jack2}/bin/jack_control exit";

      ExecStopPost = [
        "-${killall}/bin/pacmd set-default-sink alsa_output.usb-Focusrite_Scarlett_2i4_USB-00.analog-surround-40"
        "-${killall}/bin/pacmd set-default-source alsa_input.usb-Focusrite_Scarlett_2i4_USB-00.analog-stereo"
      ];

      SuccessExitStatus = 0;
      RemainAfterExit = "yes";
    };
  };

  nix.maxJobs = lib.mkDefault 16;
  # High-DPI console
  console.font =
    lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  environment.systemPackages = with pkgs; [ qjackctl libjack2 jack2 ];
}
