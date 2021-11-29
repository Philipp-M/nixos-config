{ nixpkgs-unstable, nixpkgs-personal, ... }:
{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf hasAttrByPath;
  inherit (builtins) isAttrs isFunction;
  cfg = config.modules.cli.neovim;
in
{
  options.modules.cli.neovim.enable = mkEnableOption "Enable personal neovim";

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      package = nixpkgs-unstable.pkgs.neovim-nightly;
      extraPackages = with nixpkgs-unstable.pkgs; [
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
        taplo-lsp
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
        ocamlPackages.reason
        omnisharp-roslyn
        msbuild
        ripgrep
        rnix-lsp
        nixpkgs-personal.pkgs.jdt-ls
        sumneko-lua-language-server
        tree-sitter
        yapf
        zathura
        zls
      ];
    };

    # neovim base16 themes with transparency support
    home.file.".config/nvim/colors/base16.vim" = {
      source = (config.lib.theme.compileTemplate
        { name = "base16-vim"; src = ./colorscheme-base16.template.vim; });
    };

    home.activation.linkNeovimConfs = ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/.config/nvim
      $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
        ${builtins.toPath ./init.lua} $HOME/.config/nvim/init.lua
      $DRY_RUN_CMD ln -fs --no-dereference $VERBOSE_ARG \
        ${builtins.toPath ./lua} $HOME/.config/nvim/lua
    '';
  };
}
