{ pkgs, lib, config, nixpkgs-unstable, nixpkgs-personal, ... }: {
  # TODO automate module import
  imports = [
    (import ./modules/cli/ssh.nix { })
    (import ./modules/cli/git.nix { })
    (import ./modules/cli/starship.nix { })
    (import ./modules/cli/fish.nix { })
    (import ./modules/cli/tmux.nix { })
    (import ./modules/cli/neovim { inherit nixpkgs-unstable nixpkgs-personal; })
    (import ./modules/cli { })
    (import ./theme.nix)
    (import ./create-directories.nix)
    (import ./x.nix)
  ];

  programs.home-manager.enable = true;
  modules.cli.enable = true;
}
