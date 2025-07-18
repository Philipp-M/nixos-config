{ ewmh-status-listener, ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.desktop-environment.enable = lib.mkEnableOption ''
    Enable personal desktop-environment config (xmonad, eww etc.)
  '';

  config = lib.mkIf config.modules.gui.desktop-environment.enable {
    home.keyboard.variant = "colemak";
    home.keyboard.layout = "us";

    home.pointerCursor = {
      package = pkgs.vanilla-dmz;
      name = "Vanilla-DMZ-AA";
      gtk.enable = true;
      x11.enable = true;
    };

    xdg.configFile."cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom" = {
      source = ./cosmic-comp-keybindings.ron;
      force = true;
    };
    xdg.configFile."gtk-4.0/gtk.css".force = true;
    # home.file.".xmonad/xmonad-x86_64-linux".force = true;

    wayland.windowManager.hyprland = {
      enable = true;
      systemd = {
        enable = true;
        enableXdgAutostart = true;
      };
      settings = let pointer = config.home.pointerCursor; in {
        "$mod" = "SUPER";

        exec-once = [
          "hyprctl setcursor ${pointer.name} ${toString pointer.size}"
          "sleep 2 && ${pkgs.eww}/bin/eww --no-daemonize open bar"
          "${pkgs.swaybg}/bin/swaybg -i ~/wallpaper/JWST/wallpaper/STScI-01GA76Q01D09HFEV174SVMQDMV.png"
        ];

        misc = [
          { disable_autoreload = 1; focus_on_activate = 1; }
          { disable_hyprland_logo = true; }
        ];

        monitor = ",preferred,auto,1";

        gestures = {
          workspace_swipe = 1;
          workspace_swipe_forever = 1;
        };

        general = {
          layout = "master";
          gaps_in = 6;
          gaps_out = 6;
          border_size = 0;
          resize_on_border = true;
          extend_border_grab_area = 10;
          hover_icon_on_border = true;
        };

        input = {
          kb_layout = "us";
          kb_variant = "colemak";
          repeat_rate = 60;
          repeat_delay = 300;
          follow_mouse = 1;
          mouse_refocus = false;
          float_switch_override_focus = 0;
          accel_profile = "flat";
          sensitivity = 1.5;
          touchpad = { scroll_factor = 0.3; };
        };

        ecosystem = {
          no_update_news = true;
          no_donation_nag = true;
        };

        cursor.no_warps = true;

        decoration = {
          rounding = 6;
          blur = { size = 8; passes = 4; };
          shadow = {
            color = "0x${config.theme.extraParams.alpha-hex}${config.theme.base16.colors.base0D.hex.rgb}";
            color_inactive = "0xAA000000";
            range = 16;
          };
          blurls = [ "rofi" "gtk-layer-shell" ];
        };

        animations = {
          enabled = 1;
          animation = [
            "border,1,2,default"
            "fade,1,4,default"
            "windows,1,3,default,popin 80%"
            "workspaces,1,2,default,slide"
          ];
        };

        master = {
          new_status = "master";
          new_on_top = true;
          orientation = "right";
        };

        dwindle = {
          pseudotile = 1;
          preserve_split = 1;
        };

        workspace = [
          "f[1], gapsout:0, gapsin:0"
          "w[tv1], gapsout:0, gapsin:0"
        ];

        windowrulev2 = [
          "tile,class:kitty"
          "float,class:floating"
        ];

        bindm = [
          "$mod,mouse:272,movewindow"
          "$mod,mouse:273,resizewindow"
          "$mod ALT,mouse:272,resizewindow"
        ];

        bind = [
          "$mod SHIFT,Q,exit"
          "$mod,Backspace,killactive,"
          "$mod,F,fullscreen,0"
          "$mod SHIFT,F,fullscreen"
          "$mod SHIFT,N,changegroupactive,f"
          "$mod SHIFT,P,changegroupactive,b"
          "$mod,T,togglefloating,"
          "$mod,P,layoutmsg,swapwithmaster master"
          "$mod,A,layoutmsg,addmaster"
          "$mod,R,layoutmsg,removemaster"
          "$mod,K,layoutmsg,cyclenext"
          "$mod,H,layoutmsg,cycleprev"
          "$mod ALT,,resizeactive,"
          "$mod,Return,exec,kitty"
          "$mod,Space,exec,rofi -show run"
          "$mod,I,exec,toggle-light"
          "$mod,B,exec,toggle-bright-light"
          # "$mod,S,exec,env XDG_CURRENT_DESKTOP=sway XDG_SESSION_DESKTOP=sway QT_QPA_PLATFORM=wayland flameshot gui"
          "$mod,S,exec,env ${pkgs.hyprshot}/bin/hyprshot -m region"
          "$mod,W,exec,firefox"
          "$mod,G,exec,firefox -P geobility"
          "$mod,Escape,exec,wlogout -p layer-shell"
          "$mod,L,exec,gtklock"
          "$mod,O,exec,wl-ocr"
          "$mod,J,movefocus,l"
          "$mod,L,movefocus,r"
          "$mod SHIFT,J,movewindow,l"
          "$mod SHIFT,L,movewindow,r"
          "$mod SHIFT,H,movewindow,u"
          "$mod SHIFT,K,movewindow,d"
          "$mod,1,workspace,1"
          "$mod SHIFT,1,movetoworkspacesilent,1"
          "$mod,2,workspace,2"
          "$mod SHIFT,2,movetoworkspacesilent,2"
          "$mod,3,workspace,3"
          "$mod SHIFT,3,movetoworkspacesilent,3"
          "$mod,4,workspace,4"
          "$mod SHIFT,4,movetoworkspacesilent,4"
          "$mod,5,workspace,5"
          "$mod SHIFT,5,movetoworkspacesilent,5"
          "$mod,6,workspace,6"
          "$mod SHIFT,6,movetoworkspacesilent,6"
          "$mod,7,workspace,7"
          "$mod SHIFT,7,movetoworkspacesilent,7"
          "$mod,8,workspace,8"
          "$mod SHIFT,8,movetoworkspacesilent,8"
          "$mod,9,workspace,9"
          "$mod SHIFT,9,movetoworkspacesilent,9"
          ",XF86AudioPlay,exec,mpc toggle"
          ",XF86AudioPrev,exec,mpc prev"
          ",XF86AudioNext,exec,mpc next"
          ",XF86AudioMute,exec,${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute,exec,${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ];

        bindle = [
          ",XF86AudioRaiseVolume,exec,${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"
          ",XF86AudioLowerVolume,exec,${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"
        ];
      };
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
          "x-scheme-handler/terminal" = "kitty.desktop";
        };
      };
      desktopEntries = {
        helix = {
          name = "Helix Editor";
          genericName = "Helix Editor";
          # exec = "alacritty --title Helix --class helix -e hx %F";
          exec = "hx %F";
          terminal = true;
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
        # since firefox unfortunately doesn't use xdg-open, at least configure xterm to look more uniform
        "xterm*font" = "xft:${fontname}${xftfontextra}:size=${fontsize}";

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
      platformTheme.name = "gtk3";
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
      # enable = true;
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
