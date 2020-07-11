{ config, lib, pkgs, ... }:

{
  nix.nixPath = [
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "nixos-config=/home/philm/dev/personal/dotfiles/nixos/machines/office"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  imports = [ ./hardware-configuration.nix ../../configuration.nix ];

  networking.hostName = "WS02";

  hardware.enableRedistributableFirmware = true;

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp5s0.useDHCP = false;

  boot.kernelParams = [ "nomodeset" "pci=nomsi" ];

  virtualisation.docker.enableNvidia = true;

  services.xserver = {
    dpi = 110;
    screenSection = ''
      DefaultDepth 24
      Option "RegistryDwords" "PerfLevelSrc=0x3322; PowerMizerDefaultAC=0x1"
      Option "TripleBuffer" "True"
      Option "Stereo" "0"
      Option "nvidiaXineramaInfoOrder" "DP-0, DP-2"
      Option "metamodes" "DP-0: nvidia-auto-select +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, DP-2: nvidia-auto-select +3840+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
      Option "SLI" "Off"
      Option "MultiGPU" "Off"
      Option "BaseMosaic" "off"
    '';
    videoDrivers = [ "nvidia" ];
  };

  nix.maxJobs = lib.mkDefault 12;
  # High-DPI console
  console.font =
    lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
}
