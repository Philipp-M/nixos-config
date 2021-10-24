{ ... }:
{ lib, config, ... }: {
  options.modules.cli.fish.enable = lib.mkEnableOption "Enable personal fish config";

  config = lib.mkIf config.modules.cli.fish.enable {
    programs.fish = {
      enable = true;
      shellInit = ''
        set fish_greeting ""

        npm set prefix $HOME/.npm/global

        set -gx PATH $HOME/.cargo/bin/ $PATH
        set -gx PATH ./node_modules/.bin/ $PATH
        set -gx PATH $HOME/.npm/global/bin/ $PATH
        set -gx PATH $HOME/.gem/*/bin/ $PATH
      '';
      shellAliases = {
        # list aliases
        ll = "lsd -Al";
        lld = "lsd -Altr";
        llt = "lsd -Altr --tree";
        lls = "lsd -ArlS --total-size";
        l = "lsd -l";
        # package/dependency management
        nx = "NIXPKGS_ALLOW_UNFREE=1 nix-shell --command fish";
        upgrade = "sudo nixos-rebuild switch --upgrade";
        update = "sudo nixos-rebuild switch";
        # shortcuts for changing the directory
        cdate = "date +%Y%m%d%H%M";
        # useful shortcuts
        lsblka = "lsblk --output NAME,LABEL,UUID,SIZE,MODEL,MOUNTPOINT,FSTYPE";
        rsyncp = "rsync --info=progress2";
        sudoe = "sudo -E";
        tree = "tree -C";
        gdiff = "git diff --no-index";
      };
    };
  };
}
