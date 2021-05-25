let
  unstableNixpkgs = builtins.fetchGit {
    url = "https://github.com/Philipp-M/nixpkgs/";
    ref = "refs/heads/init-efm-langserver";
    rev = "29cb084d24c11ed4f298e6de80beb675ad63c5d7";
  };
  jdtPkgs = import (
    builtins.fetchGit {
      url = "https://github.com/jlesquembre/nixpkgs/";
      ref = "refs/heads/jdt-ls";
      rev = "3825eb534dc07214a3607493bc101494d1fb1d7e";
    }
  ) {};
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
      nodePackages.vscode-css-languageserver-bin
      nodePackages.vscode-html-languageserver-bin
      nodePackages.vscode-json-languageserver
      nodePackages.yaml-language-server
      omnisharp-roslyn
      ripgrep
      rnix-lsp
      jdtPkgs.jdt-ls
      sumneko-lua-language-server
      tree-sitter
      yapf
      zathura
      zls
    ];

    package = (
      (
        import (
          builtins.fetchTarball {
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
