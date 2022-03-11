{ nixpkgs-unstable, nixpkgs-personal, helix, ... }:
{ pkgs, lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.cli.helix;
in
{
  options.modules.cli.helix.enable = mkEnableOption "Enable personal helix";

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      package = helix.packages.x86_64-linux.helix;
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
            brown = "#${base0F.hex.rgb}";
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
            "punctuation" = brown;
            "operator" = brown;
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
      languages = [
        { name = "rust"; auto-format = false; }
        {
          name = "c-sharp";
          language-server = { command = "omnisharp"; args = [ "-l" "Error" "--languageserver" "-z" ]; };
        }
      ];
      settings = {
        theme = "base16";
        lsp.display-messages = true;
        editor = {
          completion-trigger-len = 1;
          line-number = "relative";
          search.smart-case = false;
          scrolloff = 0;
          true-color = true;
          file-picker.hidden = false;
        };
        keys = {
          normal = {
            "'" = "repeat_last_motion";
            j = "move_char_left";
            h = "move_line_up";
            k = "move_line_down";
            y = "yank_joined_to_clipboard";
            Y = "yank_main_selection_to_clipboard";
            d = [ "yank_joined_to_clipboard" "delete_selection" ];
            p = "paste_clipboard_after";
            P = "paste_clipboard_before";
            g.j = "goto_line_start";
            z.k = "scroll_down";
            z.h = "scroll_up";
            Z.k = "scroll_down";
            Z.h = "scroll_up";
            "C-y" = "scroll_up";
            "C-e" = "scroll_down";
            "C-w" = {
              "C-k" = "jump_view_down";
              "k" = "jump_view_down";
              "C-h" = "jump_view_up";
              "h" = "jump_view_up";
              "C-j" = "jump_view_left";
              "j" = "jump_view_left";
            };
            backspace = [ "collapse_selection" "keep_primary_selection" ];
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
              y = "yank";
              p = "paste_after";
              P = "paste_before";
            };
          };
          select = {
            d = [ "yank_joined_to_clipboard" "delete_selection" ];
            j = "extend_char_left";
            h = "extend_line_up";
            k = "extend_line_down";
            y = "yank_joined_to_clipboard";
            Y = "yank_main_selection_to_clipboard";
            p = "paste_clipboard_after";
            P = "paste_clipboard_before";
            space = {
              y = "yank";
              p = "paste_after";
              P = "paste_before";
            };
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
      pkgs.dotnet-sdk
      pkgs.omnisharp-roslyn
      pkgs.msbuild
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
