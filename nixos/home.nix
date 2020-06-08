{ pkgs, lib, config, ... }: {
  imports = [
    (import "${
        (builtins.fetchTarball {
          url =
            "https://github.com/atpotts/base16-nix/archive/4f192afaa0852fefb4ce3bde87392a0b28d6ddc8.tar.gz";
          sha256 = "1yf59vpd1i8lb2ml7ha8v6i4mv1b0xwss8ngzw08s39j838gyx6h";
        })
      }/base16.nix")
  ];

  themes.base16 = {
    enable = true;
    scheme = "gruvbox";
    variant = "gruvbox-dark-medium";
    extraParams = {
      fontname = "FiraCode Nerd Font";
      xftfontextra = ":style=Regular";
      fontsize = "14";
      dpi = "100";
    };
  };

  home.sessionVariables.EDITOR = "nvim";

  # X specific
  home.keyboard.variant = "colemak";
  home.keyboard.layout = "us";

  xsession = {
    enable = true;
    initExtra = ''
      # Remap Escape to 'Hyper_L' for an extra 'hybrid' modifier for xmonad and other applications that use Super
      # Caps Lock is useless anyway, so remap it to 'Escape' to provide comfort in vim...
      # Unfortunately Alacritty (or more precisely winit) has a bug with xmodmap modifier remappings...
      ${pkgs.xorg.xmodmap}/bin/xmodmap  \
              -e 'keycode 23 = Hyper_L'  \
              -e 'clear Lock'           \
              -e 'keycode 66 = Escape' \
              -e 'keycode any = Tab' \
      # Currently the service xcape in home-manager doesn't work correctly
      # (my guess is because xcape is started before the script above)
      # The following line is used for reenabling Escape if it is used on its own (single tap which takes under 500ms)
      ${pkgs.xcape}/bin/xcape -e 'Hyper_L=Tab'
    '';
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
        config = builtins.toPath (config.lib.base16.template {
          name = "xmonad";
          src = ../xmonad/xmonad.hs;
        });
      };
    };
  };

  # custom home files, currently mostly base16 templates

  home.file.".Xresources".source = config.lib.base16.template {
    name = "Xresources";
    src = ../Xresources;
  };

  home.file.".config/nvim/colors/base16.vim".source =
    config.lib.base16.template {
      name = "base16-vim";
      src = ../config/nvim/base16.vim.template;
    };

  home.file.".config/nvim/autoload/airline/themes/base16.vim".source =
    config.lib.base16.template {
      name = "base16-vim-airline";
      src = ../config/nvim/autoload/airline/themes/base16.vim;
    };

  # List of user services

  services.taffybar = {
    enable = true;
    package = (import ../config/taffybar/default.nix);
  };

  home.file.".config/taffybar/taffybar.css".source =
    config.lib.base16.template {
      name = "taffybar.css";
      src = ../config/taffybar/taffybar.css;
    };

  services.picom = {
    enable = true;
    experimentalBackends = true;
    backend = "glx";
    blur = true;
    blurMethod = "dual_kawase";
    blurStrength = 10;
    vSync = false;
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

  services.status-notifier-watcher.enable = true;

  services.xembed-sni-proxy.enable = true;

  # List of user programs

  programs.home-manager.enable = true;

  programs.alacritty = with config.lib.base16.theme; {
    enable = true;
    settings = {
      live_config_reload = true;
      scrolling = {
        history = 100000; # max amount
        multiplier = 5;
      };
      custom_cursor_colors = false;
      background_opacity = 0.9;
      font.normal.family = fontname;
      colors = {
        primary = {
          background = "#${base00-hex}";
          foreground = "#${base06-hex}";
        };
        normal = {
          black = "#${base00-hex}";
          red = "#${base08-hex}";
          green = "#${base0B-hex}";
          yellow = "#${base0A-hex}";
          blue = "#${base0D-hex}";
          magenta = "#${base0E-hex}";
          cyan = "#${base0C-hex}";
          white = "#${base05-hex}";
        };
      };
    };
  };

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

  programs.rofi = {
    enable = true;
    theme = builtins.toPath (config.lib.base16.template {
      name = "rofi";
      src = ../config/rofi/theme.rasi;
    });
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
      update = "sudo nixos-rebuild switch --upgrade"; # dangerous use of sudo, don't do it at home (but it's comfortable)
      # shortcuts for changing the directory
      cdwork = "cd $HOME/dev/work";
      cdev = "cd $HOME/dev/personal";
      cdot = "cd $HOME/dev/personal/dotfiles";
      cdgo = "cd $HOME/dev/personal/go/src";
      cdc = "cd $HOME/dev/personal/c";
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
    extraConfig.core.pager = "diff-so-fancy | less --tabs=4 -RFX";
    aliases = { pushall = "!git remote | xargs -L1 git push --all"; };
  };

  programs.mpv = {
    enable = true;
    config = {
      x11-netwm = "yes"; # necessary for xmonads fullscreen
      profile = "vdpau-high";
      video-sync = "audio";
    };
    profiles = {
      vdpau-high = {
        vo = "vdpau";
        profile = "opengl-hq";
        scale = "ewa_lanczossharp";
        cscale = "ewa_lanczossharp";
        video-sync = "display-resample";
        interpolation = "yes";
        tscale = "oversample";
        vf = "vdpaupp:deint=yes:deint-mode=temporal-spatial:hqscaling=1";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      vdpau-low = {
        vo = "vdpau";
        profile = "opengl-hq";
        video-sync = "display-resample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      opengl-high = {
        vo = "opengl";
        profile = "opengl-hq";
        scale = "ewa_lanczossharp";
        cscale = "ewa_lanczossharp";
        video-sync = "display-resample";
        interpolation = "yes";
        tscale = "oversample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      opengl-low = {
        vo = "opengl";
        profile = "opengl-hq";
        video-sync = "display-resample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      xv-high = {
        vo = "xv";
        profile = "opengl-hq";
        scale = "ewa_lanczossharp";
        cscale = "ewa_lanczossharp";
        video-sync = "display-resample";
        interpolation = "yes";
        tscale = "oversample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      xv-low = {
        vo = "xv";
        profile = "opengl-hq";
        video-sync = "display-resample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      fun = { vo = "tct"; };
    };
  };

}
