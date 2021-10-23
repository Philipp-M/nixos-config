{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-personal.url = "github:Philipp-M/nixpkgs/personal";
    rycee-nur-expressions = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    home-manager = {
      url = "github:Philipp-M/home-manager/personal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, rycee-nur-expressions, ... }:
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
      mkHost = path: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = nixpkgs-stable;
        modules = [
          inputs.home-manager.nixosModules.home-manager
          ./machines/zen/default.nix
        ];
        specialArgs = { inherit inputs nixpkgs-unstable nixpkgs-personal rycee-nur-expressions; };
      };
    in
    {
      nixosConfigurations = {
        zen = mkHost ./machines/zen;
        shadow = mkHost ./machines/shadow;
        office = mkHost ./machines/office;
      };
    };
}
