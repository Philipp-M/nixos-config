{ ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.alacritty.enable = lib.mkEnableOption "Enable personal alacritty config";

  config = lib.mkIf config.modules.gui.alacritty.enable {

    # set alacritty as the default terminal if enabled
    # home.sessionVariables.TERMINAL = "alacritty";
    programs.alacritty = with config.theme.extraParams; {
      enable = true;
      settings = {
        live_config_reload = true;
        scrolling = {
          history = 100000; # max amount
          multiplier = 5;
        };
        custom_cursor_colors = false;
        window.opacity = builtins.fromJSON alpha;
        font.size = 18;
        font.normal.family = fontname;
        font.ligatures = true;
        colors = with config.theme.base16.colors; {
          primary = {
            background = "#${base00.hex.rgb}";
            foreground = "#${base06.hex.rgb}";
          };
          normal = {
            black = "#${base00.hex.rgb}";
            red = "#${base08.hex.rgb}";
            green = "#${base0B.hex.rgb}";
            yellow = "#${base0A.hex.rgb}";
            blue = "#${base0D.hex.rgb}";
            magenta = "#${base0E.hex.rgb}";
            cyan = "#${base0C.hex.rgb}";
            white = "#${base05.hex.rgb}";
          };
        };
      };
    };
  };
}
