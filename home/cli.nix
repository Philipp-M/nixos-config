# This contains most CLI related stuff
{ pkgs, lib, config, ... }: {
  imports = [ ./neovim ];
  home.sessionVariables.EDITOR = "nvim";

  # custom home files, currently mostly base16 templates

  programs.ssh = {
    enable = true;
    serverAliveInterval = 240;
  };

  programs.zoxide.enable = true;

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

  programs.fish = {
    enable = true;
    shellInit = ''
      set fish_greeting ""

      npm set prefix $HOME/.npm/global

      set -gx PATH $HOME/.cargo/bin/ $PATH
      set -gx PATH ./node_modules/.bin/ $PATH
      set -gx PATH $HOME/.npm/global/bin/ $PATH
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

  programs.bat.enable = true;

  programs.tmux = {
    enable = true;
    extraConfig = ''
      set-window-option -g xterm-keys on
      set -sg escape-time 0
      set -g mouse on
      set -g default-terminal "alacritty"
      set-option -ga terminal-overrides "alacritty:Tc"
    '';
  };

  # git
  programs.git = {
    enable = true;
    userName = "Philipp Mildenberger";
    userEmail = "philipp@mildenberger.me";
    lfs.enable = true;
    delta.enable = true;
    extraConfig = {
      pull.rebase = true;
      rerere.enabled = true;
    };
    extraConfig.init.defaultBranch = "main";
    aliases = {
      pushall = "!git remote | xargs -L1 git push --all";
      spull = "!git stash && git pull && git stash pop";
    };
  };
}
