{ ... }:
{ lib, config, ... }: {
  options.modules.cli.starship.enable = lib.mkEnableOption "Enable personal starship config";

  config = lib.mkIf config.modules.cli.starship.enable {
    programs.starship = {
      enable = true;
      settings = {
        add_newline = false;
        directory.truncation_length = 8;
        cmd_duration = {
          min_time = 10;
          show_milliseconds = true;
        };
        time.disabled = false;
      };
    };
  };
}
