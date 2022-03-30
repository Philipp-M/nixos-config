# This module enables all personal CLI related stuff for home-manager
{ ... }:
{ lib, config, ... }:
{
  options.modules.cli.enable = lib.mkEnableOption "Enable all personal cli configurations";

  config = lib.mkIf config.modules.cli.enable {
    home.sessionVariables.EDITOR = "hx";

    modules.cli = {
      neovim.enable = true;
      ssh.enable = true;
      fish.enable = true;
      starship.enable = true;
      tmux.enable = true;
      git.enable = true;
      helix.enable = true;
    };

    # "too small" for dedicated modules

    programs.zoxide.enable = true;

    programs.bat.enable = true;
  };
}
