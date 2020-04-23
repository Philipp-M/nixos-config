{ pkgs, ... }: {
  home.sessionVariables.EDITOR = "nvim";

  # X specific
  home.keyboard.variant = "colemak";
  home.keyboard.layout = "us";

  xsession = {
    enable = true;
    windowManager = {
      xmonad = {
        enable = true;
        extraPackages = hpkgs: [
          hpkgs.xmonad-contrib
          hpkgs.xmonad-extras
          hpkgs.monad-logger
          hpkgs.taffybar
        ];
        enableContribAndExtras = true;
        config = ../xmonad/xmonad.hs;
      };
    };
  };

  # List of user services

  services.taffybar = {
    enable = true;
    package = (import ../config/taffybar/default.nix);
  };

  services.picom = {
    enable = true;
    experimentalBackends = true;
    backend = "glx";
    blur = true;
    blurMethod = "dual_kawase";
    blurStrength = 10;
    vSync = false;
    fade = true;
    fadeDelta = 8;
    fadeSteps = [ "0.10" "0.035" ];
    inactiveDim = "0.1";
    extraOptions = "unredir-if-possible = false";
  };

  services.redshift = {
    enable = true;
    latitude = "47.267";
    longitude = "11.383";
    brightness.day = "1";
    brightness.night = "0.8";
    temperature.day = 6500;
    temperature.night = 3200;
  };

  services.random-background = {
    enable = true;
    imageDirectory = "%h/dev/personal/dotfiles/wallpaper/";
  };

  # List of user programs

  programs.home-manager.enable = true;

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
    };
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx PATH $HOME/.cargo/bin/ $PATH
      set fish_greeting ""
    '';
    shellAliases = {
      ll = "lsd -Al";
      lld = "lsd -Altr";
      llt = "lsd -Altr --tree";
      lls = "lsd -ArlS --total-size";
      l = "lsd -l";
      lsblka = "lsblk --output NAME,LABEL,UUID,SIZE,MODEL,MOUNTPOINT,FSTYPE";
      tree = "tree -C";
      cdot = "cd $HOME/dev/personal/dotfiles";
      cdgo = "cd $HOME/dev/personal/go/src";
      cdrust = "cd $HOME/dev/personal/rust";
      cdpy = "cd $HOME/dev/personal/python";
      cddocker = "cd $HOME/dev/docker";
      cddev = "cd $HOME/dev";
      cdwww = "cd $HOME/dev/www";
      cdpro = "cd $HOME/dev/projects";
      cdvox = "cd $HOME/dev/projects/voxinfinity";
      cdvue = "cd $HOME/dev/vue";
      cdeth = "cd $HOME/dev/ethereumBased";
      cdvul = "cd $HOME/dev/vulkan";
      cdgql = "cd $HOME/dev/GraphQL";
      cdwork = "cd $HOME/dev/work";
      cdnode = "cd $HOME/dev/nodeBased";
      cdml = "cd $HOME/dev/MachineLearning";
      cduni = "cd $HOME/Uni";
      cdrand = "cd $HOME/dev/randomStuff";
      cdrandrs = "cd $HOME/dev/randomStuff/rust";
      cdsmall = "cd $HOME/dev/randomStuff/small";
      cdray = "cd $HOME/dev/rayTracing";
      cdandroid = "cd $HOME/dev/Android";
      cdate = "date +%Y%m%d%H%M";
      dus = "du -h | sort -h";
      rsyncp = "rsync --info=progress2";
      sudoe = "sudo -E";
    };
    plugins = [{
      name = "fasd";
      src = pkgs.fetchFromGitHub {
        owner = "oh-my-fish";
        repo = "plugin-fasd";
        rev = "38a5b6b6011106092009549e52249c6d6f501fba";
        sha256 = "06v37hqy5yrv5a6ssd1p3cjd9y3hnp19d3ab7dag56fs1qmgyhbs";
      };
    }];
  };

  programs.autorandr = {
    enable = true;
    profiles = {
      "zen" = {
        fingerprint = {
          "DP-0" =
            "00ffffffffffff0004721304c738804326180104a53c22783e4dd5a7554a9d240e5054bfef8081c0810081809500b3008140d1c0714f4dd000a0f0703e8030203500544f2100001a04740030f2705a80b0588a00544f2100001a000000fd0017501ea03c010a202020202020000000fc00414345522042323736484b0a200104020329f14f9001020304051112131f140607202223090707830100006c030c002000007820004001030e1f008051001e3040803700544f2100001c023a801871382d40582c4500544f2100001e565e00a0a0a0295030203500544f2100001a0000000000000000000000000000000000000000000000000000000000000000de";
          "DP-2" =
            "00ffffffffffff00410c42c105000000341a0104b55932783a1571ad5047a726125054bfef00d1c0b30095008180814081c0010101014dd000a0f0703e803020350075f23100001aa36600a0f0701f803020350075f23100001a000000fd0017501ea03c010a202020202020000000fc0050484c2042444d34303337550a0176020326f14b0103051404131f1202119023090707830100006d030c0020001878200060010203011d007251d01e206e28550075f23100001e8c0ad08a20e02d10103e960075f2310000188c0ad090204031200c40550075f2310000184d6c80a070703e8030203a0075f23100001a000000000000000000000000000000000025";
        };
        config = {
          "DP-0" = {
            position = "0x0";
            primary = false;
            mode = "3840x2160";
          };
          "DP-2" = {
            position = "3840x0";
            primary = false;
            mode = "3840x2160";
          };
        };
      };
    };
  };

  # git
  programs.git = {
    enable = true;
    userName = "Philipp Mildenberger";
    userEmail = "philipp.mildenberger@koeln.de";
    lfs.enable = true;
    extraConfig.core.pager = "diff-so-fancy | less --tabs=4 -RFX";
  };
}
