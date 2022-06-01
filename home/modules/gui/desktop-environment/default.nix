{ nixpkgs-unstable, ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.desktop-environment.enable = lib.mkEnableOption ''
    Enable personal desktop-environment config (xmonad, polybar etc.)
  '';

  config = lib.mkIf config.modules.gui.desktop-environment.enable {
    home.keyboard.variant = "colemak";
    home.keyboard.layout = "us";

    xsession = {
      enable = true;
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


    services.polybar = {
      enable = true;
      script = "polybar -r bar &";
      package = nixpkgs-unstable.pkgs.polybar.override {
        mpdSupport = true;
        nlSupport = true;
        iwSupport = true;
        githubSupport = true;
      };
      config = with config.theme.base16.colors; with config.theme.extraParams; {
        "bar/bar" = {
          fill = "";
          empty = "";
          indicator = "";
          modules-left = [ "ewmh" ];
          modules-right = [ "memory" "cpu" "network-wired" "network-wireless" "date" ];
          modules-center = [ "mpd" ];
          background = "#${alpha-hex}${base00.hex.rgb}";
          foreground = "#${base06.hex.rgb}";
          font-0 = "${fontname}${xftfontextra}:pixelsize=16;3.5";
          font-1 = "Font Awesome 6 Free:style=Solid:pixelsize=16;3.5";
          font-2 = "Font Awesome 6 Brands:pixelsize=16;3.5";
          font-3 = "Font Awesome 6 Brands:style=Regular:pixelsize=16;3.5";
          height = 33;
        };
        "module/network-wired" = {
          type = "internal/network";
          accumulate-stats = true;
          label-connected = "%{T2}%{T-}%downspeed:9% %{T2}%{T-}%upspeed:9%";
          interface-type = "wired";
          label-connected-background = "#${alpha-hex}${base0C.hex.rgb}";
          label-connected-foreground = "#${base00.hex.rgb}";
          label-connected-padding = 1;
        };
        "module/network-wireless" = {
          type = "internal/network";
          accumulate-stats = true;
          label-connected = "%{T2} %{T-}%downspeed:9% %{T2}%{T-}%upspeed:9%";
          interface-type = "wireless";
          label-connected-background = "#${alpha-hex}${base0C.hex.rgb}";
          label-connected-foreground = "#${base00.hex.rgb}";
          label-connected-padding = 1;
        };
        "module/mpd" = {
          type = "internal/mpd";
          format-online = "<icon-prev> <icon-stop> <toggle> <icon-next>  <label-time>  <label-song>";
          interval = 1;
          icon-play = "%{T2}%{T-}";
          icon-pause = "%{T2}⏸%{T-}";
          icon-stop = "%{T2}%{T-}";
          icon-prev = "%{T2}⏮%{T-}";
          icon-next = "%{T2}⏭%{T-}";
          icon-seekb = "%{T2}⏪%{T-}";
          icon-seekf = "%{T2}⏩%{T-}";
          icon-random = "%{T2}�%{T-}�";
          icon-repeat = "%{T2}�%{T-}�";
          icon-repeatone = "%{T2}�%{T-}�";
          icon-single = "%{T2}�%{T-}�";
          icon-consume = "%{T2}✀%{T-}";
        };
        "module/ewmh" = {
          type = "internal/xworkspaces";
          pin-workspaces = true;
          enable-click = true;
          enable-scroll = true;
          reverse-scroll = true;
          label-active = "%name%";
          label-occupied = "%name%";
          label-active-foreground = "#${base00.hex.rgb}";
          label-active-background = "#${base03.hex.rgb}";
          label-occupied-background = "#${alpha-hex}${base02.hex.rgb}";
          label-active-padding = 1;
          label-occupied-padding = 1;
          label-empty = "";
        };
        "module/date" = {
          type = "internal/date";
          label = "%{T2}%{T-} %date% %time%";
          label-background = "#${alpha-hex}${base0D.hex.rgb}";
          label-foreground = "#${base00.hex.rgb}";
          label-padding = 1;
          interval = "1.0";
          date = "%d.%m.%Y";
          time = "%H:%M:%S";
          date-alt = "%A, %d %B %Y";
          time-alt = "%H:%M:%S";
        };
        "module/cpu" = {
          type = "internal/cpu";
          format = "%{T2}%{T-} <ramp-load> <label>";
          label = "%percentage:3%%";
          format-background = "#${alpha-hex}${base0B.hex.rgb}";
          format-foreground = "#${base00.hex.rgb}";
          ramp-load-spacing = 1;
          ramp-load-0 = "▁";
          ramp-load-1 = "▂";
          ramp-load-2 = "▃";
          ramp-load-3 = "▄";
          ramp-load-4 = "▅";
          ramp-load-5 = "▆";
          ramp-load-6 = "▇";
          ramp-load-7 = "█";
          format-padding = 1;
          interval = "0.5";
        };
        "module/memory" = {
          label = "%{T2}%{T-}%gb_used:10%";
          label-background = "#${alpha-hex}${base0A.hex.rgb}";
          label-foreground = "#${base00.hex.rgb}";
          label-padding = 1;
          type = "internal/memory";
        };
      };
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = "org.pwmt.zathura.desktop";
        "image/png" = "feh.desktop";
        "image/jpeg" = "feh.desktop";
        "video/x-matroska" = "mpv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/webm" = "mpv.desktop";
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
        "application/x-bittorrent" = "qbittorent.desktop";
        "x-scheme-handler/magnet" = "qbittorent.desktop";
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
        "Xcursor.size" = xcursorSize;

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

    gtk.enable = true;

    qt = {
      enable = true;
      platformTheme = "gtk";
    };

    programs.rofi = {
      enable = true;
      enableBase16Theme = false;
      theme = builtins.toPath (
        config.lib.theme.compileTemplate {
          name = "rofi";
          src = ./rofi/theme.template.rasi;
        }
      );
    };

    services.picom = {
      enable = true;
      # add fancy dual kawase blur to picom
      package = pkgs.picom.overrideAttrs (
        old: {
          src = builtins.fetchGit {
            shallow = true;
            url = "https://github.com/Philipp-M/picom/";
            ref = "customizable-rounded-corners";
            rev = "2b1d9faf0bf5dfad04a5acf02b34a432368de805";
          };
        }
      );
      experimentalBackends = true;
      settings = {
        # general
        backend = "glx";
        vsync = true;
        refresh-rate = 0;
        unredir-if-possible = false;
        # blur
        blur-background = true;
        blur-background-exclude = [ ];
        blur-method = "dual_kawase";
        blur-strength = 10;
        wintypes = {
          desktop = {
            opacity = builtins.fromJSON config.theme.extraParams.alpha;
            corner-radius = 0;
            corner-radius-top-left = 5;
            corner-radius-top-right = 5;
            round-borders = 1;
          };
          normal = { round-borders = 1; };
        };
        # rounded corners and alpha-transparency
        detect-rounded-corners = true;
        round-borders = 1;
        corner-radius = 0;
        corner-radius-bottom-left = 5;
        corner-radius-bottom-right = 5;
        rounded-corners-exclude = [
          "window_type = 'menu'"
          "window_type = 'dock'"
          "window_type = 'dropdown_menu'"
          "window_type = 'popup_menu'"
          "class_g = 'Polybar'"
          "class_g = 'Rofi'"
          "class_g = 'Dunst'"
        ];
        frame-opacity = builtins.fromJSON config.theme.extraParams.alpha;
      };
    };

    services.random-background = {
      enable = true;
      imageDirectory = "%h/wallpaper/";
    };

    services.redshift = {
      enable = true;
      settings = {
        manual = {
          lat = "47.267";
          lon = "11.383";
        };
      };
      temperature.day = 6500;
      temperature.night = 3200;
    };

    services.udiskie.enable = true;

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
