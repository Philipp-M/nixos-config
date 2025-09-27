{ ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.kitty.enable = lib.mkEnableOption "Enable personal kitty config";

  config =
    lib.mkIf config.modules.gui.kitty.enable {
      # set kitty as the default terminal if enabled
      home.sessionVariables.TERMINAL = "kitty";
      programs.kitty = with config.theme.extraParams; {
        enable = true;
        font = {
          name = fontname;
          size = 18;
        };
        settings = {
          confirm_os_window_close = 0;
          scrollback_lines = 100000;
          enable_audio_bell = false;
          update_check_interval = 0;
          # background_opacity = alpha;
          background_opacity = 0.95;
          scrollback_fill_enlarged_window = true;
          shell_integration = "no-rc no-cursor no-prompt-mark";
          symbol_map = "U+23FB-U+23FE,U+2630,U+2665,U+26A1,U+276C-U+2771,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0C8,U+E0CA,U+E0CC-U+E0D2,U+E0D4,U+E0D6-U+E0D7,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6B8,U+E700-U+E8EF,U+EA60-U+EA88,U+EA8A-U+EA8C,U+EA8F-U+EAC7,U+EAC9,U+EACC-U+EB09,U+EB0B-U+EB4E,U+EB50-U+EC1E,U+ED00-U+EFCE,U+F000-U+F381,U+F400-U+F533,U+F0001-U+F1AF0 Symbols Nerd Font";
        };
        extraConfig = with config.theme.base16.colors;
          ''
            include ${pkgs.writeText "theme.conf" ''
              background #${base00.hex.rgb}
              foreground #${base05.hex.rgb}
              selection_background #${base05.hex.rgb}
              selection_foreground #${base00.hex.rgb}
              url_color #${base04.hex.rgb}
              cursor #${base05.hex.rgb}
              active_border_color #${base03.hex.rgb}
              inactive_border_color #${base01.hex.rgb}
              active_tab_background #${base00.hex.rgb}
              active_tab_foreground #${base05.hex.rgb}
              inactive_tab_background #${base01.hex.rgb}
              inactive_tab_foreground #${base04.hex.rgb}
              tab_bar_background #${base01.hex.rgb}

              # normal
              color0 #${base00.hex.rgb}
              color1 #${base08.hex.rgb}
              color2 #${base0B.hex.rgb}
              color3 #${base0A.hex.rgb}
              color4 #${base0D.hex.rgb}
              color5 #${base0E.hex.rgb}
              color6 #${base0C.hex.rgb}
              color7 #${base05.hex.rgb}

              # bright
              color8 #${base03.hex.rgb}
              color9 #${base09.hex.rgb}
              color10 #${base01.hex.rgb}
              color11 #${base02.hex.rgb}
              color12 #${base04.hex.rgb}
              color13 #${base06.hex.rgb}
              color14 #${base0F.hex.rgb}
              color15 #${base07.hex.rgb}
            ''}
          '';
      };
    };
}
