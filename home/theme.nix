{ pkgs, lib, config, ... }: {
  imports = let
    nurNoPkgs = import (builtins.fetchGit {
      url = "https://github.com/nix-community/NUR/";
      ref = "master";
      rev = "a7878103fd7f758e22d1deae4746fd001d3848cc";
    }) { };
  in [
    nurNoPkgs.repos.rycee.hmModules.theme-base16
    {
      options.theme.extraParams = with lib;
        mkOption {
          type = types.attrsOf types.string;
          default = { };
        };
      config.lib.theme.template = { name, src }:
        with lib;
        pkgs.runCommandLocal name { } ''
          sed '${
            concatStrings ((mapAttrsToList (n: v:
              "s/\\(#\\?\\){{${n}\\(\\:\\?-hex\\)\\?}}/\\1${v.hex.rgb}/;")
              config.theme.base16.colors)
              ++ (mapAttrsToList (n: v: "s/{{${n}}}/${v}/;")
                config.theme.extraParams))
          }' ${src} > $out
        '';
    }
  ];

  theme = {
    base16 = config.lib.theme.base16.fromYamlFile (builtins.fetchurl
      "https://raw.githubusercontent.com/chriskempson/base16-tomorrow-scheme/master/tomorrow-night.yaml");
    extraParams = {
      fontname = "Iosevka";
      xftfontextra = ":style=Regular";
      fontsize = "16";
      xcursorSize = "32";
      dpi = "100";
      alpha = "0.85"; # background alpha for applications that support it
    };
  };
}
