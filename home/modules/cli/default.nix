# This module enables all personal CLI related stuff for home-manager
{ ... }:
{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf hasAttrByPath;
  inherit (builtins) isAttrs isFunction;
  cfg = config.modules.cli;
in
{
  options.modules.cli.enable = mkEnableOption "Enable all personal cli configurations";

  config = mkIf cfg.enable {
    home.sessionVariables.EDITOR = "nvim";

    modules.cli = {
      neovim.enable = true;
      ssh.enable = true;
      fish.enable = true;
      starship.enable = true;
      tmux.enable = true;
      git.enable = true;
    };

    # "too small" for dedicated modules

    programs.zoxide.enable = true;

    programs.bat.enable = true;
  };
}
