{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";
    nixpkgs-personal.url = "github:Philipp-M/nixpkgs/personal";
    rycee-nur-expressions = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager = {
      url = "github:Philipp-M/home-manager/personal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, rycee-nur-expressions, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgImport = pkgs: overlays:
        import pkgs {
          inherit system;
          overlays = [ inputs.neovim-nightly-overlay.overlay ] ++ overlays;
          config.allowUnfree = true;
        };
      nixpkgs-stable = pkgImport inputs.nixpkgs [ ];
      nixpkgs-unstable = pkgImport inputs.nixpkgs-unstable [ ];
      nixpkgs-personal = pkgImport inputs.nixpkgs-personal [ ];

      homeManagerModules = {
        create-directories = import ./home/create-directories.nix { };
        cli = import ./home/modules/cli { }; # enables all modules in the cli directory + small extra ones
        fish = import ./home/modules/cli/fish.nix { };
        git = import ./home/modules/cli/git.nix { };
        neovim = import ./home/modules/cli/neovim { inherit nixpkgs-unstable nixpkgs-personal; };
        ssh = import ./home/modules/cli/ssh.nix { };
        starship = import ./home/modules/cli/starship.nix { };
        tmux = import ./home/modules/cli/tmux.nix { };
        gui = import ./home/modules/gui { }; # enables all modules in the gui directory + small extra ones
        firefox = import ./home/modules/gui/firefox.nix { };
        alacritty = import ./home/modules/gui/alacritty { };
        autorandr = import ./home/modules/gui/autorandr.nix { };
        desktop-environment = import ./home/modules/gui/desktop-environment { };
        mpv = import ./home/modules/gui/mpv { };
        theme = import ./home/modules/theme.nix { inherit rycee-nur-expressions; };
        mpd = import ./home/modules/mpd.nix { inherit nixpkgs-unstable; };
      };

      mkHost = { path, overlays ? [ ] }: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = pkgImport inputs.nixpkgs overlays;
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
            home-manager.users.philm = {
              imports = builtins.attrValues homeManagerModules;
              programs.home-manager.enable = true;
              modules.cli.enable = true;
              modules.gui.enable = true;
            };
          }
          path
        ];
        specialArgs = { inherit inputs nixpkgs-unstable; };
      };
    in
    {
      devShell."${system}" =
        import ./shell.nix { pkgs = nixpkgs-stable; inherit inputs; };

      inherit homeManagerModules;
      nixosConfigurations = {
        zen = mkHost {
          path = ./machines/zen;
          overlays = [ ] ++
            (import ./machines/zen/overlays.nix { inherit nixpkgs-unstable; }) ++
            (import ./secrets/nix-expressions/zen-overlays.nix { inherit nixpkgs-unstable; });
        };
        shadow = mkHost { path = ./machines/shadow; };
        office = mkHost { path = ./machines/office; };
      };
    };
}
