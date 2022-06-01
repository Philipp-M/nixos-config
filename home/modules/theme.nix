{ rycee-nur-expressions, ... }:
{ pkgs, lib, config, ... }:
let inherit (lib) concatStrings mapAttrsToList mkOption types; in
{
  imports = [
    (import "${rycee-nur-expressions}/hm-modules/theme-base16" { inherit pkgs lib config; })
  ];

  options.theme = {
    base16-theme = mkOption {
      type = types.attrs;
      default = config.lib.theme.base16.fromYamlFile (
        builtins.fetchurl {
          url = "https://raw.githubusercontent.com/chriskempson/base16-tomorrow-scheme/master/tomorrow-night.yaml";
          sha256 = "sha256:0mc699fps18lk9dl154vpcdh0in62215yfq9n4mwg4213j06488z";
        }
      );
    };
    extraParams = mkOption {
      type = types.attrsOf types.string;
      default = rec {
        fontname = "Iosevka";
        xftfontextra = ":style=Regular";
        fontsize = "16";
        xcursorSize = "32";
        dpi = "100";
        alpha = "0.85"; # background alpha for applications that support it
        alpha-hex = builtins.readFile (pkgs.runCommandLocal "alpha-hex" { } "echo 'obase=16;scale=0;${alpha}*255/1' | ${pkgs.bc}/bin/bc | tr -d '\n' > $out");
      };
    };
  };
  config = {
    lib.theme.compileTemplate = { name, src }:
      pkgs.runCommandLocal name { } ''
        sed '${
          concatStrings ((mapAttrsToList (n: v:
            "s/\\(#\\?\\){{${n}\\(\\:\\?-hex\\)\\?}}/\\1${v.hex.rgb}/;")
            config.theme.base16.colors)
            ++ (mapAttrsToList (n: v: "s/{{${n}}}/${v}/;")
              config.theme.extraParams))
        }' ${src} > $out
      '';
    theme.base16 = config.theme.base16-theme;
  };
}
