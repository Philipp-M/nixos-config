{ config, lib, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ../../configuration.nix ];

  nix.settings.max-jobs = lib.mkDefault 8;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = false;
  hardware.enableRedistributableFirmware = true;

  networking = {
    hostId = "4ae8e232";
    hostName = "shadow";
    interfaces.enp3s0.useDHCP = true;
    interfaces.wlp4s0.useDHCP = true;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    # networkmanager.dns = "none";
    networkmanager.enable = true;
  };

  services.xserver.videoDrivers = [ "intel" ];
  services.xserver.deviceSection = ''
    Option "DRI" "2"
    Option "TearFree" "true"
  '';

  hardware.opengl.extraPackages = with pkgs; [
    intel-media-driver # LIBVA_DRIVER_NAME=iHD
    vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
    vaapiVdpau
    libvdpau-va-gl
  ];
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ vaapiIntel ];

  services.kanata.keyboards.default.devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];

  services.thermald.enable = true;

  home-manager.users.philm.services.cbatticon = {
    enable = true;
    commandCriticalLevel = ''notify-send "battery critical!"'';
  };
  home-manager.users.philm.services.xembed-sni-proxy.enable = true;
  home-manager.users.philm.programs.mpv.config.profile = lib.mkForce "gpu-low";
}
