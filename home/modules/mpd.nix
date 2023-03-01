{ ... }:
{ pkgs, lib, config, ... }: {
  options.modules.mpd.enable = lib.mkEnableOption "Enable personal mpd config";

  config = lib.mkIf config.modules.mpd.enable {
    services.mpd = {
      enable = true;
      musicDirectory = "~/Music";
      network.listenAddress = "any";
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
        auto_update "yes"
      '';
    };
    systemd.user.services.mpd-mpris = {
      Service = {
        Type = "simple";
        # awful hack
        ExecStart = "${pkgs.writeShellScriptBin "delay-mpd-dris" "${pkgs.coreutils}/bin/sleep 1 && ${pkgs.mpd-mpris}/bin/mpd-mpris"}/bin/delay-mpd-dris";
      };
      Unit.PartOf = [ "mpd.socket" "mpd.service" ];
      Install.WantedBy = [ "mpd.socket" "mpd.service" ];
    };
  };
}
