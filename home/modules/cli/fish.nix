{ chatgpt-tui, fzf-fish, ... }:
{ pkgs, lib, config, ... }: {
  options.modules.cli.fish.enable = lib.mkEnableOption "Enable personal fish config";

  config = lib.mkIf config.modules.cli.fish.enable {
    programs.fish = {
      enable = true;
      plugins = [{ name = "fzf"; src = fzf-fish; }];
      shellInit = ''
        set fish_greeting ""

        set -gx PATH $HOME/.cargo/bin/ $PATH
        set -gx PATH $HOME/.npm/global/bin/ $PATH
        set -gx PATH $HOME/.gem/*/bin/ $PATH
      '';
      shellAliases = {
        # list aliases
        ll = "lsd -Al";
        lt = "lsd -Altr";
        llt = "lsd -Altr --tree";
        lls = "lsd -ArlS --total-size";
        l = "lsd -l";
        fdh = "fd -HI";
        # package/dependency management
        nx = "NIXPKGS_ALLOW_UNFREE=1 nix-shell --command fish";
        nxd = "NIXPKGS_ALLOW_UNFREE=1 nix develop --command fish";
        upgrade = "nix flake update /home/philm/dev/personal/dotfiles/ && nixos-rebuild switch --use-remote-sudo --flake /home/philm/dev/personal/dotfiles/";
        update = "nixos-rebuild switch --use-remote-sudo --flake /home/philm/dev/personal/dotfiles/";
        # shortcuts for changing the directory
        cdate = "date +%Y%m%d%H%M";
        # useful shortcuts
        lsblka = "lsblk --output NAME,LABEL,UUID,SIZE,MODEL,MOUNTPOINT,FSTYPE";
        rsyncp = "rsync --info=progress2";
        sudoe = "sudo -E";
        tree = "tree -C";
        gdiff = "git diff --no-index";
        chat = "${chatgpt-tui.packages.${pkgs.system}.default}/bin/chatgpt-tui";
      };
    };
  };
}
