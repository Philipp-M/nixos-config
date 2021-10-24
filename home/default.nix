{ pkgs, lib, config, nixpkgs-unstable, nixpkgs-personal, rycee-nur-expressions, ... }: {
  # TODO automate module import
  imports = [
    (import ./create-directories.nix)
    (import ./modules/cli { })
    (import ./modules/cli/fish.nix { })
    (import ./modules/cli/git.nix { })
    (import ./modules/cli/neovim { inherit nixpkgs-unstable nixpkgs-personal; })
    (import ./modules/cli/ssh.nix { })
    (import ./modules/cli/starship.nix { })
    (import ./modules/cli/tmux.nix { })
    (import ./modules/gui { })
    (import ./modules/gui/alacritty { })
    (import ./modules/gui/autorandr.nix { })
    (import ./modules/gui/desktop-environment { })
    (import ./modules/gui/firefox.nix { })
    (import ./modules/gui/mpv { })
    (import ./modules/theme.nix { inherit rycee-nur-expressions; })
  ];

  programs.home-manager.enable = true;
  modules.cli.enable = true;
  modules.gui.enable = true;
}
