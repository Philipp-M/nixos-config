{ config, lib, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ../../configuration.nix ../../secrets/nix-expressions/office.nix ];

  networking.hostName = "WS02";

  hardware = {
    enableRedistributableFirmware = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      open = false;
      modesetting.enable = true;
      powerManagement.enable = true;
      forceFullCompositionPipeline = true;
    };
    nvidia-container-toolkit.enable = true;
  };

  boot = {
    kernelParams = [
      "pci=nomsi"
      "nvidia_drm.fbdev=1"
      "nordrand"
      "preempt=full"
      "nomodeset"
      "nvidia.NVreg_EnableGpuFirmware=0"
      "initcall_blacklist=simpledrm_platform_driver_init"
    ];
    supportedFilesystems = [ "ntfs" ];
  };

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp5s0.useDHCP = false;
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
  networking.networkmanager.enable = true;
  # networking.networkmanager.dns = "none";

  services.kanata.keyboards.default.devices = [
    "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-kbd"
    # "/dev/input/by-id/usb-Logitech_USB_Keyboard-event-kbd"
    # "/dev/input/by-id/usb-Input_Club_Infinity_Ergodox_QMK-event-kbd" # ergodox infinity keyboard
    "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse" # mouse
  ];

  environment.systemPackages = with pkgs; [
    remmina
    (pkgs.callPackage ./claude-code/package.nix {})
  ];
  environment.etc."resolv.conf".text = ''
    nameserver 1.1.1.1
    nameserver 8.8.8.8
  '';

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
    deviceSection = ''
      Option "TripleBuffer" "on"
    '';
  };

  nix.settings.max-jobs = lib.mkDefault 12;
  # High-DPI console
  console.font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  home-manager.users.philm = {
    services.blueman-applet.enable = true;
    home.sessionVariables.LIBVA_DRIVER_NAME = "nvidia";
    programs.fish.shellAliases = {
      # overwrite update/upgrade, since the hostname is different
      upgrade = lib.mkForce "nix flake update /home/philm/dev/personal/dotfiles/ && nixos-rebuild switch --use-remote-sudo --flake /home/philm/dev/personal/dotfiles/#office";
      update = lib.mkForce "nixos-rebuild switch --use-remote-sudo --flake /home/philm/dev/personal/dotfiles/#office";
    };
  };
}
