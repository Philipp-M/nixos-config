{ ewmh-status-listener, ... }:
{ pkgs, lib, config, ... }: {

  imports = [ (import ./niri.nix) ];

  options.modules.gui.desktop-environment.enable = lib.mkEnableOption ''
    Enable personal desktop-environment config (niri etc.)
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

    home.sessionVariables = {
      DISPLAY = ":0";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      NIXOS_OZONE_WL = "1";
    };

    xdg.configFile."uwsm/env".text = ''
      source /etc/profile
      source ${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh
    '';
    xdg.configFile."gtk-4.0/gtk.css".force = true;

    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        enableDebug = true;
      };
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;

          modules-left = [ "niri/workspaces" "niri/window" ];
          modules-center = [ "mpd" ];
          modules-right = [ "tray" "cpu" "wireplumber" "network" "battery" "clock" ];

          "niri/workspaces" = {
            format = "{icon}";
            format-icons = {
              browser = "";
              discord = "";
              chat = "<b></b>";

              active = "";
              default = "";
            };
          };
          "niri/window" = {
            format = "{}";
            rewrite = {
              "(.*) - Mozilla Firefox" = "🌎 $1";
            };
          };
          clock = { format = "{:%Y-%m-%d %H:%M:%S}"; interval = 1; };
          tray = {
            icon-size = 21;
            spacing = 10;
            icons = {
              blueman = "bluetooth";
            };
          };
          cpu = {
            interval = 1;
            format = "{}% ";
            max-length = 10;
          };
          wireplumber = {
            format = "{volume}% {icon}";
            format-muted = "";
            on-click = "helvum";
            format-icons = [ "" "" "" ];
          };
          network = {
            format-wifi = " {essid} ({signalStrength}%)";
            format-ethernet = " : {bandwidthUpBytes} : {bandwidthDownBytes}";
            format-disconnected = "⚠ Disconnected";
            interval = 1;
          };
          battery = {
            format = "{capacity}% {icon}";
            format-icons = [ "" "" "" "" "" ];
          };
        };
      };

      style = ''
        * {
          font-family: ${config.theme.extraParams.fontname}, monospace, Symbols Nerd Font;
          font-size: ${config.theme.extraParams.fontsize}px;
        }
        window#waybar {
          background: #${config.theme.base16.colors.base00.hex.rgb};
          color: #${config.theme.base16.colors.base07.hex.rgb};
        }
        button {
            /* Use box-shadow instead of border so the text isn't offset */
            box-shadow: none;
            /* Avoid rounded borders under each button name */
            border: none;
            border-radius: 0;
            transition-property: none;
        }

        /* https://github.com/Alexays/Waybar/wiki/FAQ#the-workspace-buttons-have-a-strange-hover-effect */
        button:hover {
            background: none;
            box-shadow: none;
            text-shadow: none;
            border: none;
            -gtk-icon-effect: none;
            -gtk-icon-shadow: none;
        }

        #clock {
          padding: 0 10px;
          color: #${config.theme.base16.colors.base00.hex.rgb};
          background-color: #${config.theme.base16.colors.base03.hex.rgb};
        }

        #network {
          padding: 0 10px;
          min-width: 230px;
          background-color: #${config.theme.base16.colors.base02.hex.rgb};
        }

        #wireplumber {
          min-width: 80px;
          padding: 0 10px;
          background-color: #${config.theme.base16.colors.base01.hex.rgb};
        }

        #workspaces {
          padding-right: 10px;
        }

        #workspaces button {
          padding: 0 0;
          margin: 0 0;
          /* color: #${config.theme.base16.colors.base07.hex.rgb}; */
          min-width: 30px;
        }

        #workspaces button:hover {
          background-color: #${config.theme.base16.colors.base02.hex.rgb};
        }

        #workspaces button.active, #workspaces button.focused {
          background-color: #${config.theme.base16.colors.base04.hex.rgb};
          color: #${config.theme.base16.colors.base00.hex.rgb};
        }

        #workspaces button.active:hover {
          background-color: #${config.theme.base16.colors.base05.hex.rgb};
        }

        #workspaces button.urgent {
          background-color: #${config.theme.base16.colors.base0D.hex.rgb};
          color: #${config.theme.base16.colors.base00.hex.rgb};
        }
      '';
    };

    systemd.user.services = {
      swww = {
        Unit = {
          Description = "Background Wallpaper Manager for Wayland";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.swww}/bin/swww-daemon";
          Restart = "always";
          IOSchedulingClass = "idle";
        };
      };
      swww-random-image = {
        Unit = {
          Description = "Set random wallpaper using swww";
          After = [ "swww.service" ];
          Requires = [ "swww.service" ];
          PartOf = [ "swww.service" ];
        };

        Service = {
          Type = "oneshot";
          Environment = [
            "RESIZE_TYPE=crop"
            "SWWW_TRANSITION=fade"
            "SWWW_TRANSITION_FPS=120"
            "SWWW_TRANSITION_STEP=2"
            "WALLPAPER_PATH=/home/philm/wallpaper/JWST/wallpaper"
          ];
          IOSchedulingClass = "idle";
          ExecStart =
            "${pkgs.writeShellScriptBin "swww-random-image" ''
                ${pkgs.swww}/bin/swww img --resize="$RESIZE_TYPE" "$(${pkgs.findutils}/bin/find "$WALLPAPER_PATH" -type f | ${pkgs.coreutils}/bin/shuf -n1)"
              ''}/bin/swww-random-image";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      # This seems to be necessary, as the background is gone after shutting off a monitor
      restart-swww-random-image-on-output-change = {
        Unit = {
          Description = "Reapply swww wallpaper when Niri adds an output";
          After = [ "niri.service" "graphical-session.target" ];
          Requires = [ "niri.service" ];
          PartOf = [ "niri.service" "graphical-session.target" ];
          ConditionEnvironment = "NIRI_SOCKET";
        };
        Service = {
          ExecStart =
            "${pkgs.writeShellScriptBin "restart-swww-random-image-on-output-change" ''
              set -eu

              has_new_output() {
                local previous="$1"
                local current="$2"
                local output

                while IFS= read -r output; do
                  [ -n "$output" ] || continue

                  if ! ${pkgs.coreutils}/bin/grep -Fxq -- "$output" <<< "$previous"; then
                    return 0
                  fi
                done <<< "$current"

                return 1
              }

              previous_outputs=""

              printf '"EventStream"\n' | ${pkgs.netcat-openbsd}/bin/nc -U "$NIRI_SOCKET" | while IFS= read -r line; do
                current_outputs="$(
                  printf '%s\n' "$line" | ${pkgs.jaq}/bin/jaq -r '
                    if .WorkspacesChanged? then
                      .WorkspacesChanged.workspaces
                      | map(.output)
                      | sort
                      | unique
                      | .[]
                    else
                      empty
                    end
                  '
                )"

                [ -n "$current_outputs" ] || continue

                if [ -z "$previous_outputs" ]; then
                  previous_outputs="$current_outputs"
                  continue
                fi

                if [ "$current_outputs" != "$previous_outputs" ] && [ "$current_outputs" != "null" ] && has_new_output "$previous_outputs" "$current_outputs"; then
                  ${pkgs.coreutils}/bin/sleep 3
                  ${pkgs.systemd}/bin/systemctl --user restart swww-random-image.service
                fi

                previous_outputs="$current_outputs"
              done
            ''}/bin/restart-swww-random-image-on-output-change";
          IOSchedulingClass = "idle";
          Restart = "always";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

    systemd.user.timers.swww-random-image = {
      Unit.Description = "Periodically change wallpaper using swww";
      Timer.OnUnitActiveSec = "5min";
      Install.WantedBy = [ "timers.target" ];
    };

    home.packages = [
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

    services.copyq.enable = true;

    # services.random-background = {
    #   enable = true;
    #   imageDirectory = "%h/wallpaper/JWST/wallpaper";
    # };

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

    services.swaync.enable = true;

    # services.unclutter.enable = true;

    services.kdeconnect.enable = true;

    # audio services

    services.easyeffects.enable = true;
  };
}
