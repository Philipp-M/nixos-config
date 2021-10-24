{ ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.desktop-environment.enable = lib.mkEnableOption ''
    Enable personal desktop-environment config (xmonad, taffybar etc.)
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
            hpkgs.taffybar
          ];
          enableContribAndExtras = true;
          config = builtins.toPath (
            config.lib.theme.compileTemplate {
              name = "xmonad";
              src = ./xmonad/xmonad.hs;
            }
          );
        };
      };
    };

    home.file.".xmonad/xmonad-x86_64-linux".force = true;

    services.taffybar = {
      enable = true;
      package = (import ./taffybar) { inherit pkgs; };
    };

    home.file.".config/taffybar/taffybar.css".source = config.lib.theme.compileTemplate {
      name = "taffybar.css";
      src = ./taffybar/taffybar.template.css;
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

    services.status-notifier-watcher.enable = true;

    services.pasystray.enable = true;

    services.network-manager-applet.enable = true;

    services.flameshot.enable = true;

    services.dunst.enable = true;

    services.unclutter.enable = true;

    # audio services

    services.pulseeffects = {
      enable = true;
      package = pkgs.pulseeffects-pw;
    };
    # services.pulseeffects.preset = "HD800S";
  };
}
