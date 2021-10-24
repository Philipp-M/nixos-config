{ nixpkgs-unstable, ... }:
{ pkgs, lib, config, ... }: {
  options.modules.mpd.enable = lib.mkEnableOption "Enable personal mpd config";

  config = lib.mkIf config.modules.mpd.enable {
    services.mpd = {
      enable = true;
      musicDirectory = "~/Music";
      package = nixpkgs-unstable.pkgs.mpd;
      extraConfig = ''
        audio_output {
          type            "pipewire"
          name            "pipewire"
        }
        playlist_plugin {
          name "cue"
          enabled "false"
        }
        input_cache {
          size "1 GB"
        }
      '';
    };
  };
}
