{ ... }:
{ pkgs, lib, config, ... }: {
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

    # Don't scan ~: stat() on network mounts can hang indefinitely.
    xdg.configFile."starship-home.toml".source = (pkgs.formats.toml { }).generate "starship-home.toml"
      (lib.recursiveUpdate config.programs.starship.settings {
        format = "$username$hostname$shlvl$directory$cmd_duration$line_break$jobs$battery$time$status$os$shell$character";
        directory.truncate_to_repo = false;
      });
    xdg.configFile."fish/conf.d/starship-home.fish".text = lib.mkIf config.programs.fish.enable ''
      function __starship_home --on-event fish_prompt
          set -gx STARSHIP_CONFIG ${lib.escapeShellArg "${config.xdg.configHome}/starship.toml"}
          test "$PWD" != "$HOME"; or set -gx STARSHIP_CONFIG ${lib.escapeShellArg "${config.xdg.configHome}/starship-home.toml"}
      end
    '';
  };
}
