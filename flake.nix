{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/master";
    nixpkgs-personal.url = "github:Philipp-M/nixpkgs/personal";
    musnix = {
      url = "github:musnix/musnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

  outputs = inputs@{ self, rycee-nur-expressions, home-manager, agenix, ... }:
    let
      system = "x86_64-linux";
      pkgImport = pkgs:
        import pkgs {
          inherit system;
          overlays = [ inputs.neovim-nightly-overlay.overlay ];
          config.allowUnfree = true;
        };
      nixpkgs-stable = pkgImport inputs.nixpkgs;
      nixpkgs-unstable = pkgImport inputs.nixpkgs-unstable;
      nixpkgs-personal = pkgImport inputs.nixpkgs-personal;

      homeManagerModules = {
        create-directories = import ./home/modules/create-directories.nix { };
        cli = import ./home/modules/cli { }; # enables all modules in the cli directory + small extra ones
        fish = import ./home/modules/cli/fish.nix { };
        git = import ./home/modules/cli/git.nix { };
        neovim = import ./home/modules/cli/neovim { inherit nixpkgs-unstable nixpkgs-personal; };
        helix = import ./home/modules/cli/helix.nix { inherit nixpkgs-unstable nixpkgs-personal; };
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

      mkHost = { path, extraConfig ? { } }: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          inputs.musnix.nixosModule
          {
            nix.registry.nixpkgs.flake = inputs.nixpkgs;
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
            home-manager.users.philm = {
              imports = builtins.attrValues homeManagerModules;
              programs.home-manager.enable = true;
              modules.cli.enable = true;
              modules.gui.enable = true;
              modules.create-directories.enable = true;
            };
          }
          extraConfig
          path
        ];
        specialArgs = { inherit inputs nixpkgs-unstable; };
      };
    in
    {
      devShell."${system}" =
        import ./shell.nix { pkgs = nixpkgs-stable; agenix = inputs.agenix.defaultPackage.x86_64-linux; };

      inherit homeManagerModules;
      nixosConfigurations = {
        zen = mkHost { path = ./machines/zen; };
        shadow = mkHost { path = ./machines/shadow; };
        office = mkHost { path = ./machines/office; extraConfig = agenix.nixosModules.age; };
      };
    };
}
