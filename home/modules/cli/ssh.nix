{ ... }:
{ lib, config, ... }: {
  options.modules.cli.ssh.enable = lib.mkEnableOption "Enable personal ssh config";

  config = lib.mkIf config.modules.cli.ssh.enable {
    services.gnome-keyring = {
      enable = true;
      components = [ "pkcs11" "secrets" "ssh" ];
    };

    # just to be safe set SSH_AUTH_SOCK everywhere...
    xsession.profileExtra = ''
      export SSH_AUTH_SOCK=/run/user/$(id -u)/keyring/ssh
    '';
    programs.fish.shellInit = ''
      set -gx SSH_AUTH_SOCK /run/user/(id -u)/keyring/ssh
    '';

    programs.ssh = {
      enable = true;
      serverAliveInterval = 240;
      # TODO whitelist this for only a selected number of hosts
      extraConfig = ''
        ForwardX11 yes
        ForwardX11Trusted yes
      '';
    };
  };
}
