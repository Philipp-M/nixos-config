{ pkgs, lib, config, ... }: {
  imports = [
    (import ./theme.nix)
    (import ./directories-links.nix)
    (import ./cli.nix)
    (import ./x.nix)
  ];

  programs.home-manager.enable = true;
}
