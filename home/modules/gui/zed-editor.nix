{ ... }:
{ pkgs, lib, config, ... }:
let
  c = config.theme.base16.colors;
  themeName = builtins.replaceStrings [ "-" ] [ " " ] config.theme.base16.name;
  hex = x: "#${x.hex.rgb}ff";
  alpha = a: x: "#${x.hex.rgb}${a}";
  status = n: x: {
    "${n}" = hex x;
    "${n}.background" = alpha "1a" x;
    "${n}.border" = alpha "66" x;
  };
  mutedStatus = n: x: {
    "${n}" = hex x;
    "${n}.background" = hex c.base01;
    "${n}.border" = hex c.base02;
  };
  player = x: {
    cursor = hex x;
    background = hex x;
    selection = alpha "3d" x;
  };
  syntax = x: {
    color = hex x;
    font_style = null;
    font_weight = null;
  };
  syntaxItalic = x: (syntax x) // { font_style = "italic"; };
  syntaxBold = x: (syntax x) // { font_weight = 700; };
  zedTheme = with c; {
    "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
    name = themeName;
    author = config.theme.base16.author or "Generated from home/modules/theme.nix";
    themes = [{
      name = themeName;
      appearance = "dark";
      style =
        {
          accents = map hex [ base08 base0B base0A base0D base0E base0C base09 ];
          background = hex base02;
          border = hex base02;
          "border.variant" = hex base01;
          "border.focused" = hex base0D;
          "border.selected" = hex base0D;
          "border.transparent" = "#00000000";
          "border.disabled" = hex base02;
          "elevated_surface.background" = hex base01;
          "surface.background" = hex base01;
          "element.background" = hex base01;
          "element.hover" = hex base02;
          "element.active" = hex base02;
          "element.selected" = hex base02;
          "element.disabled" = hex base01;
          "drop_target.background" = alpha "80" base0D;
          "ghost_element.background" = "#00000000";
          "ghost_element.hover" = hex base02;
          "ghost_element.active" = hex base02;
          "ghost_element.selected" = hex base02;
          "ghost_element.disabled" = hex base01;
          text = hex base05;
          "text.muted" = hex base04;
          "text.placeholder" = hex base03;
          "text.disabled" = hex base03;
          "text.accent" = hex base0D;
          icon = hex base05;
          "icon.muted" = hex base04;
          "icon.disabled" = hex base03;
          "icon.placeholder" = hex base04;
          "icon.accent" = hex base0D;
          "status_bar.background" = hex base02;
          "title_bar.background" = hex base02;
          "title_bar.inactive_background" = hex base01;
          "toolbar.background" = hex base00;
          "tab_bar.background" = hex base01;
          "tab.inactive_background" = hex base01;
          "tab.active_background" = hex base00;
          "search.match_background" = alpha "66" base0D;
          "search.active_match_background" = alpha "66" base0A;
          "panel.background" = hex base01;
          "panel.focused_border" = hex base0D;
          "pane.focused_border" = null;
          "scrollbar.thumb.active_background" = alpha "ac" base0D;
          "scrollbar.thumb.hover_background" = alpha "4c" base05;
          "scrollbar.thumb.background" = alpha "4c" base03;
          "scrollbar.thumb.border" = hex base01;
          "scrollbar.track.background" = "#00000000";
          "scrollbar.track.border" = hex base01;
          "editor.foreground" = hex base05;
          "editor.background" = hex base00;
          "editor.gutter.background" = hex base00;
          "editor.subheader.background" = hex base01;
          "editor.active_line.background" = alpha "bf" base01;
          "editor.highlighted_line.background" = hex base01;
          "editor.line_number" = hex base03;
          "editor.active_line_number" = hex base06;
          "editor.hover_line_number" = hex base04;
          "editor.invisible" = hex base03;
          "editor.wrap_guide" = alpha "0d" base05;
          "editor.active_wrap_guide" = alpha "1a" base05;
          "editor.document_highlight.read_background" = alpha "1a" base0D;
          "editor.document_highlight.write_background" = alpha "66" base02;
          "terminal.background" = hex base00;
          "terminal.foreground" = hex base05;
          "terminal.bright_foreground" = hex base07;
          "terminal.dim_foreground" = hex base03;
          "terminal.ansi.black" = hex base00;
          "terminal.ansi.bright_black" = hex base03;
          "terminal.ansi.dim_black" = hex base01;
          "terminal.ansi.red" = hex base08;
          "terminal.ansi.bright_red" = hex base08;
          "terminal.ansi.dim_red" = hex base08;
          "terminal.ansi.green" = hex base0B;
          "terminal.ansi.bright_green" = hex base0B;
          "terminal.ansi.dim_green" = hex base0B;
          "terminal.ansi.yellow" = hex base0A;
          "terminal.ansi.bright_yellow" = hex base0A;
          "terminal.ansi.dim_yellow" = hex base0A;
          "terminal.ansi.blue" = hex base0D;
          "terminal.ansi.bright_blue" = hex base0D;
          "terminal.ansi.dim_blue" = hex base0D;
          "terminal.ansi.magenta" = hex base0E;
          "terminal.ansi.bright_magenta" = hex base0E;
          "terminal.ansi.dim_magenta" = hex base0E;
          "terminal.ansi.cyan" = hex base0C;
          "terminal.ansi.bright_cyan" = hex base0C;
          "terminal.ansi.dim_cyan" = hex base0C;
          "terminal.ansi.white" = hex base05;
          "terminal.ansi.bright_white" = hex base07;
          "terminal.ansi.dim_white" = hex base04;
          "link_text.hover" = hex base0D;
          "version_control.added" = hex base0B;
          "version_control.modified" = hex base0A;
          "version_control.deleted" = hex base08;
          players = map player [ base0D base04 base09 base0E base0C base08 base0A base0B ];
          syntax = {
            attribute = syntax base0D;
            boolean = syntax base09;
            comment = syntax base03;
            "comment.doc" = syntax base04;
            constant = syntax base09;
            constructor = syntax base0D;
            embedded = syntax base0F;
            emphasis = syntax base0D;
            "emphasis.strong" = syntaxBold base0D;
            enum = syntax base0A;
            function = syntax base0D;
            "function.builtin" = syntax base0C;
            hint = syntax base0C;
            keyword = syntax base0E;
            label = syntax base0D;
            link_text = syntaxItalic base0C;
            link_uri = syntax base0E;
            namespace = syntax base0A;
            number = syntax base09;
            operator = syntax base0C;
            predictive = syntaxItalic base03;
            preproc = syntax base0F;
            primary = syntax base05;
            property = syntax base08;
            punctuation = syntax base05;
            "punctuation.bracket" = syntax base04;
            "punctuation.delimiter" = syntax base05;
            "punctuation.list_marker" = syntax base05;
            "punctuation.markup" = syntax base0D;
            "punctuation.special" = syntax base05;
            selector = syntax base0E;
            "selector.pseudo" = syntax base0D;
            string = syntax base0B;
            "string.escape" = syntax base0C;
            "string.regex" = syntax base0C;
            "string.special" = syntax base0E;
            "string.special.symbol" = syntax base0C;
            tag = syntax base08;
            "text.literal" = syntax base0D;
            title = syntaxBold base0D;
            type = syntax base0A;
            variable = syntax base05;
            "variable.special" = syntax base0D;
            variant = syntax base0A;
          };
        }
        // status "conflict" base0A
        // status "created" base0B
        // status "deleted" base08
        // status "error" base08
        // status "hint" base0C
        // status "info" base0D
        // status "modified" base0A
        // status "renamed" base0D
        // status "success" base0B
        // status "warning" base0A
        // mutedStatus "hidden" base03
        // mutedStatus "ignored" base03
        // mutedStatus "predictive" base03
        // mutedStatus "unreachable" base04;
    }];
  };
