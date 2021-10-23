let
  unstableNixpkgs = builtins.fetchGit {
    shallow = true;
    url = "https://github.com/Philipp-M/nixpkgs/";
    ref = "refs/heads/personal";
    rev = "1f461f5d60ac6523499d8986188b0862caa42362";
  };
  unstablePkgs = import unstableNixpkgs {};
in
{ lib, config, ... }: {
  programs.neovim = {
    enable = true;
    extraPackages = with unstablePkgs; [
      clang-tools
      cmake-language-server
      dart
      efm-langserver
      fzf
      xsel
      haskellPackages.ormolu # haskell formatter
      # julia
      luaformatter
      nixfmt
      nodePackages.bash-language-server
      nodePackages.dockerfile-language-server-nodejs
      nodePackages.eslint
      nodePackages.prettier
      nodePackages.pyright
      nodePackages.stylelint
      nodePackages.svelte-language-server
      nodePackages.typescript-language-server
      nodePackages.vim-language-server
      nodePackages.vls
      nodePackages.vscode-langservers-extracted
      nodePackages.yaml-language-server
      ocamlPackages.ocaml-lsp
      omnisharp-roslyn
      msbuild
      ripgrep
      rnix-lsp
      jdt-ls
      sumneko-lua-language-server
      tree-sitter
      yapf
      zathura
      zls
    ];

    # package = unstablePkgs.neovim-unwrapped;
    package = (
      (
        import (
          builtins.fetchTarball {
            # url = https://github.com/nix-community/neovim-nightly-overlay/archive/67f9deafd1949745eb1b35972746b07ec32f7778.tar.gz;
            url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
          }
        )
      ) {} unstablePkgs
    ).neovim-nightly;
  };

  # neovim base16 themes with transparency support
  home.file.".config/nvim/colors/base16.vim".source = config.lib.theme.template
    { name = "base16-vim"; src = ./colorscheme-base16.template.vim; };

  home.activation.linkNeovimConfs = ''
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/.config/nvim
    $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
      ${builtins.toPath ./init.lua} $HOME/.config/nvim/init.lua
    $DRY_RUN_CMD ln -fs --no-dereference $VERBOSE_ARG \
      ${builtins.toPath ./lua} $HOME/.config/nvim/lua
  '';
}
