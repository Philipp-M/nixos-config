{ config, lib, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ../../configuration.nix ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = false;

  networking.hostId = "4ae8e232";
  networking.hostName = "shadow";

  hardware.enableRedistributableFirmware = true;

  networking.interfaces.enp3s0.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  nix.maxJobs = lib.mkDefault 8;
}
