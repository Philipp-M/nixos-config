{
  inputs = {
    nixpkgs.url = "github:Philipp-M/nixpkgs/personal-staging";
    # nixpkgs.url = "git+file:///home/philm/dev/personal/nix/nixpkgs";
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
    nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
    deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-compat.follows = "flake-compat"; };
    devenv = { url = "github:cachix/devenv/latest"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-compat.follows = "flake-compat"; };
    impermanence.url = "github:nix-community/impermanence";
    helix = { url = "github:Philipp-M/helix/personal-staging"; inputs = { nixpkgs.follows = "nixpkgs"; rust-overlay.follows = "rust-overlay"; }; };
    nix-snapd = { url = "github:nix-community/nix-snapd"; inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs"; }; };
    rust-overlay = { url = "github:oxalica/rust-overlay"; inputs.nixpkgs.follows = "nixpkgs"; };
    nil = { url = "github:oxalica/nil"; inputs = { nixpkgs.follows = "nixpkgs"; }; };
    musnix = { url = "github:musnix/musnix"; inputs.nixpkgs.follows = "nixpkgs"; };
    agenix = { url = "github:ryantm/agenix"; inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; }; };
    rycee-nur-expressions = { url = "gitlab:rycee/nur-expressions"; flake = false; };
    rycee-firefox-addons = { url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons"; inputs.nixpkgs.follows = "nixpkgs"; };
    comma = { url = "github:nix-community/comma"; inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; }; };
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    # home-manager = { url = "git+file:///home/philm/dev/personal/desktop-environment/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    # kanata = { url = "github:jtroo/kanata"; flake = false; };
    # eww = { url = "github:Philipp-M/eww/fix-nix-flake"; inputs = { nixpkgs.follows = "nixpkgs"; rust-overlay.follows = "rust-overlay"; flake-compat.follows = "flake-compat"; }; };
    # eww = { url = "git+file:///home/philm/dev/personal/rust/eww"; inputs = { nixpkgs.follows = "nixpkgs"; rust-overlay.follows = "rust-overlay"; flake-compat.follows = "flake-compat"; }; };
    ewmh-status-listener = { url = "github:Philipp-M/ewmh-status-listener"; inputs = { nixpkgs.follows = "nixpkgs"; rust-overlay.follows = "rust-overlay"; }; };
    chatgpt-tui = { url = "github:Philipp-M/chatgpt-tui"; inputs = { nixpkgs.follows = "nixpkgs"; rust-overlay.follows = "rust-overlay"; }; };
    mpv-ai-upscale = { url = "github:Alexkral/AviSynthAiUpscale"; flake = false; };
    mpv-default-shader-pack = { url = "github:iwalton3/default-shader-pack"; flake = false; };
    fzf-fish = { url = "github:PatrickF1/fzf.fish"; flake = false; };
    # pipewire = { url = "gitlab:pipewire/pipewire?tag=1.0.0&host=gitlab.freedesktop.org"; flake = false; };
  };

  outputs = inputs:
    let
      system = "x86_64-linux";
      mkHost = { path, extraConfig ? { } }: inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ extraConfig path ];
        specialArgs = { inherit inputs; };
      };
      importHomeModule = path: import path inputs;
    in
    {
      devShell."${system}" = with inputs.nixpkgs.legacyPackages.${system};
        let nixBin = writeShellScriptBin "nix" "${nixVersions.stable}/bin/nix --option experimental-features 'nix-command flakes' \"$@\""; in
        mkShell {
          buildInputs = [
            f2fs-tools
            gptfdisk
            git
            nix-zsh-completions
            git-crypt
            inputs.agenix.packages.${system}.default
            inputs.deploy-rs.packages."${system}".default
            nixos-install-tools
            nixBin
            (nixos { nix.package = nixVersions.stable; }).nixos-rebuild
          ];
          shellHook = "export FLAKE=\"$(pwd)\"";
        };

      nixosConfigurations = {
        zen = mkHost { path = ./machines/zen; };
        aura = mkHost { path = ./machines/aura; };
        shadow = mkHost { path = ./machines/shadow; };
        office = mkHost { path = ./machines/office; };
      };

      homeManagerModules = {
        create-directories = importHomeModule ./home/modules/create-directories.nix;
        cli = importHomeModule ./home/modules/cli; # enables all modules in the cli directory + small extra ones
        fish = importHomeModule ./home/modules/cli/fish.nix;
        git = importHomeModule ./home/modules/cli/git.nix;
        neovim = importHomeModule ./home/modules/cli/neovim;
        helix = importHomeModule ./home/modules/cli/helix.nix;
        ssh = importHomeModule ./home/modules/cli/ssh.nix;
        starship = importHomeModule ./home/modules/cli/starship.nix;
        tmux = importHomeModule ./home/modules/cli/tmux.nix;
        gui = importHomeModule ./home/modules/gui; # enables all modules in the gui directory + small extra ones
        firefox = importHomeModule ./home/modules/gui/firefox.nix;
        alacritty = importHomeModule ./home/modules/gui/alacritty;
        kitty = importHomeModule ./home/modules/gui/kitty.nix;
        autorandr = importHomeModule ./home/modules/gui/autorandr.nix;
        desktop-environment = importHomeModule ./home/modules/gui/desktop-environment; # pretty much everything that is necessary to run xmonad and hyprland as "desktop-environment"
        mpv = importHomeModule ./home/modules/gui/mpv;
        theme = importHomeModule ./home/modules/theme.nix;
        mpd = importHomeModule ./home/modules/mpd.nix;
      };
    };
}
