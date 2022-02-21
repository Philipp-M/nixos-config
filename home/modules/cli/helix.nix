{ nixpkgs-unstable, nixpkgs-personal, ... }:
{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.cli.helix;
in
{
  options.modules.cli.helix.enable = mkEnableOption "Enable personal helix";

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      # doesn't work with flakes because of non-working submodules
      # package = helix.packages.x86_64-linux.helix;
      package = nixpkgs-unstable.pkgs.helix.overrideAttrs
        (
          old: rec {
            version = "0.5-git";
            src = builtins.fetchGit {
              url = "https://github.com/Philipp-M/helix.git";
              ref = "rounded-corners";
              rev = "834abf3ea3833c9e972f80a03a567fb3b8bdcae2";
              submodules = true;
            };
            cargoDeps = old.cargoDeps.overrideAttrs (lib.const {
              inherit src;
              outputHash = "sha256-XjQS18SVAFhmQCyDIaMLKODNE8UgCYtj+vJ7t4DrMtw=";
            });
          }
        );
      themes = {
        base16 = with config.theme.base16.colors;
          let
            transparent = "none";
            gray = "#${base03.hex.rgb}";
            dark-gray = "#${base01.hex.rgb}";
            white = "#${base05.hex.rgb}";
            black = "#${base00.hex.rgb}";
            red = "#${base08.hex.rgb}";
            green = "#${base0B.hex.rgb}";
            yellow = "#${base0A.hex.rgb}";
            orange = "#${base09.hex.rgb}";
            blue = "#${base0D.hex.rgb}";
            magenta = "#${base0E.hex.rgb}";
            cyan = "#${base0C.hex.rgb}";
          in
          {
            "ui.menu" = transparent;
            "ui.menu.selected" = { modifiers = [ "reversed" ]; };
            "ui.linenr" = { fg = gray; bg = dark-gray; };
            "ui.popup" = { bg = transparent; };
            "ui.linenr.selected" = { fg = white; bg = black; modifiers = [ "bold" ]; };
            "ui.selection" = { fg = black; bg = blue; };
            # "ui.selection.primary" = { fg = white; bg = blue; };
            "ui.selection.primary" = { modifiers = [ "reversed" ]; };
            "comment" = { fg = gray; };
            "ui.statusline" = { fg = white; bg = dark-gray; };
            "ui.statusline.inactive" = { fg = dark-gray; bg = white; };
            "ui.help" = { fg = dark-gray; bg = white; };
            "ui.cursor" = { modifiers = [ "reversed" ]; };
            "variable" = red;
            "variable.builtin" = orange;
            "constant.numeric" = orange;
            "constant" = orange;
            "attributes" = yellow;
            "type" = yellow;
            "ui.cursor.match" = { fg = yellow; modifiers = [ "underlined" ]; };
            "string" = green;
            "variable.other.member" = red;
            "constant.character.escape" = cyan;
            "function" = blue;
            "constructor" = blue;
            "special" = blue;
            "keyword" = magenta;
            "label" = magenta;
            "namespace" = blue;
            "diff.plus" = green;
            "diff.delta" = yellow;
            "diff.minus" = red;
            "diagnostic" = { modifiers = [ "underlined" ]; };
            "ui.gutter" = { bg = black; };
            "info" = blue;
            "hint" = dark-gray;
            "debug" = dark-gray;
            "warning" = yellow;
            "error" = red;
          };
      };
      languages = [{ name = "rust"; auto-format = false; }];
      settings = {
        theme = "base16";
        lsp.display-messages = true;
        editor = {
          completion-trigger-len = 0;
          line-number = "relative";
          scrolloff = 0;
          true-color = true;
        };
        keys = {
          normal = {
            "'" = "repeat_last_motion";
            j = "move_char_left";
            h = "move_line_up";
            k = "move_line_down";
            g.j = "goto_line_start";
            z.k = "scroll_down";
            z.h = "scroll_up";
            Z.k = "scroll_down";
            Z.h = "scroll_up";
            "C-w" = {
              "C-k" = "jump_view_down";
              "k" = "jump_view_down";
              "C-h" = "jump_view_up";
              "h" = "jump_view_up";
              "C-j" = "jump_view_left";
              "j" = "jump_view_left";
            };
            space = {
              space = "file_picker";
              f = ":format";
              t = {
                t = "goto_definition";
                i = "goto_implementation";
                r = "goto_reference";
                d = "goto_type_definition";
              };
              d = {
                s = "signature_help";
                d = "hover";
              };
              x = ":buffer-close";
              w = ":w";
              q = ":q";
            };
          };
          select = {
            j = "extend_char_left";
            h = "extend_line_up";
            k = "extend_line_down";
          };
        };
      };
    };
    # TODO sandbox these packages into helix
    home.packages = with nixpkgs-unstable.pkgs; [
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
      dotnet-sdk
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
}
