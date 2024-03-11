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
      default = config.lib.theme.base16.fromYamlFile (builtins.toFile "tomorrow-night.yaml" ''
        scheme: "Tomorrow Night"
        author: "Chris Kempson (http://chriskempson.com)"
        base00: "1d1f21"
        base01: "282a2e"
        base02: "373b41"
        base03: "969896"
        base04: "b4b7b4"
        base05: "c5c8c6"
        base06: "e0e0e0"
        base07: "ffffff"
        base08: "cc6666"
        base09: "de935f"
        base0A: "f0c674"
        base0B: "b5bd68"
        base0C: "8abeb7"
        base0D: "81a2be"
        base0E: "b294bb"
        base0F: "a3685a"
      '');
    };
    extraParams = mkOption {
      type = types.attrsOf types.string;
      default = rec {
        fontname = "Iosevka Kitty";
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
    fonts.fontconfig.enable = true;
    home.packages = lib.mkIf (config.theme.extraParams.fontname == "Iosevka Kitty") [
      (pkgs.iosevka.override { privateBuildPlan = { family = "Iosevka Kitty"; exportGlyphNames = true; }; set = "kitty"; })
    ];
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
