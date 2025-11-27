{ ... }:
{ pkgs, lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.cli.neovim;
in
{
  options.modules.cli.neovim.enable = mkEnableOption "Enable personal neovim";

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      extraPackages = with pkgs; [
        clang-tools
        cmake-language-server
        dart
        efm-langserver
        fzf
        xsel
        haskellPackages.ormolu # haskell formatter
        # julia
        # luaformatter
        # nixfmt
        taplo
        pyright
        nodePackages.bash-language-server
        nodePackages.dockerfile-language-server-nodejs
        nodePackages.eslint
        nodePackages.prettier
        nodePackages.stylelint
        nodePackages.svelte-language-server
        nodePackages.typescript-language-server
        nodePackages.vim-language-server
        # nodePackages.vls
        nodePackages.vscode-langservers-extracted
        nodePackages.yaml-language-server
        ocamlPackages.ocaml-lsp
        ocamlPackages.reason
        ripgrep
        # rnix-lsp
        java-language-server
        lua-language-server
        tree-sitter
        yapf
        zathura
        zls
      ];
    };

    # TODO clean this up, so that helix and neovim can access the same instance
    home.packages = with pkgs; [
      dotnet-sdk
      omnisharp-roslyn
      msbuild
    ];

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
