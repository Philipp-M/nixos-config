{ config, lib, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ../../configuration.nix ../../secrets/nix-expressions/office.nix ];

  networking.hostName = "WS02";

  hardware.enableRedistributableFirmware = true;

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp5s0.useDHCP = false;
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "none";

  boot.kernelParams = [ "nomodeset" "pci=nomsi" ];

  virtualisation.docker.enableNvidia = true;

  services.xserver = {
    dpi = 110;
    screenSection = ''
      DefaultDepth 24
      Option "RegistryDwords" "PerfLevelSrc=0x3322; PowerMizerDefaultAC=0x1"
      Option "TripleBuffer" "True"
      Option "Stereo" "0"
      Option "nvidiaXineramaInfoOrder" "DP-4, DP-2"
      Option "metamodes" "DP-4: nvidia-auto-select +0+0 { ForceFullCompositionPipeline=On }, DP-2: nvidia-auto-select +3840+0 { ForceFullCompositionPipeline=On }"
      Option "SLI" "Off"
      Option "MultiGPU" "Off"
      Option "BaseMosaic" "off"
    '';
    videoDrivers = [ "nvidia" ];
  };

  nix.maxJobs = lib.mkDefault 12;
  # High-DPI console
  console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  # overwrite update/upgrade, since the hostname is different
  home-manager.users.philm.programs.fish.shellAliases = {
    upgrade = lib.mkForce "nix flake update /home/philm/dev/personal/dotfiles/ && sudo nixos-rebuild switch --flake /home/philm/dev/personal/dotfiles/#office";
    update = lib.mkForce "sudo nixos-rebuild switch --flake /home/philm/dev/personal/dotfiles/#office";
  };
}
