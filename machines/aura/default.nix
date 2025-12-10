{ config, lib, pkgs, modulesPath, ... }:
let
  persistent = "/persistent";
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ../../configuration.nix ];

  nix.settings.max-jobs = lib.mkDefault 4;

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    opengl = {
      extraPackages = with pkgs; [
        intel-media-driver
        libvdpau-va-gl
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ intel-media-driver ];
    };
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  networking = {
    hostId = "4f842b6c";
    hostName = "aura";
    interfaces.wlp0s20f3.useDHCP = true;
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    # networkmanager.dns = "none";
    networkmanager.enable = true;
  };

  services.xserver.videoDrivers = [ "modesetting" ];
  services.xserver.deviceSection = ''
    Option "DRI" "2"
    Option "TearFree" "true"
  '';

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  fileSystems = {
    "${persistent}" = {
      device = "/dev/disk/by-uuid/0dd94b8f-2cb0-40cc-b444-e301efe30f12";
      fsType = "xfs";
      neededForBoot = true;
    };
    # impermanence tries to unmount /nix, thus manually bind mount it here
    "/nix" = {
      device = "${persistent}/nix/";
      options = [ "bind" ];
      depends = [ "${persistent}" ];
      neededForBoot = true;
    };
    "/boot" = { device = "/dev/disk/by-uuid/CB84-48C8"; fsType = "vfat"; };
    # root on tmpfs
    "/" = { device = "none"; fsType = "tmpfs"; options = [ "defaults" "size=32G" "mode=755" ]; };
  };

  # persistent state

  environment.persistence."${persistent}" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/blueman"
      "/var/lib/cups/ppd"
      "/var/lib/bluetooth"
      "/var/lib/systemd/coredump"
      "/var/lib/docker"
      "/var/lib/snapd"
      "/var/lib/snap"
      "/var/snap"
      "/snap"
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
    users.philm = {
      directories = [
        "dev"
        # tmp folder, persistent, but not backed up
        "tmp"
        "wallpaper"
        "Screenshots"
        "windows-11"
        "Downloads"
        "Desktop"
        "Pictures"
        "Documents"
        "Videos"
        "Audio"
        "VirtualBox VMs"
        "Bitwig Studio"
        "SteamLibrary"
        "Calibre Library"
        "Unity"
        "Android"
        "Arduino"
        "ollama"
        "snap"
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
        ".config/REAPER"
        ".config/Ryujinx"
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
        ".cache/nvidia" # avoid unnecessary computation
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
      files = [
        ".cache/helix/helix.log"
        ".npmrc"
        ".netrc"
      ];
    };
  };

  services.kanata.keyboards.default.devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];

  services.openssh.hostKeys = [
    { path = "${persistent}/etc/ssh/ssh_host_rsa_key"; bits = 4096; type = "rsa"; }
    { path = "${persistent}/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
  ];

  services.thermald.enable = true;
  services.upower.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };


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

