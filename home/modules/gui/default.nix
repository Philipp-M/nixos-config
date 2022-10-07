# This module enables all personal X.org desktop environment related stuff for home-manager
{ ... }:
{ pkgs, lib, config, ... }:
{
  options.modules.gui.enable = lib.mkEnableOption "Enable all personal gui configurations";

  config = lib.mkIf config.modules.gui.enable {
    modules.gui = {
      alacritty.enable = true;
      kitty.enable = true;
      autorandr.enable = true;
      desktop-environment.enable = true;
      firefox.enable = true;
      mpv.enable = true;
    };

    # too small for dedicated module
    programs.obs-studio.enable = true;
  };
}
