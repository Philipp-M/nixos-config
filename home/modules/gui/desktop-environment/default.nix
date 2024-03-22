{ hyprland, ewmh-status-listener, ... }:
{ pkgs, lib, config, ... }: {
  imports = [ hyprland.homeManagerModules.default ];
  options.modules.gui.desktop-environment.enable = lib.mkEnableOption ''
    Enable personal desktop-environment config (xmonad, eww etc.)
  '';

  # ${lib.optionalString (config.wayland.windowManager.hyprland.enableNvidiaPatches) ''
  # ''}
  options.modules.gui.desktop-environment.hyprland-session-wrapper = lib.mkOption {
    type = with lib.types; nullOr package;
    default = let sessionName = "Hyprland"; in pkgs.writeTextFile
      {
        name = sessionName;
        destination = "/share/wayland-sessions/${sessionName}.desktop";
        text = ''
          [Desktop Entry]
          Version=1.0
          Name=${sessionName}
          Type=Application
          Comment=An intelligent dynamic tiling Wayland compositor
          Exec=${pkgs.writeShellScriptBin sessionName ''
            . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"

            if [ -e "$HOME/.profile" ]; then
              . "$HOME/.profile"
            fi
            systemctl --user stop graphical-session.target graphical-session-pre.target

            ${lib.optionalString (config.xsession.importedVariables != [ ])
            ("systemctl --user import-environment "
              + toString (lib.unique config.xsession.importedVariables))}

              export LIBVA_DRIVER_NAME=nvidia
              export GBM_BACKEND=nvidia-drm
              export GDK_BACKEND=wayland
              export __GLX_VENDOR_LIBRARY_NAME=nvidia
              export WLR_NO_HARDWARE_CURSORS=1
            ${lib.optionalString (config.modules.cli.ssh.enable) ''
              export SSH_AUTH_SOCK=/run/user/$(id -u)/keyring/ssh
            ''}

            export XDG_SESSION_TYPE=wayland
            # export GTK_USE_PORTAL=1
            export MOZ_GLX_TEST_EARLY_WL_ROUNDTRIP=1
            export NIXOS_OZONE_WL=1
            systemctl --user start hm-graphical-session.target
            systemctl --user start hyprland-session.target
            ${config.wayland.windowManager.hyprland.package}/bin/Hyprland
            systemctl --user stop hyprland-session.target
            systemctl --user stop hm-graphical-session.target
            systemctl --user stop graphical-session.target
            systemctl --user stop graphical-session-pre.target
            unset __HM_SESS_VARS_SOURCED
          ''}/bin/${sessionName}
        '';
      } // {
      providedSessions = [ sessionName ];
    };
    description = ''
      Hyprland session wrapper which sets some environment vars for desktop use and manages relevant graphical systemd services.
    '';
  };

  config = lib.mkIf config.modules.gui.desktop-environment.enable {
    home.keyboard.variant = "colemak";
    home.keyboard.layout = "us";

    home.pointerCursor = {
      package = pkgs.vanilla-dmz;
      name = "Vanilla-DMZ-AA";
      gtk.enable = true;
      x11.enable = true;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      package = hyprland.packages.${pkgs.system}.default;
      # let cfg = config.wayland.windowManager.hyprland; in
      #.override {
      # enableXWayland = cfg.xwayland.enable;
      # hidpiXWayland = cfg.xwayland.hidpi;
      # enableNvidiaPatches = cfg.enableNvidiaPatches;
      # legacyRenderer = true;
      # };
      # enableNvidiaPatches = true;
      # recommendedEnvironment = false; # environment vars get set in session to not intervene with X11 sessions
      extraConfig =
        let
          pointer = config.home.pointerCursor;
        in
        ''
          $mod = SUPER

          # set cursor for HL itself
          exec-once = hyprctl setcursor ${pointer.name} ${toString pointer.size}
          # exec-once = killall eww && systemctl restart --user eww && sleep 0.3 && eww open bar
          exec-once = ${pkgs.eww}/bin/eww open bar

          misc {
            # disable auto polling for config file changes
            disable_autoreload = 1
            focus_on_activate = 1
          }

          monitor=,preferred,auto,1

          # touchpad gestures
          gestures {
            workspace_swipe = 1
            workspace_swipe_forever = 1
          }

          general {
            layout = master
            gaps_in = 6
            gaps_out = 6
            border_size = 0
          }

          input {
            kb_layout = us
            kb_variant = colemak
            repeat_rate = 60
            repeat_delay = 300
            # focus change on cursor move
            follow_mouse = 1
            accel_profile = flat
            sensitivity = 1.5
            touchpad {
              scroll_factor = 0.3
            }
          }

          decoration {
            rounding = 6
            blur {
              size = 8
              passes = 4
              # inactive_opacity = 0.8
            }
            drop_shadow = true
            shadow_ignore_window = true
            shadow_offset = 0 0
            shadow_range = 16
            shadow_render_power = 2
            col.shadow = 0x${config.theme.extraParams.alpha-hex}${config.theme.base16.colors.base0D.hex.rgb}
            col.shadow_inactive = 0xAA000000
            blurls = rofi
            blurls = gtk-layer-shell
          }

          animations {
            enabled = 1
            animation = border,1,2,default
            animation = fade,1,4,default
            animation = windows,1,3,default,popin 80%
            animation = workspaces,1,2,default,slide
          }

          master {
            new_on_top = true
            no_gaps_when_only = true
          }

          dwindle {
            pseudotile = 1
            preserve_split = 1
            no_gaps_when_only = true
          }

          misc {
            disable_hyprland_logo = true
          }

          exec-once = ${pkgs.swaybg}/bin/swaybg -i ~/wallpaper/JWST/wallpaper/STScI-01GA76Q01D09HFEV174SVMQDMV.png

          # windowrules
          # windowrulev2 = fullscreen,pin,class:Rofi
          # windowrulev2 = fullscreen,pin,class:Rofi
          windowrulev2 = tile,class:kitty
          # mouse movements
          bindm = $mod,mouse:272,movewindow
          bindm = $mod,mouse:273,resizewindow
          bindm = $mod ALT,mouse:272,resizewindow
          # compositor commands
          bind = $mod SHIFT,Q,exit
          bind = $mod,Backspace,killactive,
          bind = $mod,F,fullscreen,1
          bind = $mod SHIFT,F,fullscreen
          # bind = $mod,G,togglegroup,
          bind = $mod SHIFT,N,changegroupactive,f
          bind = $mod SHIFT,P,changegroupactive,b
          # bind = $mod,R,togglesplit,
          bind = $mod,T,togglefloating,
          # bind = $mod,P,pseudo,
          bind = $mod,P,layoutmsg,swapwithmaster master
          bind = $mod,A,layoutmsg,addmaster
          bind = $mod,R,layoutmsg,removemaster
          # bind = $mod,N,layoutmsg,cyclenext
          # bind = $mod,E,layoutmsg,cycleprev
          bind = $mod,K,layoutmsg,cyclenext
          bind = $mod,H,layoutmsg,cycleprev
          bind = $mod ALT,,resizeactive,
          # utility
          # bind = $mod,Return,exec,${pkgs.alacritty}/bin/alacritty
          # bind = $mod,Return,exec,${config.programs.alacritty.package}/bin/alacritty
          # bind = $mod,Return,exec,hyprctl --batch "keyword windowrule tile,kitty ; dispatch exec ${config.programs.kitty.package}/bin/kitty"
          bind = $mod,Return,exec,kitty
          bind = $mod,Space,exec,rofi -show run
          bind = $mod,I,exec,toggle-light
          bind = $mod,B,exec,toggle-bright-light
          bind = $mod,S,exec,env XDG_CURRENT_DESKTOP=sway XDG_SESSION_DESKTOP=sway QT_QPA_PLATFORM=wayland flameshot gui
          bind = $mod,W,exec,firefox
          bind = $mod,Escape,exec,wlogout -p layer-shell
          bind = $mod,L,exec,gtklock
          # bind = $mod,E,exec,
          bind = $mod,O,exec,wl-ocr
          # move focus
          bind = $mod,J,movefocus,l
          bind = $mod,L,movefocus,r
          # bind = $mod,H,movefocus,u
          # bind = $mod,K,movefocus,d
          bind = $mod SHIFT,J,movewindow,l
          bind = $mod SHIFT,L,movewindow,r
          bind = $mod SHIFT,H,movewindow,u
          bind = $mod SHIFT,K,movewindow,d

          bind = $mod,1,workspace,1
          bind = $mod SHIFT,1,movetoworkspacesilent,1
          bind = $mod,2,workspace,2
          bind = $mod SHIFT,2,movetoworkspacesilent,2
          bind = $mod,3,workspace,3
          bind = $mod SHIFT,3,movetoworkspacesilent,3
          bind = $mod,4,workspace,4
          bind = $mod SHIFT,4,movetoworkspacesilent,4
          bind = $mod,5,workspace,5
          bind = $mod SHIFT,5,movetoworkspacesilent,5
          bind = $mod,6,workspace,6
          bind = $mod SHIFT,6,movetoworkspacesilent,6
          bind = $mod,7,workspace,7
          bind = $mod SHIFT,7,movetoworkspacesilent,7
          bind = $mod,8,workspace,8
          bind = $mod SHIFT,8,movetoworkspacesilent,8
          bind = $mod,9,workspace,9
          bind = $mod SHIFT,9,movetoworkspacesilent,9
        
          # media controls
          bind = ,XF86AudioPlay,exec,mpc toggle
          bind = ,XF86AudioPrev,exec,mpc prev
          bind = ,XF86AudioNext,exec,mpc next
          # volume
          bindle = ,XF86AudioRaiseVolume,exec,${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+
          bindle = ,XF86AudioLowerVolume,exec,${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-
          bind = ,XF86AudioMute,exec,${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
          bind = ,XF86AudioMicMute,exec,${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        '';
    };

    xsession = {
      enable = true;
      profileExtra = ''
        export MOZ_USE_XINPUT2=1
        export XDG_SESSION_TYPE=x11
        export GDK_BACKEND=x11
        export PATH=${pkgs.eww}/bin:$PATH
      '';
      initExtra = ''
        systemctl start --user xmonad-session.target
      '';
      windowManager = {
        xmonad = {
          enable = true;
          extraPackages = hpkgs: [
            hpkgs.xmonad-contrib
            hpkgs.xmonad-extras
            hpkgs.monad-logger
          ];
          enableContribAndExtras = true;
          config = builtins.toPath (config.lib.theme.compileTemplate {
            name = "xmonad";
            src = ./xmonad/xmonad.hs;
          });
        };
      };
    };

    home.file.".xmonad/xmonad-x86_64-linux".force = true;

    systemd.user.targets.xmonad-session = {
      Unit = {
        Requires = [ "graphical-session.target" ];
        RefuseManualStart = false;
        StopWhenUnneeded = false;
      };
    };

    # temporary for debugging xmonad
    # home.activation.linkXmonadHs = ''
    #   $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
    #     $HOME/dev/personal/dotfiles/home/modules/gui/desktop-environment/xmonad/xmonad.hs $HOME/.xmonad/xmonad.hs
    # '';

    # temporary for debugging eww
    # home.activation.linkEww = ''
    #   $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
    #     $HOME/dev/personal/dotfiles/home/modules/gui/desktop-environment/eww $HOME/.config/eww
    # '';

    xdg.configFile."_eww_colors.scss".text = with config.theme.base16.colors; ''
      $base00: rgba(${toString base00.dec.r}, ${toString base00.dec.g}, ${toString base00.dec.b}, ${toString config.theme.extraParams.alpha});
      $base01: #${base01.hex.rgb};
      $base02: #${base02.hex.rgb};
      $base03: #${base03.hex.rgb};
      $base04: #${base04.hex.rgb};
      $base05: #${base05.hex.rgb};
      $base06: #${base06.hex.rgb};
      $base07: #${base07.hex.rgb};
      $base08: #${base08.hex.rgb};
      $base09: #${base09.hex.rgb};
      $base0A: #${base0A.hex.rgb};
      $base0B: #${base0B.hex.rgb};
      $base0C: #${base0C.hex.rgb};
      $base0D: #${base0D.hex.rgb};
      $base0E: #${base0E.hex.rgb};
      $base0F: #${base0F.hex.rgb};

      $blue: $base0D;
      $cyan: $base0C;
      $green: $base0B;
      $magenta: $base0E;
      $yellow: $base0A;
      $red: $base08;
      $orange: $base09;
      $brown: $base0F;
    '';

    systemd.user.services =
      let
        eww-dependencies = with pkgs; [
          config.wayland.windowManager.hyprland.package
          ewmh-status-listener.packages.${pkgs.system}.default
          bash
          bc
          blueberry
          bluez
          coreutils
          dbus
          dunst
          findutils
          gawk
          gnused
          gojq
          imagemagick
          iwgtk
          jaq
          light
          vnstat
          networkmanager
          networkmanagerapplet
          pavucontrol
          playerctl
          procps
          pulseaudio
          xorg.xprop
          wmctrl
          gnused
          ripgrep
          socat
          udev
          upower
          util-linux
          wget
          wireplumber
          wlogout
          wofi
        ];
        mkEwwService = { sessionTarget, ewwPackage, sessionManagerName }: {
          Unit = {
            Description = "Eww Daemon for ${sessionManagerName}";
            PartOf = [ "graphical-session.target" sessionTarget ];
          };
          Service = {
            Environment = "PATH=/run/wrappers/bin:${lib.makeBinPath ([ ewwPackage ] ++ eww-dependencies)}";
            ExecStart = "${ewwPackage}/bin/eww daemon --no-daemonize";
            Restart = "on-failure";
          };
          Install.WantedBy = [ sessionTarget ];
        };
      in
      # eww unfortunately only works either in X11 or in wayland with the same binary, thus the two different services
      {
        eww-hyprland = mkEwwService { sessionTarget = "hyprland-session.target"; ewwPackage = pkgs.eww; sessionManagerName = "Hyprland"; };
        eww-xmonad = mkEwwService { sessionTarget = "xmonad-session.target"; ewwPackage = pkgs.eww; sessionManagerName = "XMonad"; };
        eww-xmonad-statusbar = {
          Unit = { Description = "Eww widgets for xmonad"; PartOf = [ "eww-xmonad.service" ]; };
          Service = { Type = "oneshot"; ExecStart = "${pkgs.eww}/bin/eww open xmonadbar"; };
          Install.WantedBy = [ "eww-xmonad.service" ];
        };
        picom.Unit.BindsTo = [ "xmonad-session.target" ];
      };


    home.packages = [
      (lib.mkIf config.wayland.windowManager.hyprland.enable pkgs.wl-clipboard)
      (pkgs.writeShellScriptBin "feh" "${pkgs.feh}/bin/feh --conversion-timeout 5 \"$@\"")
    ];

    xdg = {
      mimeApps = {
        enable = true;
        defaultApplications = {
          "application/pdf" = "org.pwmt.zathura.desktop";
          "image/*" = "feh.desktop";
          "video/*" = "mpv.desktop";
          "text/html" = "firefox.desktop";
          "text/*" = "helix.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/about" = "firefox.desktop";
          "x-scheme-handler/unknown" = "firefox.desktop";
          "x-scheme-handler/slack" = "slack.desktop";
          "application/x-bittorrent" = "qbittorent.desktop";
          "x-scheme-handler/magnet" = "qbittorent.desktop";
          "x-scheme-handler/mailto" = "thunderbird.desktop";
        };
      };
      desktopEntries = {
        helix = {
          name = "Helix Editor";
          genericName = "Helix Editor";
          exec = "alacritty --title Helix --class helix -e hx %F";
          terminal = false;
          categories = [ "Application" "Network" "WebBrowser" ];
          # mimeType = [ "text/*" ];
        };
      };
    };

    # some app overwrites mimeapps all the time...
    xdg.configFile."mimeapps.list".force = true;

    xresources.properties = with config.theme.base16.colors;
      with config.theme.extraParams; {
        "Xft.dpi" = dpi;
        "Xft.antialias" = true;
        "Xft.rgba" = "rgb";
        "Xft.hinting" = true;
        "Xft.autohint" = false;
        "Xft.hintstyle" = "hintslight";
        "Xft.lcdfilter" = "lcddefault";
        "Xft.font" = "xft:${fontname}${xftfontextra}:size=${fontsize}";

        "*color0" = "#${base00.hex.rgb}";
        "*color1" = "#${base08.hex.rgb}";
        "*color2" = "#${base0B.hex.rgb}";
        "*color3" = "#${base0A.hex.rgb}";
        "*color4" = "#${base0D.hex.rgb}";
        "*color5" = "#${base0E.hex.rgb}";
        "*color6" = "#${base0C.hex.rgb}";
        "*color7" = "#${base05.hex.rgb}";
        "*color8" = "#${base03.hex.rgb}";

        "*color9" = "#${base08.hex.rgb}";
        "*color10" = "#${base0B.hex.rgb}";
        "*color11" = "#${base0A.hex.rgb}";
        "*color12" = "#${base0D.hex.rgb}";
        "*color13" = "#${base0E.hex.rgb}";
        "*color14" = "#${base0C.hex.rgb}";

        "*color15" = "#${base07.hex.rgb}";
        "*color16" = "#${base09.hex.rgb}";
        "*color17" = "#${base0F.hex.rgb}";
        "*color18" = "#${base01.hex.rgb}";
        "*color19" = "#${base02.hex.rgb}";
        "*color20" = "#${base04.hex.rgb}";
        "*color21" = "#${base06.hex.rgb}";

        "*foreground" = "#${base05.hex.rgb}";
        "*background" = "#${base00.hex.rgb}";
        "*fadeColor" = "#${base07.hex.rgb}";
        "*cursorColor" = "#${base01.hex.rgb}";
        "*pointerColorBackground" = "#${base01.hex.rgb}";
        "*pointerColorForeground" = "#${base06.hex.rgb}";
      };

    # KDE/GTK specific

    gtk = {
      enable = true;
      iconTheme.name = "Papirus-Dark-Maia";
      iconTheme.package = pkgs.papirus-maia-icon-theme;
    };

    qt = {
      enable = true;
      platformTheme = "gtk";
    };

    programs.rofi = {
      package = pkgs.rofi-wayland;
      enable = true;
      enableBase16Theme = false;
      theme = builtins.toPath (
        config.lib.theme.compileTemplate {
          name = "rofi";
          src = ./rofi/theme.template.rasi;
        }
      );
      extraConfig = {
        cache-dir = ".local/share/rofi/cache";
      };
    };

    services.picom = {
      enable = true;
      # add fancy dual kawase blur to picom
      # package = pkgs.picom.overrideAttrs (
      #   old: {
      #     src = builtins.fetchGit {
      #       shallow = true;
      #       url = "https://github.com/Philipp-M/picom/";
      #       ref = "customizable-rounded-corners";
      #       rev = "2b1d9faf0bf5dfad04a5acf02b34a432368de805";
      #     };
      #   }
      # );
      package = pkgs.compfy;
      # extraArgs = [ "--experimental-backends" ];
      settings = {
        # general
        backend = "glx";
        vsync = true;
        refresh-rate = 0;
        unredir-if-possible = true;
        # blur
        animations = false;
        blur-background = true;
        blur-background-exclude = [ ];
        blur-method = "dual_kawase";
        blur-strength = 10;
        blur-whitelist = false;
        corner-radius = 0;
        wintypes = {
          desktop = {
            opacity = builtins.fromJSON config.theme.extraParams.alpha;
            # corner-radius = 0;
            # corner-radius-top-left = 5;
            # corner-radius-top-right = 5;
            # round-borders = 1;
          };
          # normal = { round-borders = 1; };
        };
        ## rounded corners and alpha-transparency
        # detect-rounded-corners = true;
        # round-borders = 1;
        # corner-radius = 0;
        # corner-radius-bottom-left = 5;
        # corner-radius-bottom-right = 5;
        # rounded-corners-exclude = [
        #   "window_type = 'menu'"
        #   "window_type = 'dock'"
        #   "window_type = 'dropdown_menu'"
        #   "window_type = 'popup_menu'"
        #   "class_g = 'Polybar'"
        #   "class_g = 'Rofi'"
        #   "class_g = 'Dunst'"
        # ];
        frame-opacity = builtins.fromJSON config.theme.extraParams.alpha;
      };
    };

    services.random-background = {
      enable = true;
      imageDirectory = "%h/wallpaper/";
    };

    services.gammastep = {
      enable = true;
      latitude = "47.267";
      longitude = "11.383";
      temperature.day = 6500;
      temperature.night = 3200;
    };

    services.udiskie = {
      enable = true;
      settings.icon_names.media = [ "media-optical" ];
    };

    services.status-notifier-watcher.enable = true;

    services.pasystray.enable = true;

    services.network-manager-applet.enable = true;

    services.flameshot.enable = true;

    services.dunst.enable = true;

    # services.unclutter.enable = true;

    services.kdeconnect.enable = true;

    # audio services

    services.easyeffects.enable = true;
  };
}