in
{
  options.modules.gui.zed-editor.enable = lib.mkEnableOption "Enable personal zed editor config";

  config = lib.mkIf config.modules.gui.zed-editor.enable {
    programs.zed-editor = {
      enable = true;
      themes.base16 = zedTheme;
      mutableUserKeymaps = false;
      userSettings = {
        theme = themeName;
        agent_servers = {
          "codex-nix" = {
            type = "custom";
            command = lib.getExe pkgs.codex-acp;
          };
        };
      };
      userKeymaps = [
        {
          context = "Editor && !menu";
          bindings = {
            "space space" = "file_finder::Toggle";
          };
        }
        {
          context = "Editor && vim_mode == insert && !menu";
          bindings = {
            "ctrl-space" = "editor::ShowCompletions";
          };
        }
        {
          context = "Editor && (vim_mode == helix_normal || vim_mode == helix_select) && !menu";
          bindings = {
            "'" = "vim::RepeatFind";
            "backspace" = "vim::HelixCollapseSelection";
            "ctrl-e" = "vim::LineDown";
            "ctrl-x" = "vim::HelixSelectLine";
            "ctrl-y" = "vim::LineUp";
            "," = [
              "action::Sequence"
              [
                "vim::HelixCollapseSelection"
                "vim::HelixKeepNewestSelection"
              ]
            ];
            "g j" = "vim::StartOfLine";
            "h" = [
              "vim::Up"
              {
                display_lines = true;
              }
            ];
            "j" = "vim::WrappingLeft";
            "k" = [
              "vim::Down"
              {
                display_lines = true;
              }
            ];
            "l" = "vim::WrappingRight";
            "n" = "vim::HelixSelectNext";
            "p" = "vim::HelixPaste";
            "shift-n" = "vim::HelixSelectPrevious";
            "shift-p" = [
              "vim::HelixPaste"
              {
                before = true;
              }
            ];
            "shift-r" = "editor::Paste";
            "shift-y" = "editor::Copy";
            "space c" = "editor::ToggleComments";
            "space f" = "editor::Format";
            "space n" = "workspace::NewSearch";
            "space p" = "vim::HelixPaste";
            "space q" = "pane::CloseActiveItem";
            "space shift-p" = [
              "vim::HelixPaste"
              {
                before = true;
              }
            ];
            "space shift-r" = "editor::Paste";
            "space t d" = "editor::GoToTypeDefinition";
            "space t i" = "editor::GoToImplementation";
            "space t r" = "editor::FindAllReferences";
            "space t t" = "editor::GoToDefinition";
            "space w" = "workspace::SaveWithoutFormat";
            "space x" = "pane::CloseActiveItem";
            "space y" = "editor::Copy";
            "y" = "editor::Copy";
            "z h" = "vim::ScrollUp";
            "z k" = "vim::ScrollDown";
            "shift-z h" = "vim::ScrollUp";
            "shift-z k" = "vim::ScrollDown";
            "ctrl-w ctrl-h" = "workspace::ActivatePaneUp";
            "ctrl-w ctrl-j" = "workspace::ActivatePaneLeft";
            "ctrl-w ctrl-k" = "workspace::ActivatePaneDown";
            "ctrl-w h" = "workspace::ActivatePaneUp";
            "ctrl-w j" = "workspace::ActivatePaneLeft";
            "ctrl-w k" = "workspace::ActivatePaneDown";
          };
        }
      ];
    };
  };
}
