{ ... }:
{ lib, config, ... }: {
  options.modules.cli.ssh.enable = lib.mkEnableOption "Enable personal ssh config";

  config = lib.mkIf config.modules.cli.ssh.enable {

    home.file.".ssh/config" = {
      target = ".ssh/config_source";
      onChange = ''cat ~/.ssh/config_source > ~/.ssh/config && chmod 400 ~/.ssh/config'';
    };

    programs.ssh = {
      enable = true;
      serverAliveInterval = 240;
      # TODO whitelist this for only a selected number of hosts
      extraConfig = ''
        ForwardX11 yes
        ForwardX11Trusted yes
        Host *
        AddKeysToAgent yes
      '';
    };
  };
}
