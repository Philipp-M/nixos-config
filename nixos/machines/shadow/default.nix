{ config, lib, pkgs, ... }:

{
  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "nixos-config=/home/philm/dev/personal/dotfiles/nixos/machines/shadow"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  imports = [ ./hardware-configuration.nix ../../configuration.nix ];

  boot.supportedFilesystems = [ "zfs" ];

  networking.hostId = "4ae8e232";
  networking.hostName = "shadow";

  hardware.enableRedistributableFirmware = true;

  networking.interfaces.enp3s0.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  nix.maxJobs = lib.mkDefault 8;
}
