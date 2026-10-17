# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    inputs.nix-snapd.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.musnix.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.agenix.nixosModules.age
    inputs.niri.nixosModules.niri
    # "${inputs.nixpkgs}/nixos/modules/services/desktops/pipewire/filter.nix"
    ./secrets/nix-expressions/nixos.nix
    ./modules/voice-control
  ];

  nixpkgs.config = import ./nixpkgs-config.nix;

  nixpkgs.overlays = [
    inputs.rust-overlay.overlays.default
    (final: prev: {
      bitwig-studio = prev.bitwig-studio.overrideAttrs (finalAttrs: oldAttrs: {
        version = "6.0.11";
        src = prev.fetchurl {
          name = "bitwig-studio-${finalAttrs.version}.deb";
          url = "https://www.bitwig.com/dl/Bitwig%20Studio/${finalAttrs.version}/installer_linux";
          hash = "sha256-rnr/Z8y6klKrU2gT5/XT+sRryl/HZZZ04n565L0HPEw=";
        };
      });
    })
    # "overwrite" xdg-open with handlr
    (final: prev: {
      # very expensive since this invalidates the cache for a lot of (almost all) graphical apps.
      xdg-utils = prev.xdg-utils.overrideAttrs (oldAttrs: {
        postInstall = ''
          # "overwrite" xdg-open with handlr
          cp ${prev.writeShellScriptBin "xdg-open" "${prev.handlr}/bin/handlr open \"$@\""}/bin/xdg-open $out/bin/xdg-open
        '';
      });
    })
    # use same wine version as the system...
    # (final: prev: {
    #   yabridgectl = prev.yabridgectl.override { wine = prev.wineWowPackages.stableFull; };
    #   yabridge = prev.yabridge.override { wine = prev.wineWowPackages.stableFull; };
    # })
    (final: prev: {
      my-rust-toolchain = (pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
        extensions = [ "rustfmt" "rust-analyzer" "rust-src" "miri" ];
        targets = [ "x86_64-unknown-linux-gnu" "wasm32-unknown-unknown" "x86_64-pc-windows-gnu" "aarch64-linux-android" ];
      }));
    })
    (final: prev: { qemu = prev.qemu.override { smbdSupport = true; }; })
    (import ./deduplicate.nix)
    (final: prev: {
      # Host C++ code includes nvcc's CRT headers via Eigen/CHOLMOD/cuBLAS.
      # strictDeps exposes nativeBuildInputs as tools, not host headers.
      colmap = prev.colmap.overrideAttrs (old:
        let
          # Reuse the selected toolkit; CPU-only builds have no nvcc input.
          cudaHeaders = builtins.filter
            (input: (input.pname or "") == "cuda_nvcc")
            old.nativeBuildInputs;
        in
        {
          buildInputs = old.buildInputs ++ cudaHeaders;
          # Eigen 3.4 wraps cholmod.h in extern "C", but CUDA-enabled CHOLMOD
          # includes C++ templates. Load it first using its own linkage guards.
          postPatch = (old.postPatch or "") + ''
            substituteInPlace src/colmap/optim/sparse_cholesky.h \
              --replace-fail '#include <Eigen/CholmodSupport>' \
                $'#include <cholmod.h>\n#include <Eigen/CholmodSupport>'
          '';
          passthru = old.passthru // {
            depsAlsoForPycolmap = old.passthru.depsAlsoForPycolmap ++ cudaHeaders;
          };
        });
    })
    (final: prev: { gimp = prev.gimp.overrideAttrs (oldAttrs: { buildInputs = oldAttrs.buildInputs ++ [ final.darktable ]; }); })
    inputs.niri.overlays.niri
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix = {
    package = pkgs.nixVersions.latest;
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      auto-optimise-store = true;
      keep-failed = true;
      trusted-users = [ "root" "@wheel" ];
      substituters = [ "https://nix-cache.mildenberger.me" "https://cache.nixos.org/" ];
      trusted-public-keys = [
        "nix-cache.mildenberger.me:dcNVw3YMUReIGC5JsMN4Ifv9xjbQn7rkDF7gJIO0ZoI="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
      experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.memtest86.enable = true;

  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];
  boot.kernelModules = [ "v4l2loopback" ];

  system.stateVersion = "22.11";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_IE.UTF-8";

  console.keyMap = "colemak";
  console.font = "Lat2-Terminus16";

  # Set your time zone.
  time.timeZone = "Europe/Vienna";
  hardware.graphics = {
    enable = true;
    # Enable 32-bit dri support for steam
    enable32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  };

  # Enable audio
  # Not strictly required but pipewire will use rtkit if it is present
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    # Compatibility shims, adjust according to your needs
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.udev = {
    enable = true;
    extraRules = ''
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
    '';
  };

  services.voiceControl = {
    enable = true;
    user = "philm";

    midi = {
      port = "Ampero Control";
      commandNote = 48;
      germanNote = 52;
      enterNote = 50;
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
        kitty = "${pkgs.niri-unstable}/bin/niri msg action spawn -- kitty";
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

          commands = let
            aliases = words: action: builtins.listToAttrs
              (map (name: { inherit name; value = action; }) words);
          in {
            insert = "key esc; key i";
            undo = "key esc; key u";
            redo = "key esc; key shift+u";
            escape = "key esc";
            "select all" = "key esc; key shift+5";

          }
          // aliases [ "goto" "go to" "go-to" "go too" "go two" "go to definition" "definition" ]
            "key esc; key g; key d"
          // aliases [ "back" "beck" "backward" "backwards" "go back" "jump back" ]
            "key esc; key ctrl+o"
          // aliases [ "into" "in to" "in-to" "forward" "forwards" "go forward" "jump forward" ]
            "key esc; key ctrl+i"
          // aliases [ "up" "half page up" "half-page up" "page up" ]
            "key esc; key ctrl+u"
          // aliases [ "down" "half page down" "half-page down" "page down" ]
            "key esc; key ctrl+d";
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
      # Keep Whisper unprompted; command vocabulary lives in contextual regexes.
      vocabulary = [ ];
      transforms = [
        {
          name = "short-utterance";
          excludeLanguages = [ "de" ];
          pattern = ''(?s)^\s*(\S+(?:\s+\S+){0,2})\s*$'';
          replace = "$1";
          lowercase = true;
          wholeSessionOnly = true;
        }
        {
          name = "short-utterance-trailing-dots";
          pattern = ''(?s)^\s*(\S*?(?:\s+\S+?){0,2}?)\.+\s*$'';
          replace = "$1";
          wholeSessionOnly = true;
        }
        {
          name = "droix-name";
          pattern = ''(?i)\bdraw(?:[\s_,–—-]*|[\s,]+(?:dash|minus)[\s,]+)x\b'';
          replace = "droix";
        }
        {
          name = "spoken-hashtag";
          pattern = ''(?i)\bhash[ -]?tag\b[\t ,]*'';
          replace = "#";
          afterModes = true;
        }
        {
          name = "spoken-identifier-punctuation";
          pattern = ''(?is)^(.*\b(?:slash|dash|minus|dot|colon)\b.*)$'';
          replace = "$1";
          spokenPunctuation = "identifier";
          afterModes = true;
        }
      ];

      modes = {
        terminal = {
          priority = 50;
          match = {
            overview = false;
            appId = "^(kitty|foot|alacritty|wezterm|ghostty)$";
          };
          transforms = import ./modules/voice-control/terminal-transforms.nix;
        };

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
              replace = "\\k{esc}gd";
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


  # services.pipewire.deepfilter.enable = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  # debugging of local webservices from external devices like smartphones
  networking.firewall.allowedTCPPorts = [ 80 443 8080 8081 8000 8001 3000 6600 7201 ];
  networking.firewall.allowedUDPPorts = [ 80 443 8080 8081 8000 8001 3000 6600 7201 ];
  networking.firewall.allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
  networking.firewall.allowedUDPPortRanges = [{ from = 1714; to = 1764; }];

  networking.hosts = { "127.0.0.1" = [ "work" "www" "spa-test" ]; };

  # nginx is sandboxed and doesn't allow reading from /home
  systemd.services.nginx.serviceConfig = {
    ProtectSystem = lib.mkForce false;
    ProtectHome = lib.mkForce false;
  };
  services.nginx = {
    user = "philm"; # because all content is served locally in home for testing
    enable = true;
    recommendedGzipSettings = true;
    virtualHosts = {
      "work" = {
        root = "/home/philm/dev/work/";
        locations."/".extraConfig = "autoindex on;";
      };
      "www" = {
        default = true;
        root = "/home/philm/dev/personal/www/";
        locations."/".extraConfig = "autoindex on;";
      };
      "spa-test" = {
        # simple test for SPAs, that need to use / with normal history routing
        root = "/home/philm/dev/personal/www/spa-test";
        locations."/".extraConfig = ''
          try_files $uri $uri/ /index.html;
          autoindex on;
        '';
      };
    };
  };

  # List of systemwide services

  virtualisation = {
    docker = {
      enable = true;
      daemon.settings.features.buildkit = true;
    };
    virtualbox.host = {
      enable = true;
      enableHardening = false;
      enableExtensionPack = true;
    };
  };

  # systemd.extraConfig = ''
  #   DefaultJobTimeoutSec=15s
  #   DefaultTimeoutStartSec=15s
  #   DefaultTimeoutStopSec=15s
  # '';

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
    settings.X11Forwarding = true;
  };

  services.udisks2.enable = true;

  # Enable the X11 windowing system.

  services.autorandr.enable = true;
  services.pulseaudio.enable = false;

  services.vnstat.enable = true;

  environment.sessionVariables = {
    EDITOR = "${config.home-manager.users.philm.programs.helix.package}/bin/hx";
  };
  environment.interactiveShellInit = ''
    alias google-chrome='google-chrome-stable'
  '';

  services.displayManager = {
    defaultSession = "niri";
    gdm = {
      enable = true;
      debug = true;
      autoSuspend = false; # for ssh connections mostly
    };
  };
  services.libinput.enable = true;

  services.xserver = {
    enable = true;
    autoRepeatInterval = 15;
    autoRepeatDelay = 300;
    xkb.variant = "colemak";
  };

  services.kanata = {
    enable = true;
    keyboards.default = {
      # devices are configured in each /machines/<machine>/default.nix
      # TODO extend kanata to automatically recognize input devices, autorestart/map devices if they connect/disconnect etc.
      config = ''
        (defsrc
          mlft mrgt mmid mfwd
          esc  1    2    3    4    5    6    7    8    9    0    -    =    bspc
          tab  q    w    f    p    g    j    l    u    y    ;    [    ]    \
          caps a    r    s    t    d    h    n    e    i    o    '    ret
          lsft z    x    c    v    b    k    m    ,    .    /    rsft
          lctl lmet lalt           spc            ralt rmet cmp rctl
        )
        (deflayer colemak
          mlft mrgt mmid @metaextra
          esc  1    2    3    4    5    6    7    8    9    0    -    =    bspc
          @xcp q    w    f    p    g    j    l    u    y    ;    [    ]    \
          esc a    r    s    t    d    h    n    e    i    o    '    ret
          lsft z    x    c    v    b    k    m    ,    .    /    rsft
          lctl lmet lalt           spc            ralt rmet cmp rctl
        )
        (defalias xcp (tap-hold-press 300 300 tab lmet))
        (defalias metaextra (tap-hold-press 300 300 mfwd lmet))
      '';
    };
  };

  systemd.user.services."sync-nix-cache" = {
    path = [ config.programs.ssh.package ];
    enable = true;
    script = "${config.nix.package}/bin/nix copy -s --to ssh://nix-cache.mildenberger.me /run/current-system";
    startAt = "hourly";
  };

  # gtk themes (home-manager more specifically) seem to have problems without it
  services.dbus.packages = [ pkgs.dconf ];
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    # TODO configure this correctly
    config = {
      common.default = [ "gtk" ];
      niri = {
        default = [ "gtk" "gnome" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
  };

  services.flatpak.enable = true;
  services.snap.enable = true;
  services.teamviewer.enable = true;
  programs.command-not-found.enable = false;

  # allow no password for sudo (dangerous...)
  security.polkit.enable = true;
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.philm = {
    uid = 1000;
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "input"
      "uinput"
      "audio"
      "dialout"
      "networkmanager"
      "systemd-journal"
      "adbusers"
      "realtime"
      "video"
      "power"
      "wheel" # Enable ‘sudo’ for the user.
      "docker"
    ];
  };
  users.extraGroups.vboxusers.members = [ "philm" ];

  # configure home-manager
  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.users.philm = {
    imports = builtins.attrValues inputs.self.homeManagerModules ++ [
      inputs.nix-index-database.homeModules.nix-index
      (import ./secrets/nix-expressions/firefox.nix inputs)
    ];
    programs.home-manager.enable = true;
    xdg.configFile."nixpkgs/config.nix".source = ./nixpkgs-config.nix;
    home.stateVersion = "22.05";
    home.enableNixpkgsReleaseCheck = false;
    modules.cli.enable = true;
    modules.gui.enable = true;
    modules.create-directories.enable = true;
  };

  # All system wide packages

  programs.niri = {
    package = pkgs.niri-unstable;
    enable = true;
  };
  programs.fish.enable = true;

  # programs.adb.enable = true;

  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-tty;
    settings = {
      default-cache-ttl = 604800;
      max-cache-ttl = 604800;
    };
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.thunderbird.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;
  services.gnome.gcr-ssh-agent.enable = true;
  # programs.ssh.startAgent = true;
  programs.seahorse.enable = true;

  environment.etc."nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text = ''
    {
        "rules": [
            {
                "pattern": {
                    "feature": "procname",
                    "matches": "niri"
                },
                "profile": "Limit Free Buffer Pool On Wayland Compositors"
            }
        ],
        "profiles": [
            {
                "name": "Limit Free Buffer Pool On Wayland Compositors",
                "settings": [
                    {
                        "key": "GLVidHeapReuseRatio",
                        "value": 0
                    }
                ]
            }
        ]
    }
  '';
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # DEVELOPMENT
    ## compilers and dev environment
    # clang_10 # conflicts with gcc
    python3
    python3Packages.pip
    python3Packages.setuptools
    poetry
    wasm-bindgen-cli
    graphql-client
    openapi-generator-cli
    ruby
    earthbuild
    grpc-client-cli
    websocat
    minio-client
    mongodb-compass
    beamPackages.elixir
    gcc
    gdb
    meson
    cmake
    dart
    perf
    valgrind
    # tracy
    git
    mercurial
    mold
    lldb
    wild
    hotspot
    ryubing
    gti
    gitui
    git-secret
    git-crypt
    diff-so-fancy
    pijul
    gnumake
    jdk
    ghc
    llvmPackages.bintools
    kakoune
    android-studio
    droidcam
    flatpak-builder
    # haskell.compiler.ghc882
    nixpkgs-review
    php
    yarn
    deno
    nodejs_24
    pnpm
    biome
    pkg-config
    android-tools

    # Rust
    # (pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
    #   extensions = [ "rustfmt" "rust-analyzer" "rust-src" "miri" ];
    #   targets = [ "x86_64-unknown-linux-gnu" "wasm32-unknown-unknown" "x86_64-pc-windows-gnu" ];
    # }))
    my-rust-toolchain
    cargo-expand
    cargo-update
    cargo-insta
    cargo-make
    cargo-flamegraph
    cargo-watch
    cargo-leptos
    cargo-llvm-lines

    # WASM related
    binaryen
    trunk
    twiggy
    wasm-pack
    miniserve

    sqlitebrowser
    sqlite
    zig
    vscode
    glslang
    vulkan-tools
    vulkan-headers
    vulkan-loader
    vulkan-validation-layers
    steam-run
    rcm # manage dotfiles

    # OFFICE/DOCUMENTING
    pandoc
    calibre
    exiv2
    libreoffice
    texliveFull
    # wkhtmltopdf

    xournalpp

    # TERMINAL/CLI
    awscli2
    fasd
    fzf
    file
    asciinema
    progress
    htop
    bottom
    killall
    lm_sensors
    lsd
    lshw
    pciutils
    ripgrep
    ripgrep-all
    fd
    tokei
    gh
    dust
    bat
    mdcat
    zoxide
    bandwhich
    grex
    hyperfine
    tealdeer
    procs
    wget
    unzip
    b3sum
    inputs.llm-agents.packages.${system}.codex
    inputs.llm-agents.packages.${system}.opencode
    yq
    jaq
    yt-dlp
    zip
    unrar
    p7zip
    brotli

    # GRAPHICS
    # blender # flatpak version is used due to Optix support
    # TODO: not strictly a module (yet)
    (import ./home/modules/gui/blender.nix { inherit pkgs; })
    krita
    gimp
    darktable
    inkscape
    exiftool
    realesrgan-ncnn-vulkan
    pitivi
    rembg

    # GIS
    LAStools
    (pkgs.python3Packages.ifcopenshell.overrideAttrs (old: { cmakeFlags = old.cmakeFlags or [ ] ++ [ "-DGLTF_SUPPORT=ON" ]; }))
    cloudcompare
    qgis
    gdal

    # AUDIO
    giada
    cantata
    gmetronome
    # loopers
    yabridge
    yabridgectl
    pavucontrol
    crosspipe
    ffmpeg-full
    flacon
    bitwig-studio
    renoise
    qpwgraph
    a2jmidid
    playerctl
    picard
    reaper
    musescore
    lilypond-with-fonts

    # COMMUNICATION
    signal-desktop
    # element-desktop
    # qtox
    discord
    slack
    v4l-utils
    zoom-us
    # skypeforlinux
    fractal
    telegram-desktop

    # WEB
    chromium
    google-chrome
    firefox
    (brave.override { vulkanSupport = true; })
    tor-browser
    ff2mpv

    # XORG/DESKTOP ENVIRONMENT
    kdePackages.dolphin
    dzen2
    file-roller
    dmenu
    wmctrl
    xev
    xinit
    xmessage
    xkill
    xwininfo
    handlr
    # deadd-notification-center

    # GAMES
    # minecraft
    wineWow64Packages.yabridge
    winetricks
    protontricks

    # MISC
    android-tools
    scrcpy
    quickemu
    spice-gtk
    xwayland-satellite
    xhost
    nextcloud-client
    parallel
    nix-du
    nix-tree
    nix-query-tree-viewer
    gnuplot
    inputs.comma.packages.${system}.default
    # inputs.devenv.packages.${system}.devenv
    colmapWithCuda
    # colmap
    exfat
    rdup
    sanoid
    # rmlint
    # cloudcompare
    gdal
    gparted
    gsettings-desktop-schemas
    appimage-run
    ntfs3g
    woeusb
    kubo
    acpi
    freecad
    # (pkgs.freecad.overrideAttrs (old: { nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.wrapGAppsHook3 ]; }))
    appimage-run
    openvpn
    # openvpn3
    powertop
    usbutils
    cabextract
    patchelf
    qdirstat
    borgbackup
    # electrum
    monero-gui
    keepassxc
    memtester
    docker-compose
    # arion
    filezilla
    scrot
    feh # to view images in terminal wrapped in home.packages with a script for svg support
    kdePackages.gwenview
    smartmontools
    rdfind
    rage
    imagemagick
    guetzli
    unityhub
    unixtools.xxd
    fira-code
    reptyr
    openssl
    rclone
    mpv
    source-code-pro
    transmission_4-gtk
    qbittorrent
    xclip
    better-adb-sync
    udiskie
    tree-sitter
    adwaita-icon-theme
    wl-clipboard-rs
  ];

  # TODO put these in home-manager?
  fonts = {
    fontconfig.enable = true;
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      font-awesome
      nerd-fonts.symbols-only
      google-fonts
      material-symbols
    ];
  };
}
