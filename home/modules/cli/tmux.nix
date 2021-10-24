{ ... }:
{ lib, config, ... }: {
  options.modules.cli.tmux.enable = lib.mkEnableOption "Enable personal tmux config";

  config = lib.mkIf config.modules.cli.tmux.enable {
    programs.tmux = {
      enable = true;
      extraConfig = ''
        set-window-option -g xterm-keys on
        set -sg escape-time 0
        set -g mouse on
        set -g default-terminal "alacritty"
        set-option -ga terminal-overrides "alacritty:Tc"
      '';
    };
  };
}
