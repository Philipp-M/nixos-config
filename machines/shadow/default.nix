{ config, lib, pkgs, modulesPath, ... }:
let
  persistent = "/persistent";
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ../../configuration.nix ];

  nix.settings.max-jobs = lib.mkDefault 4;

  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs.requestEncryptionCredentials = false;
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "ata_piix" "uas" "sd_mod" "rtsx_pci_sdmmc" ];
    kernelModules = [ "kvm-intel" ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    opengl = {
      extraPackages = with pkgs; [
        intel-media-driver # LIBVA_DRIVER_NAME=iHD
        vaapiIntel # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        vaapiVdpau
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ vaapiIntel ];
    };
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  networking = {
    hostId = "4ae8e232";
    hostName = "shadow";
    interfaces.enp2s0.useDHCP = true;
    interfaces.wlp3s0.useDHCP = true;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    # networkmanager.dns = "none";
    networkmanager.enable = true;
  };

  services.xserver.videoDrivers = [ "intel" ];
  services.xserver.deviceSection = ''
    Option "DRI" "2"
    Option "TearFree" "true"
  '';

  fileSystems = {
    ${persistent} = {
      device = "rpool/persistent";
      fsType = "zfs";
      neededForBoot = true;
    };
    "/home-persistent" = {
      device = "rpool/safe/home";
      fsType = "zfs";
      neededForBoot = true;
    };
    # root on tmpfs
    "/" = { device = "none"; fsType = "tmpfs"; options = [ "defaults" "size=8G" "mode=755" ]; };
    "/nix" = {
      device = "rpool/local/nix";
      fsType = "zfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/00F8-62D4";
      fsType = "vfat";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/e1408d0d-f5c2-424b-8e00-67e6d7e6c454"; }
    { device = "/dev/disk/by-uuid/70f599a3-fdca-419d-8283-6dac988f0dd1"; }
  ];

  environment.persistence."/home-persistent" = {
    hideMounts = true;
    users.philm = {
      directories = [
        "dev"
        "wallpaper"
        "screenshots"
        "windows-11"
        "Downloads"
        "Desktop"
        "Pictures"
        "Documents"
        "Music"
        "Videos"
        "Audio"
        "VirtualBox VMs"
        "Bitwig Studio"
        "SteamLibrary"
        "Calibre Library"
        "Unity"
        "Arduino"
        { directory = ".gnupg"; mode = "0700"; }
        { directory = ".ssh"; mode = "0700"; }
        { directory = ".local/share/keyrings"; mode = "0700"; }
        ".config/calibre"
        ".config/cantata"
        ".config/Cantata"
        ".config/chromium"
        ".config/google-chrome"
        ".config/cosmic"
        ".config/dconf"
        ".config/discord"
        ".config/easyeffects"
        ".config/Element"
        ".config/gtk-2.0"
        ".config/gtk-3.0"
        ".config/gtk-4.0"
        ".config/kdeconnect"
        ".config/qBittorrent"
        ".config/Signal"
        ".config/syncthing"
        ".config/yabridgectl"
        ".config/FreeCAD"
        ".config/gh"
        ".config/heroic"
        ".config/Google"
        ".config/Slack"
        ".config/BraveSoftware"
        ".config/Renoise"
        ".config/loopers"
        ".config/tree-sitter"
        ".config/obs-studio"
        ".config/chatgpt"
        ".local/share/mpd"
        ".local/share/rofi"
        ".local/share/flatpak"
        ".local/share/zathura"
        ".local/share/nix"
        ".local/share/qBittorrent"
        ".local/share/Steam"
        ".local/share/cantata"
        ".local/share/fish"
        ".local/share/zoxide"
        ".local/share/chatgpt"
        ".local/share/TelegramDesktop"
        ".local/share/Midinous"
        ".local/state/wireplumber"
        ".local/state/cosmic-comp"
        ".BitwigStudio"
        ".cache/nix" # avoid unnecessary fetching
        ".cache/Google" # Android studio takes a long time otherwise
        ".cache/cantata" # avoid redownloading covers
        ".cache/pop-launcher"
        ".cache/fontconfig"
        ".gradle"
        ".android"
        ".var/app"
        ".vst"
        ".vst3"
        ".gnome"
        ".steam"
        ".cargo"
        ".mozilla"
        ".thunderbird"
        ".wine"
        ".xmonad"
      ];
      files = [ ".cache/helix/helix.log" ".npmrc" ];
    };
  };

  environment.persistence.${persistent} = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/blueman"
      "/var/lib/cups/ppd"
      "/var/lib/bluetooth"
      "/var/lib/systemd/coredump"
      "/var/lib/docker"
      "/var/lib/teamviewer"
      "/var/lib/NetworkManager"
      "/var/lib/flatpak"
      "/var/lib/vnstat"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/var/lib/cups/subscriptions.conf"
      "/var/lib/cups/printers.conf"
    ];
  };

  services.kanata.keyboards.default.devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];

  services.openssh.hostKeys = [
    { path = "${persistent}/etc/ssh/ssh_host_rsa_key"; bits = 4096; type = "rsa"; }
    { path = "${persistent}/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
  ];

  # ZFS related
  services.zfs.autoScrub.enable = true;
  services.sanoid =
    let
      # templates not working correctly because of kinda broken sanoid config
      # (default values, which aren't overwritten by templates)
      default-dataset = {
        daily = 7;
        hourly = 48;
        monthly = 5;
        yearly = 0;
      };
      default-settings = {
        frequent_period = 2;
        frequently = 60;
      };
    in
    {
      enable = true;
      interval = "minutely";
      settings = {
        "rpool/safe/root" = default-settings;
        "rpool/safe/home" = default-settings;
      };
      datasets = {
        "rpool/safe/root" = default-dataset;
        "rpool/safe/home" = default-dataset;
      };
    };

  services.thermald.enable = true;
  services.upower.enable = true;

  users = let philm-password = builtins.readFile ../../secrets/philm-password; in {
    mutableUsers = false;
    users.philm.initialHashedPassword = philm-password;
    users.root.initialHashedPassword = philm-password;
  };

  home-manager.users.philm.services.cbatticon = {
    enable = true;
    commandCriticalLevel = ''notify-send "battery critical!"'';
  };
  home-manager.users.philm.services.xembed-sni-proxy.enable = true;
  home-manager.users.philm.programs.mpv.config.profile = lib.mkForce "gpu-low";
}
