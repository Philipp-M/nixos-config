# This contains most X.org desktop environment related stuff

{ pkgs, lib, config, ... }: {
  imports = [ ./mpv ];
  home.keyboard.variant = "colemak";
  home.keyboard.layout = "us";

  xsession = {
    enable = true;
    initExtra = ''
      # Remap Escape to 'Hyper_L' for an extra 'hybrid' modifier for xmonad and other applications that use Super
      # Caps Lock is useless anyway, so remap it to 'Escape' to provide comfort in vim...
      # Unfortunately Alacritty (or more precisely winit) has a bug with xmodmap modifier remappings...
      ${pkgs.xorg.xmodmap}/bin/xmodmap  \
              -e 'keycode 23 = Hyper_L'  \
              -e 'clear Lock'           \
              -e 'keycode 66 = Escape' \
              -e 'keycode any = Tab' \
      # Currently the service xcape in home-manager doesn't work correctly
      # (my guess is because xcape is started before the script above)
      # The following line is used for reenabling Escape if it is used on its own (single tap which takes under 500ms)
      ${pkgs.xcape}/bin/xcape -e 'Hyper_L=Tab'
    '';
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
          config.lib.base16.template {
            name = "xmonad";
            src = ./xmonad/xmonad.hs;
          }
        );
      };
    };
  };

  services.taffybar = {
    enable = true;
    package = (import ./taffybar) { inherit pkgs; };
  };

  home.file.".config/taffybar/taffybar.css".source =
    config.lib.base16.template {
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

  xresources.properties = with config.lib.base16.theme; {
    "Xft.dpi" = dpi;
    "Xft.antialias" = true;
    "Xft.rgba" = "rgb";
    "Xft.hinting" = true;
    "Xft.autohint" = false;
    "Xft.hintstyle" = "hintslight";
    "Xft.lcdfilter" = "lcddefault";
    "Xft.font" = "xft:${fontname}${xftfontextra}:size=${fontsize}";
    "Xcursor.size" = xcursorSize;

    "*color0" = "#${base00-hex}";
    "*color1" = "#${base08-hex}";
    "*color2" = "#${base0B-hex}";
    "*color3" = "#${base0A-hex}";
    "*color4" = "#${base0D-hex}";
    "*color5" = "#${base0E-hex}";
    "*color6" = "#${base0C-hex}";
    "*color7" = "#${base05-hex}";
    "*color8" = "#${base03-hex}";

    "*color9" = "#${base08-hex}";
    "*color10" = "#${base0B-hex}";
    "*color11" = "#${base0A-hex}";
    "*color12" = "#${base0D-hex}";
    "*color13" = "#${base0E-hex}";
    "*color14" = "#${base0C-hex}";

    "*color15" = "#${base07-hex}";
    "*color16" = "#${base09-hex}";
    "*color17" = "#${base0F-hex}";
    "*color18" = "#${base01-hex}";
    "*color19" = "#${base02-hex}";
    "*color20" = "#${base04-hex}";
    "*color21" = "#${base06-hex}";

    "*foreground" = "#${base05-hex}";
    "*background" = "#${base00-hex}";
    "*fadeColor" = "#${base07-hex}";
    "*cursorColor" = "#${base01-hex}";
    "*pointerColorBackground" = "#${base01-hex}";
    "*pointerColorForeground" = "#${base06-hex}";
  };

  # KDE/GTK specific

  gtk = {
    enable = true;
    theme.name = "adwaita-dark";
    # iconTheme = {
    #   name = "Numix-Circle";
    #   package = pkgs.numix-icon-theme-circle;
    # };
  };

  # gtk 2
  home.file.".themes/base16/gtk-2.0/gtkrc".source = config.lib.base16.template {
    name = "base16-gtk-2.0";
    src = ./gtk-2.0/template.gtkrc;
  };

  # gtk 3
  # home.file.".themes/base16/gtk-3.0/gtk.css".source =
  #   config.lib.base16.template {
  #     name = "base16-gtk-2.0";
  #     src = ./gtk-3.0/gtk.template.css;
  #   };

  qt = {
    enable = true;
    platformTheme = "gtk";
  };

  programs.rofi = {
    enable = true;
    theme = builtins.toPath (
      config.lib.base16.template {
        name = "rofi";
        src = ./rofi/theme.template.rasi;
      }
    );
  };

  programs.autorandr = {
    enable = true;
    profiles = {
      "zen" = {
        fingerprint = {
          "DP-0" =
            "00ffffffffffff0004721304c738804326180104a53c22783e4dd5a7554a9d240e5054bfef8081c0810081809500b3008140d1c0714f4dd000a0f0703e8030203500544f2100001a04740030f2705a80b0588a00544f2100001a000000fd0017501ea03c010a202020202020000000fc00414345522042323736484b0a200104020329f14f9001020304051112131f140607202223090707830100006c030c002000007820004001030e1f008051001e3040803700544f2100001c023a801871382d40582c4500544f2100001e565e00a0a0a0295030203500544f2100001a0000000000000000000000000000000000000000000000000000000000000000de";
          "DP-2" =
            "00ffffffffffff00410c42c105000000341a0104b55932783a1571ad5047a726125054bfef00d1c0b30095008180814081c0010101014dd000a0f0703e803020350075f23100001aa36600a0f0701f803020350075f23100001a000000fd0017501ea03c010a202020202020000000fc0050484c2042444d34303337550a0176020326f14b0103051404131f1202119023090707830100006d030c0020001878200060010203011d007251d01e206e28550075f23100001e8c0ad08a20e02d10103e960075f2310000188c0ad090204031200c40550075f2310000184d6c80a070703e8030203a0075f23100001a000000000000000000000000000000000025";
        };
        config = {
          "DP-0" = {
            position = "0x0";
            primary = false;
            mode = "3840x2160";
          };
          "DP-2" = {
            position = "3840x0";
            primary = false;
            mode = "3840x2160";
          };
        };
      };
    };
  };

  services.picom = {
    enable = true;
    # add fancy dual kawase blur to picom
    package = pkgs.picom.overrideAttrs (
      old: {
        src = builtins.fetchGit {
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
      blur-background-exclude = [];
      blur-method = "dual_kawase";
      blur-strength = 10;
      wintypes = {
        desktop = {
          opacity = builtins.fromJSON config.lib.base16.theme.alpha;
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
      frame-opacity = builtins.fromJSON config.lib.base16.theme.alpha;
    };
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

  services.random-background = {
    enable = true;
    imageDirectory = "%h/wallpaper/";
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

  programs.alacritty = with config.lib.base16.theme; {
    enable = true;
    package = pkgs.callPackage ./alacritty.nix {};
    settings = {
      live_config_reload = true;
      scrolling = {
        history = 100000; # max amount
        multiplier = 5;
      };
      custom_cursor_colors = false;
      background_opacity = builtins.fromJSON alpha;
      font.size = 18;
      font.normal.family = fontname;
      font.ligatures = true;
      colors = {
        primary = {
          background = "#${base00-hex}";
          foreground = "#${base06-hex}";
        };
        normal = {
          black = "#${base00-hex}";
          red = "#${base08-hex}";
          green = "#${base0B-hex}";
          yellow = "#${base0A-hex}";
          blue = "#${base0D-hex}";
          magenta = "#${base0E-hex}";
          cyan = "#${base0C-hex}";
          white = "#${base05-hex}";
        };
      };
    };
  };

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs; [ obs-v4l2sink ];
  };
}
