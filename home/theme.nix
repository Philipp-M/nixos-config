{ pkgs, lib, config, ... }: {
  imports = [
    (import "${
        (builtins.fetchGit {
          url = "https://github.com/atpotts/base16-nix/";
          ref = "master";
          rev = "4f192afaa0852fefb4ce3bde87392a0b28d6ddc8";
        })
      }/base16.nix")
  ];

  themes.base16 = {
    enable = true;
    scheme = "tomorrow";
    variant = "tomorrow-night";
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
