{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";
    impermanence.url = "github:nix-community/impermanence";
    helix = { url = "github:Philipp-M/helix/personal"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };
    rust-overlay = { url = "github:oxalica/rust-overlay"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };
    nil = { url = "github:oxalica/nil"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };
    musnix = { url = "github:Philipp-M/musnix/fix-zfs-gpl-issue"; inputs.nixpkgs.follows = "nixpkgs-unstable"; };
    agenix = { url = "github:ryantm/agenix"; inputs.nixpkgs.follows = "nixpkgs"; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    rycee-nur-expressions = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    neovim-nightly-overlay = { url = "github:nix-community/neovim-nightly-overlay"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; flake-compat.follows = "flake-compat"; }; };
    comma = { url = "github:nix-community/comma"; inputs = { nixpkgs.follows = "nixpkgs-unstable"; flake-compat.follows = "flake-compat"; }; };
    home-manager = { url = "github:Philipp-M/home-manager/personal-unstable"; inputs.nixpkgs.follows = "nixpkgs"; };

    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    kanata = { url = "github:jtroo/kanata"; flake = false; };
  };

  outputs = inputs@{ rust-overlay, rycee-nur-expressions, home-manager, agenix, helix, nil, ... }:
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

      homeManagerModules = {
        create-directories = import ./home/modules/create-directories.nix { };
        cli = import ./home/modules/cli { }; # enables all modules in the cli directory + small extra ones
        fish = import ./home/modules/cli/fish.nix { };
        git = import ./home/modules/cli/git.nix { };
        neovim = import ./home/modules/cli/neovim { inherit nixpkgs-unstable; };
        helix = import ./home/modules/cli/helix.nix { inherit nixpkgs-unstable helix nil; };
        ssh = import ./home/modules/cli/ssh.nix { };
        starship = import ./home/modules/cli/starship.nix { };
        tmux = import ./home/modules/cli/tmux.nix { };
        gui = import ./home/modules/gui { }; # enables all modules in the gui directory + small extra ones
        firefox = import ./home/modules/gui/firefox.nix { };
        alacritty = import ./home/modules/gui/alacritty { };
        kitty = import ./home/modules/gui/kitty.nix { };
        autorandr = import ./home/modules/gui/autorandr.nix { };
        desktop-environment = import ./home/modules/gui/desktop-environment { inherit nixpkgs-unstable; };
        mpv = import ./home/modules/gui/mpv { };
        theme = import ./home/modules/theme.nix { inherit rycee-nur-expressions; };
        mpd = import ./home/modules/mpd.nix { inherit nixpkgs-unstable; };
      };

      mkHost = { path, extraConfig ? { } }: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          inputs.musnix.nixosModules.default
          inputs.impermanence.nixosModules.impermanence
          ({ pkgs, ... }: {
            nixpkgs.overlays = [ rust-overlay.overlays.default ];
            home-manager.useUserPackages = true;
            home-manager.useGlobalPkgs = true;
            home-manager.users.philm = {
              imports = builtins.attrValues homeManagerModules ++ [ inputs.nix-index-database.hmModules.nix-index ];
              programs.home-manager.enable = true;
              home.stateVersion = "22.05";
              modules.cli.enable = true;
              modules.gui.enable = true;
              modules.create-directories.enable = true;
            };
          })
          extraConfig
          path
        ];
        specialArgs = { inherit inputs nixpkgs-unstable; };
      };
    in
    {
      devShell."${system}" = with nixpkgs-stable;
        let nixBin = writeShellScriptBin "nix" "${nixFlakes}/bin/nix --option experimental-features 'nix-command flakes' \"$@\""; in
        mkShell {
          buildInputs = [
            f2fs-tools
            gptfdisk
            git
            nix-zsh-completions
            git-crypt
            agenix.defaultPackage."${system}"
            nixBin
            (nixos { nix.package = nixFlakes; }).nixos-rebuild
          ];
          shellHook = "export FLAKE=\"$(pwd)\"";
        };

      inherit homeManagerModules;

      nixosConfigurations = {
        zen = mkHost { path = ./machines/zen; };
        shadow = mkHost { path = ./machines/shadow; };
        office = mkHost { path = ./machines/office; extraConfig = agenix.nixosModules.age; };
      };
    };
}
