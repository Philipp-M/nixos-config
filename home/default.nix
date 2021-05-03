{ pkgs, lib, config, ... }: {
  imports = [
    (import ./theme.nix)
    (import ./create-directories.nix)
    (import ./cli.nix)
    (import ./x.nix)
  ];

  programs.home-manager.enable = true;
}
