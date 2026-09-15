{ config, lib, pkgs, modulesPath, ... }:
let
  persistent = "/persistent";
  realityscan-unwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "realityscan-unwrapped";
    version = "2.1.1.1";

    src = pkgs.requireFile {
      name = "RealityScan-2.1.1.deb";
      sha256 = "sha256-2ClHuaPkQr1l5D/Y2kXDotp4ENAl2o30U+b3vZAoI3U=";
      message = ''
        Add RealityScan-2.1.1.deb to the Nix store with:

          nix-store --add-fixed sha256 RealityScan-2.1.1.deb
      '';
    };

    nativeBuildInputs = [ pkgs.dpkg ];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a opt usr $out/
      runHook postInstall
    '';

    dontFixup = true;
  };

  realityscan = pkgs.buildFHSEnv {
    pname = "realityscan";
    version = realityscan-unwrapped.version;
    executableName = "realityscan-cli";
    runScript = "/opt/realityscan/bin/realityscan-cli";

    extraBuildCommands = ''
      mkdir -p $out/opt/realityscan
    '';

    extraBwrapArgs = [
      "--ro-bind"
      "${realityscan-unwrapped}/opt/realityscan"
      "/opt/realityscan"
    ];

    profile = ''
      export CX_ROOT=/opt/realityscan
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    '';

    targetPkgs = pkgs: with pkgs; [
      alsa-lib
      cups
      dbus
      desktop-file-utils
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gnutls
      gst_all_1.gst-plugins-base
      gst_all_1.gstreamer
      gtk3
      krb5
      liberation_ttf
      libgphoto2
      libglvnd
      libpcap
      libpulseaudio
      libunwind
      libusb1
      libxkbcommon
      ocl-icd
      openssl
      pango
      pcsclite
      perl
      python3
      python3Packages.dbus-python
      python3Packages.pycairo
      python3Packages.pygobject3
      sensible-utils
      systemd
      vte
      vulkan-loader
      xdg-utils
      libx11
      libxcomposite
      libxcursor
      libxext
      libxfixes
      libxi
    ];
  };
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../configuration.nix
  ];

  nixpkgs.overlays = import ../../secrets/nix-expressions/zen-overlays.nix;

  hardware = {
    cpu.amd.updateMicrocode = true;
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    xpadneo.enable = true;
    nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaPersistenced = true;
      forceFullCompositionPipeline = true;
    };
    nvidia-container-toolkit.enable = true;
  };

  virtualisation.docker.enableNvidia = true;
  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "sd_mod" ];
    kernel.sysctl."vm.swappiness" = lib.mkForce 1;
    kernel.sysctl."vm.vfs_cache_pressure" = 200;
    kernelParams = [
      "nordrand"
      "amd_iommu=fullflush"
      "preempt=full"
      "initcall_blacklist=simpledrm_platform_driver_init"
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "pcie_port_pm=off"
    ];
    supportedFilesystems = [ "ntfs" "zfs" ];
    zfs.requestEncryptionCredentials = false;
    zfs.package = pkgs.zfs_unstable;
    zfs.forceImportRoot = true;
    # kernelPackages = pkgs.linuxPackages_6_1;
    extraModulePackages = [ config.boot.kernelPackages.zenpower ];
    kernelModules = [ "kvm-amd" "snd-seq" "snd-rawmidi" "snd-virmidi" ];
    blacklistedKernelModules = [ "snd-pcsp" "snd-hda-intel" ]; # don't use anything else than the audio interface, this just adds up noise...
    loader.systemd-boot.consoleMode = "max";
    # Bluetooth
    extraModprobeConfig = ''
      options bluetooth disable_ertm=1
      options zfs l2arc_noprefetch=0 l2arc_write_boost=33554432 l2arc_write_max=16777216 zfs_arc_min=0 zfs_arc_max=2147483648
    '';
  };

  # optimize kernel for low-latency audio
  powerManagement.cpuFreqGovernor = "performance";
  musnix.enable = true;

  # disk configuration
  # root on tmpfs and persistence via impermanence

  fileSystems = {
    "${persistent}" = {
      device = "/dev/disk/by-uuid/380825df-720f-4f14-bf5e-cf448c723131";
      fsType = "xfs";
      neededForBoot = true;
    };
    # impermanence tries to unmount /nix, thus manually bind mount it here
    "/nix" = {
      device = "${persistent}/nix/";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "${persistent}" ];
      neededForBoot = true;
    };
    "/boot" = { device = "/dev/disk/by-uuid/90D9-9D03"; fsType = "vfat"; };
    # impermanence doesn't support yet direct bind mounts (without the path prefix on the persistent device)
    "/home/philm/Music" = { device = "/tank/media/Music"; fsType = "none"; options = [ "bind" ]; depends = [ "/tank/media" ]; };
    "/data/games" = { device = "data/games"; fsType = "zfs"; neededForBoot = true; };
    "/data/media" = { device = "data/media"; fsType = "zfs"; };
    "/data/backup" = { device = "data/backup"; fsType = "zfs"; };
    "/data/audio" = { device = "data/audio"; fsType = "zfs"; };
    "/data/photos" = { device = "data/photos"; fsType = "zfs"; };
    "/tank/media" = { device = "tank/media"; fsType = "zfs"; neededForBoot = true; };
    "/home/philm/Photos" = { device = "/data/photos"; fsType = "none"; options = [ "bind" ]; depends = [ "/data/photos" ]; };
    # root on tmpfs
    "/" = { device = "none"; fsType = "tmpfs"; options = [ "defaults" "size=64G" "mode=755" ]; };
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
      "/var/lib/ollama"
      "/var/lib/llama-cpp"
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
        ".codex"
        ".config/blender"
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
        ".config/opencode"
        ".config/zed"
        ".config/StardewValley"
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
        ".nvidia-settings-rc"
        ".netrc"
      ];
    };
  };

  swapDevices = [{ device = "/dev/disk/by-uuid/c44661f2-5dfb-4f7d-854e-4d3ebd4eabdd"; }];

  networking = {
    hostId = "80e43ffd";
    hostName = "zen";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
    networkmanager = {
      enable = true;
      dns = "none";
    };
    interfaces = {
      enp38s0.useDHCP = true;
      enp39s0.useDHCP = true;
      wlo1.useDHCP = false;
    };
  };

  services.samba = {
    enable = true;
    nsswins = true;
    winbindd.enable = true;
  };

  # disable virtualbox as it has problems with the rt kernel
  virtualisation.virtualbox.host.enable = lib.mkForce false;
  virtualisation.spiceUSBRedirection.enable = true;

  services.openssh.hostKeys = [
    { path = "${persistent}/etc/ssh/ssh_host_rsa_key"; bits = 2048; type = "rsa"; }
    { path = "${persistent}/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
  ];

  services.kanata.keyboards.default.devices = [
    "/dev/input/by-id/usb-Falbatech_The_Redox_Keyboard-event-kbd" # redox keyboard
    "/dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse" # mouse
    "/dev/input/by-id/usb-Gaming_KB_Gaming_KB-event-kbd"
  ];

  users = let philm-password = builtins.readFile ../../secrets/philm-password; in {
    mutableUsers = false;
    users.philm = {
      initialHashedPassword = philm-password;
      extraGroups = [ "jackaudio" "lpadmin" ];
    };
    users.root.initialHashedPassword = philm-password;
  };

  services.blueman.enable = true;

  services.voiceControl = {
    enable = true;
    user = "philm";

    midi = {
      port = "Ampero Control";
      commandNote = 48;
      germanNote = 50;
      enterNote = 52;
      dictationNote = 53;
    };

    whisperCommand = {
      pollMs = 40;
      audioMs = 600;
      vadMs = 100;
      startupMs = 0;
    };

    commands = {
      default = {
        left = "${pkgs.niri-unstable}/bin/niri msg action focus-column-left";
        right = "${pkgs.niri-unstable}/bin/niri msg action focus-column-right";
        up = "${pkgs.niri-unstable}/bin/niri msg action focus-window-or-workspace-up";
        down = "${pkgs.niri-unstable}/bin/niri msg action focus-window-or-workspace-down";
        launch = "${pkgs.niri-unstable}/bin/niri msg action spawn -- \"rofi\" \"-show\" \"run\"";
        enter = "key enter";

        overview = "${pkgs.niri-unstable}/bin/niri msg action toggle-overview";
        firefox = "focus_app firefox";

        maximize = "${pkgs.niri-unstable}/bin/niri msg action maximize-window-to-edges";
        fullscreen = "${pkgs.niri-unstable}/bin/niri msg action fullscreen-window";

        copy = "key ctrl+c";
        paste = "key ctrl+v";

        play = "key x:XF86AudioPlay";
        pause = "key x:XF86AudioPause";
      };

      modes = {
        overview = {
          priority = 100;
          match.overview = true;

          commands = {
            left = "${pkgs.niri-unstable}/bin/niri msg action focus-column-left";
            right = "${pkgs.niri-unstable}/bin/niri msg action focus-column-right";
            up = "${pkgs.niri-unstable}/bin/niri msg action focus-workspace-up";
            down = "${pkgs.niri-unstable}/bin/niri msg action focus-workspace-down";
          };
        };

        rofi = {
          priority = 90;

          match = {
            overview = false;
            layerNamespace = "^rofi$";
          };

          commands = {
            abort = "key esc";
          };
        };

        terminal = {
          priority = 60;

          match = {
            overview = false;
            appId = "kitty|foot|alacritty|wezterm|ghostty";
          };

          commands = {
            copy = "key ctrl+shift+c";
            paste = "key ctrl+shift+v";
          };
        };

        helix = {
          priority = 80;

          match = {
            overview = false;
            process = "^(hx|helix).*";
          };

          commands = {
            insert = "key esc; key i";
            undo = "key esc; key u";
            redo = "key esc; key shift+u";
            escape = "key esc";
            "select all" = "key esc; key shift+5";

            goto = "key esc; key g; key t";
            "go to" = "key esc; key g; key t";
            "go-to" = "key esc; key g; key t";

            up = "key esc; key ctrl+u";
            down = "key esc; key ctrl+d";
          };
        };

        firefox = {
          priority = 50;

          match = {
            overview = false;
            appId = "firefox";
          };

          commands = {
            back = "key alt+left";
            forward = "key alt+right";
            next = "key ctrl+tab";
            previous = "key ctrl+shift+tab";
            reload = "key ctrl+s";
            new = "key ctrl+f";
            close = "key ctrl+w";
          };
        };
      };
    };

    dictation = {
      enableLlm = false;

      transforms = [
        {
          name = "nix-command";
          pattern = ''(?i)^\s*(?:nicks|nyx|nixs)(\s|$)'';
          replace = "nix$1";
        }
        {
          name = "hx-command";
          pattern = ''(?i)^\s*(?:h\s*x|h ex)(\s|$)'';
          replace = "hx$1";
        }
        {
          name = "htop-command";
          pattern = ''(?i)^\s*(?:h\s*top|age top)(\s|$)'';
          replace = "htop$1";
        }
        {
          name = "nvtop-command";
          pattern = ''(?i)^\s*(?:n\s*v\s*top|envy top)(\s|$)'';
          replace = "nvtop$1";
        }
        {
          name = "rg-command";
          pattern = ''(?i)^\s*(?:r\s*g|are gee)(\s|$)'';
          replace = "rg$1";
        }
        {
          name = "fd-command";
          pattern = ''(?i)^\s*(?:f\s*d|eff dee)(\s|$)'';
          replace = "fd$1";
        }
        {
          name = "jaq-command";
          pattern = ''(?i)^\s*(?:jack|jac|jay cue)(\s|$)'';
          replace = "jaq$1";
        }
        {
          name = "short-input";
          pattern = ''(?s)^\s*(\S+(?:\s+\S+){0,3})\s*$'';
          replace = "$1";
          lowercaseFirst = true;
          trimEndPunctuation = true;
        }
      ];

      modes = {
        codex = {
          priority = 85;
          match = {
            overview = false;
            process = "^(codex|codex-cli)$";
          };
          transforms = [
            {
              name = "slash-command";
              pattern = ''(?i)^\s*(status|usage|model|permissions|review|compact|diff|mention|mcp|skills|apps|plugins|help|new|resume|fork|init|feedback|logout|quit)[.!?]?\s*$'';
              replace = "/$1\n";
              lowercase = true;
            }
          ];
        };

        helix = {
          priority = 80;
          match = {
            overview = false;
            process = "^(hx|helix)$";
          };
          transforms = [
            {
              name = "insert-mode";
              pattern = ''(?i)^\s*insert[.!?]?\s*$'';
              replace = "\\k{esc}i";
            }
            {
              name = "append-mode";
              pattern = ''(?i)^\s*append[.!?]?\s*$'';
              replace = "\\k{esc}a";
            }
            {
              name = "goto";
              pattern = ''(?i)^\s*(?:goto|go[ -]?to)[.!?]?\s*$'';
              replace = "\\k{esc}gt";
            }
            {
              name = "search";
              pattern = ''(?i)^\s*(?:find|search)\s+(.+?)\s*$'';
              replace = "\\k{esc}/$1";
            }
            {
              name = "open-search";
              pattern = ''(?i)^\s*(?:find|search)[.!?]?\s*$'';
              replace = "\\k{esc}/";
            }
          ];
        };

        firefox = {
          priority = 50;
          match = {
            overview = false;
            appId = "firefox";
          };
          transforms = [
            {
              name = "find";
              pattern = ''(?i)^\s*(?:find|search)\s+(.+?)\s*$'';
              replace = "\\k{ctrl+e}\\w{150}$1";
            }
            {
              name = "open-find";
              pattern = ''(?i)^\s*(?:find|search)[.!?]?\s*$'';
              replace = "\\k{ctrl+e}\\w{150}";
            }
          ];
        };
      };
    };

    llmContext = {
      default = ''
        Preserve the speaker's language and wording.
        Never translate.
        Correct only likely speech-recognition errors.
      '';

      modes = {
        overview = {
          priority = 100;
          match.overview = true;

          context = ''
            The user is interacting with the niri overview.
            Terms are likely related to windows, workspaces and applications.
          '';
        };
        terminal = {
          priority = 50;

          match = {
            overview = false;
            appId = "kitty|foot|alacritty|wezterm|ghostty";
          };

          context = ''
            The focused application is a terminal.

            Prefer interpreting ambiguous speech as common shell commands, Unix utilities,
            development tools, Nix/NixOS commands, Rust tooling, Git commands and identifiers.

            Commands and tools commonly intended include:
            hx
            z
            cd
            ls
            pwd
            mkdir
            rm
            mv
            cp
            ln
            cat
            less
            tail
            watch
            find
            fd
            rg
            grep
            sed
            awk
            jaq
            curl
            wget
            ssh
            scp
            rsync
            htop
            nvtop
            systemctl
            journalctl
            dmesg
            ps
            kill
            pkill
            cargo
            cargo check
            cargo build
            cargo run
            cargo test
            cargo watch
            rustc
            rustup
            nix
            nix build
            nix develop
            nix shell
            nix run
            nix log
            nix flake
            nix flake check
            nix flake update
            nixos-rebuild
            deploy
            git
            git status
            git diff
            git add
            git commit
            git push
            git pull
            git fetch
            git switch
            git checkout
            git rebase
            git log
            niri
            niri msg
            whisrs
            aseqdump
            llama-server

            In particular:
            - "H X", "H ex", or similar likely means "hx".
            - "H top" likely means "htop".
            - "NV top", "N V top", or similar likely means "nvtop".
            - "R G" likely means "rg".
            - "F D" likely means "fd".
            - "JAC", "jack", or similar may mean "jaq" when used as a shell command.
            - "Z <name>" or "zee <name>" or "c <name>"  likely means the zoxide command "z <name>".
            - Preserve flags beginning with "-" or "--".
            - Preserve paths, filenames, package names, Git branches and Rust identifiers.
            - Prefer lowercase command names.
            - Do not expand a short command into explanatory prose.
          '';
        };

        codex = {
          priority = 85;
          match = {
            overview = false;
            process = "^(codex|codex-cli)$";
          };

          context = "The user is dictating into Codex.";
        };

        helix = {
          priority = 80;
          match = {
            overview = false;
            process = "^(hx|helix)$";
          };

          context = ''
            The user is editing text or source code in Helix.
            Prefer exact technical terminology, identifiers, filenames,
            programming-language syntax and capitalization.
            Do not rewrite code-like text into natural prose.
          '';
        };

        rofi = {
          priority = 90;
          match.layerNamespace = "^rofi$";

          context = ''
            The user is interacting with the Rofi application launcher.
            The transcription may contain application names, executable names
            or short search terms.
          '';
        };

        firefox = {
          priority = 50;
          match = {
            overview = false;
            appId = "firefox";
          };

          context = ''
            The user is in Firefox.
            The transcription may contain website names, URLs, search terms
            or text intended for a web page.
          '';
        };
      };
    };
  };

  services.pipewire = {
    extraConfig = {
      pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 192000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 8192;
        };
        "context.modules" = [
          {
            "name" = "libpipewire-module-rt";
            "args" = {
              "rt.prio" = 88;
              "rlimits.enabled" = true;
              "rtportal.enabled" = true;
              "rtkit.enabled" = true;
            };
            "flags" = [ "ifexists" "nofail" ];
          }
          { "name" = "libpipewire-module-portal"; }
          { "name" = "libpipewire-module-spa-node-factory"; }
          { "name" = "libpipewire-module-link-factory"; }
        ];
      };
      jack."92-low-latency" = {
        "jack.properties" = {
          "rt.prio" = 88;
          "node.latency" = "1024/192000";
          "jack.show-monitor" = true;
          "jack.merge-monitor" = true;
          "jack.show-midi" = true;
          "jack.fix-midi-events" = true;
        };
      };
    };

    wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/50-ultralite-pro-audio-176khz-alsa.conf" ''
        monitor.alsa.rules = [ {
          matches = [ { device.name = "alsa_card.usb-MOTU_UltraLite-mk5_UL5LFF562C-00" } ]
          actions = {
            update-props = {
              api.alsa.use-acp = true,
              api.alsa.use-ucm = false,
              api.alsa.period-size = 1024,
              api.acp.probe-rate = 192000,
              api.acp.auto-profile = false
              api.acp.pro-channels = 10,
              device.profile = "pro-audio"
            }
          }
        } ]
      '')
    ];
  };

  # ZFS related
  services.zfs.autoScrub = {
    interval = "Sun *-*-01..07 02:00:00";
    enable = true;
  };
  services.sanoid =
    let
      # templates not working correctly because of kinda broken sanoid config
      # (default values, which aren't overwritten by templates)
      default = {
        daily = 7;
        hourly = 1000; # > one month hourly snapshots
        monthly = 5;
        yearly = 0;
        # frequently
        # TODO with ssd enable this again including the hourly...
        # settings = {
        #   frequent_period = 15;
        #   frequently = 8;
        # };
      };
    in
    {
      enable = true;
      datasets."data/private" = default;
      datasets."data/backup" = default;
      datasets."data/games" = default;
      datasets."data/photos" = default;
      datasets."data/music" = default;
    };

  services.syncthing = {
    enable = true;
    user = "philm";
    dataDir = "/home/philm/";
    configDir = "/home/philm/.config/syncthing";
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [ hplip ];
  };
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
  programs.system-config-printer.enable = true;

  networking.hosts = { "127.0.0.1" = [ "syncthing" ]; };

  services.nginx.virtualHosts."syncthing".locations."/" = {
    proxyPass = "http://localhost:8384";
    proxyWebsockets = true;
  };

  # don't backup everything in persistent,
  # as not everything is important (over a long period) (i.e. cached things or logs),
  # but may litter the backup partition (many writes)
  systemd.services.backup-persistent = {
    description = "Backups (important stuff of) persistent partition with rsync";
    startAt = "*-*-* *:50:00";
    serviceConfig.Type = "simple";
    wantedBy = [ "multi-user.target" ];
    script = ''
      printf "Started Backup at $(date)\n" >> /var/log/backup-persistent.log
      ${pkgs.rsync}/bin/rsync \
        --delete \
        -av \
        --delete-excluded \
        --exclude /var/lib/systemd \
        --exclude /var/lib/docker \
        --exclude /var/log \
        --exclude /nix \
        --exclude /home/philm/Unity \
        --exclude /home/philm/.rustup \
        --exclude /home/philm/.cache \
        --exclude /home/philm/.cargo \
        --exclude /home/philm/.gradle \
        --exclude /home/philm/.android \
        --exclude /home/philm/.npmrc \
        --exclude /home/philm/.xmonad \
        --filter=':- .gitignore' \
        --filter=':- .npmignore' \
        --filter=':- .ignore' ${persistent}/ \
        /data/backup/zen/ 2>&1 >> /var/log/backup-persistent.log
      printf "Finished Backup at $(date)\n\n" >> /var/log/backup-persistent.log
    '';
  };

  systemd.services.hd-idle = {
    description = "HD spin down daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle -i 180 -c ata";
    };
  };

  services.xserver = {
    dpi = 110;
    videoDrivers = [ "nvidia" ];
    deviceSection = ''
      Option "TripleBuffer" "on"
    '';
  };

  home-manager.users.philm = {
    modules.mpd.enable = true;
    services.blueman-applet.enable = true;
    home.sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
    };
  };

  # reduce jobs, as otherwise a lot of swapping occurs (which I guess slows down the building process)
  nix.settings.max-jobs = lib.mkDefault 1;
  # High-DPI console
  console.font =
    lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";

  environment.systemPackages = with pkgs; [
    (import ../../secrets/nix-expressions/toggle-light.nix { inherit pkgs; })
    (import ../../secrets/nix-expressions/toggle-bright-light.nix { inherit pkgs; })
    qjackctl
    libjack2
    guitarix
    lingot
    mpc
    carla
    jack2
    blender
    nvidia-vaapi-driver
    # heroic
    arduino
    shntool
    flac
    cuetools
    # arduino-core
    arduino-cli
    nvtopPackages.full
    factorio
  ];
}
