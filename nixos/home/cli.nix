# This contains most CLI related stuff
{ pkgs, lib, config, ... }: {
  home.sessionVariables.EDITOR = "nvim";

  # custom home files, currently mostly base16 templates

  # neovim base16 themes with transparency support
  home.file.".config/nvim/colors/base16.vim".source =
    config.lib.base16.template {
      name = "base16-vim";
      src = ../../config/nvim/colors/base16.template.vim;
    };

  home.file.".config/nvim/autoload/airline/themes/base16.vim".source =
    config.lib.base16.template {
      name = "base16-vim-airline";
      src = ../../config/nvim/autoload/airline/themes/base16.template.vim;
    };

  programs.ssh = {
    enable = true;
    serverAliveInterval = 240;
  };

  programs.zoxide.enable = true;

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character.symbol = "";
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
      nx = "nix-shell --command fish";
      upgrade =
        "sudo nixos-rebuild switch --upgrade"; # dangerous use of sudo, don't do it at home (but it's comfortable)
      update =
        "sudo nixos-rebuild switch"; # dangerous use of sudo, don't do it at home (but it's comfortable)
      # shortcuts for changing the directory
      cdwork = "cd $HOME/dev/work";
      cdev = "cd $HOME/dev/personal";
      cdenv = "cd $HOME/dev/personal/desktop-environment";
      cdot = "cd $HOME/dev/personal/dotfiles";
      cdgo = "cd $HOME/dev/personal/go/src";
      cdc = "cd $HOME/dev/personal/c";
      cdelx = "cd $HOME/dev/personal/elixir";
      cdrust = "cd $HOME/dev/personal/rust";
      cdhs = "cd $HOME/dev/personal/haskell";
      cdpy = "cd $HOME/dev/personal/python";
      cddocker = "cd $HOME/dev/docker";
      cdwww = "cd $HOME/dev/personal/www";
      cdvue = "cd $HOME/dev/personal/www/vue";
      cdpro = "cd $HOME/dev/projects";
      cdvox = "cd $HOME/dev/projects/voxinfinity";
      cdvul = "cd $HOME/dev/vulkan";
      cdgql = "cd $HOME/dev/GraphQL";
      cdnode = "cd $HOME/dev/nodeBased";
      cdml = "cd $HOME/dev/MachineLearning";
      cdl = "cd $HOME/dev/personal/deep-learning/";
      cduni = "cd $HOME/Uni";
      cdrand = "cd $HOME/dev/randomStuff";
      cdrandrs = "cd $HOME/dev/randomStuff/rust";
      cdsmall = "cd $HOME/dev/randomStuff/small";
      cdray = "cd $HOME/dev/rayTracing";
      cdandroid = "cd $HOME/dev/Android";
      cdate = "date +%Y%m%d%H%M";
      # useful shortcuts
      dus = "du -h | sort -h";
      lsblka = "lsblk --output NAME,LABEL,UUID,SIZE,MODEL,MOUNTPOINT,FSTYPE";
      rsyncp = "rsync --info=progress2";
      sudoe = "sudo -E";
      tree = "tree -C";
      gdiff = "git diff --no-index";
    };
  };

  programs.bat = {
    enable = true;
    config = { theme = "base16"; };
    themes = {
      base16 = builtins.readFile (toString (config.lib.base16.template {
        name = "base16-bat";
        src = ../../config/bat-base16.template.tmTheme;
      }));
    };
  };

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
    userEmail = "philipp.mildenberger@koeln.de";
    lfs.enable = true;
    delta.enable = true;
    extraConfig.pull.rebase = true;
    aliases = {
      pushall = "!git remote | xargs -L1 git push --all";
      spull = "!git stash && git pull && git stash pop";
    };
  };
}
