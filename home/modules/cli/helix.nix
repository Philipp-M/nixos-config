{ nixpkgs-unstable, helix, nil, ... }:
{ pkgs, lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.cli.helix;
  helixPackage = helix.packages.${pkgs.system}.default.overrideAttrs (self: {
    makeWrapperArgs = with nixpkgs-unstable.pkgs;
      self.makeWrapperArgs or [ ] ++ [
        "--suffix"
        "PATH"
        ":"
        (lib.makeBinPath [
          clang-tools
          cmake-language-server
          jsonnet-language-server
          dart
          xsel
          haskell-language-server
          julia-bin
          luaformatter
          elixir_ls
          solargraph
          go
          gopls
          texlab
          taplo-cli
          pgformatter
          python3Packages.python-lsp-server
          nodePackages.bash-language-server
          nodePackages.dockerfile-language-server-nodejs
          nodePackages.pyright
          nodePackages.stylelint
          nodePackages.svelte-language-server
          nodePackages.vls
          nodePackages.vim-language-server
          nodePackages.vscode-langservers-extracted
          nodePackages.yaml-language-server
          ocamlPackages.ocaml-lsp
          ocamlPackages.dune_3
          opam
          ocamlPackages.reason
          pkgs.dotnet-sdk
          pkgs.omnisharp-roslyn
          pkgs.msbuild
          ripgrep
          rnix-lsp
          java-language-server
          sumneko-lua-language-server
          yapf
          zathura
          zls
        ])
        "--set-default"
        "RUST_SRC_PATH"
        "${rustPlatform.rustcSrc}/library"
      ];
  });
in
{
  options.modules.cli.helix.enable = mkEnableOption "Enable personal helix";

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      package = helixPackage;
      themes = {
        base16 = with config.theme.base16.colors;
          let
            gray = "#${base03.hex.rgb}";
            med-gray = "#${base02.hex.rgb}";
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
            "ui.menu" = { }; # transparent
            "ui.menu.selected" = { modifiers = [ "reversed" ]; };
            "ui.linenr" = { fg = gray; bg = dark-gray; };
            "ui.popup" = { }; # transparent
            "ui.linenr.selected" = { fg = white; bg = black; modifiers = [ "bold" ]; };
            "ui.selection" = { fg = black; bg = blue; };
            "ui.selection.primary" = { bg = med-gray; };
            "comment" = { fg = gray; };
            "ui.statusline" = { fg = white; bg = dark-gray; };
            "ui.statusline.inactive" = { fg = dark-gray; bg = white; };
            "ui.help" = { fg = gray; bg = white; };
            "ui.cursor" = { modifiers = [ "reversed" ]; };
            "ui.virtual.indent-guide" = dark-gray;
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
            "diagnostic.info" = { underline = { color = "blue"; style = "line"; }; };
            "diagnostic.hint" = { underline = { color = "green"; style = "line"; }; };
            "diagnostic.warning" = { underline = { color = "yellow"; style = "line"; }; };
            "diagnostic.error" = { underline = { color = "red"; style = "line"; }; };
            "ui.gutter" = { bg = black; };
            "info" = blue;
            "hint" = gray;
            "debug" = gray;
            "warning" = yellow;
            "error" = red;
            "tag" = blue;
            "attribute" = red;
            "markup.heading.marker" = magenta;
            "markup.heading.1" = { fg = blue; modifiers = [ "underlined" "bold" ]; };
            "markup.heading.2" = { fg = blue; modifiers = [ "bold" ]; };
            "markup.heading.3" = { fg = blue; };
            "markup.heading.4" = { fg = blue; };
            "markup.heading.5" = { fg = blue; };
            "markup.heading.6" = { fg = blue; };
            "markup.bold" = { modifiers = [ "bold" ]; };
            "markup.italic" = { modifiers = [ "italic" ]; };
            "markup.quote" = gray;
            "markup.link.url" = orange;
            "markup.link.text" = red;
            "markup.raw" = gray;
            "markup.list" = brown;
          };
      };
      languages = with nixpkgs-unstable.pkgs;
        {
          language-server = {
            efm-lsp-prettier = {
              command = "${efm-langserver}/bin/efm-langserver";
              config = {
                documentFormatting = true;
                languages = lib.genAttrs [ "typescript" "javascript" "typescriptreact" "javascriptreact" "vue" ] (_:
                  let
                    findNodeModulesCmd = bin-name: ''$(
                      if [ -z "$(command -v ''${ROOT}/node_modules/.bin/${bin-name})" ]; then
                        echo ${nodePackages."${bin-name}"}/bin/${bin-name};
                      else
                        echo ''${ROOT}/node_modules/.bin/${bin-name};
                      fi
                    )'';
                    prettierCmd = findNodeModulesCmd "prettier";
                  in
                  [{
                    formatCommand = "${prettierCmd} --stdin-filepath \${INPUT}";
                    formatStdin = true;
                  }]);
              };
            };
            eslint = {
              command = "vscode-eslint-language-server";
              args = [ "--stdio" ];
              config = {
                validate = "on";
                packageManager = "yarn";
                useESLintClass = false;
                codeActionOnSave = {
                  enable = false;
                  mode = "all";
                };
                format = true;
                quiet = false;
                onIgnoredFiles = "off";
                rulesCustomizations = [ ];
                run = "onType";
                # nodePath configures the directory in which the eslint server should start its node_modules resolution.
                # This path is relative to the workspace folder (root dir) of the server instance.
                nodePath = "";
                # use the workspace folder location or the file location (if no workspace folder is open) as the working directory
                workingDirectory.mode = "location";
                codeAction = {
                  disableRuleComment = {
                    enable = true;
                    location = "separateLine";
                  };
                  showDocumentation.enable = true;
                };
              };
            };

            typescript-language-server = {
              command = "${nodePackages.typescript-language-server}/bin/typescript-language-server";
              args = [ "--stdio" "--tsserver-path=${nodePackages.typescript}/lib/node_modules/typescript/lib" ];
              config.documentFormatting = false;
            };
            nil = {
              command = "${nil.packages.x86_64-linux.default}/bin/nil";
              config.nil.formatting.command = [ "${nixpkgs-fmt}/bin/nixpkgs-fmt" ];
            };
            rust-analyzer = {
              config.rust-analyzer = {
                cargo.loadOutDirsFromCheck = true;
                checkOnSave.command = "clippy";
                procMacro.enable = true;
                lens = { references = true; methodReferences = true; };
                completion.autoimport.enable = true;
                experimental.procAttrMacros = true;
              };
            };
            omnisharp = { command = "omnisharp"; args = [ "-l" "Error" "--languageserver" "-z" ]; };
          };
          language =
            let
              jsTsWebLanguageServers =
                [
                  { name = "typescript-language-server"; except-features = [ "format" ]; }
                  { name = "efm-lsp-prettier"; only-features = [ "format" ]; }
                  "eslint"
                ];
            in
            [
              { name = "ruby"; file-types = [ "rb" "rake" "rakefile" "irb" "gemfile" "gemspec" "Rakefile" "Gemfile" "Fastfile" "Matchfile" "Pluginfile" "Appfile" ]; }
              { name = "rust"; auto-format = false; file-types = [ "lalrpop" "rs" ]; language-servers = [ "rust-analyzer" ]; }
              { name = "c-sharp"; language-servers = [ "omnisharp" ]; }
              { name = "typescript"; language-servers = jsTsWebLanguageServers; }
              { name = "javascript"; language-servers = jsTsWebLanguageServers; }
              { name = "jsx"; language-servers = jsTsWebLanguageServers; }
              { name = "tsx"; language-servers = jsTsWebLanguageServers; }
              { name = "vue"; language-servers = [{ name = "vuels"; except-features = [ "format" ]; } { name = "efm-lsp-prettier"; } "eslint"]; }
              { name = "sql"; formatter.command = "pg_format"; }
              { name = "nix"; language-servers = [ "nil" ]; }
            ];
        };
      settings = {
        theme = "base16";
        editor = {
          indent-guides.render = true;
          rainbow-brackets = true;
          auto-pairs = false;
          lsp.display-messages = true;
          completion-trigger-len = 1;
          line-number = "relative";
          search.smart-case = false;
          scrolloff = 0;
          true-color = true;
          file-picker.hidden = false;
        };
        keys =
          let
            spaceMode = {
              space = "file_picker";
              n = "global_search";
              f = ":format";
              c = "toggle_comments";
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
              R = "replace_with_yanked";
            };
            commonMovementMappings = {
              "'" = "repeat_last_motion";
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
            };
            yankPasteMappings = {
              y = "yank_joined_to_clipboard";
              Y = "yank_main_selection_to_clipboard";
              d = [ "yank_joined_to_clipboard" "delete_selection" ];
              p = "paste_clipboard_after";
              P = "paste_clipboard_before";
              R = "replace_selections_with_clipboard";
            };
          in
          {
            normal = {
              n = [ "save_selection" "search_next" ];
              N = [ "save_selection" "search_prev" ];
              j = "move_char_left";
              h = "move_line_up";
              k = "move_line_down";
              backspace = [ "collapse_selection" "keep_primary_selection" ];
              space = spaceMode;
            } // commonMovementMappings // yankPasteMappings;
            insert."C-space" = "completion";
            select = {
              j = "extend_char_left";
              h = "extend_line_up";
              k = "extend_line_down";
              space = spaceMode;
            } // commonMovementMappings // yankPasteMappings;
          };
      };
    };
  };
}
