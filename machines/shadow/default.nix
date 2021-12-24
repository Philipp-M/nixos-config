{ config, lib, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ../../configuration.nix ];

  nix.maxJobs = lib.mkDefault 8;

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


  services.thermald.enable = true;

  home-manager.users.philm.services.cbatticon = {
    enable = true;
    commandCriticalLevel = ''notify-send "battery critical!"'';
  };
  home-manager.users.philm.services.xembed-sni-proxy.enable = true;
  home-manager.users.philm.programs.mpv.config.profile = lib.mkForce "gpu-low";
}
