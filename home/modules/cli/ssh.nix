{ ... }:
{ lib, config, ... }: {
  options.modules.cli.ssh.enable = lib.mkEnableOption "Enable personal ssh config";

  config = lib.mkIf config.modules.cli.ssh.enable {

    home.file.".ssh/config".target = ".ssh/config_source";

    home.activation.installSshConfig =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD install -m 400 "$HOME/.ssh/config_source" "$HOME/.ssh/config"
      '';

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      # TODO whitelist this for only a selected number of hosts
      settings."*" = {
        ServerAliveInterval = 30;
        ServerAliveCountMax = 4;
        TCPKeepAlive = "yes";
        ForwardX11 = "yes";
        ForwardX11Trusted = "yes";
        AddKeysToAgent = "yes";
        Compression = true;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    };
  };
}
