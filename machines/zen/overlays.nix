{ nixpkgs-unstable }: [
  (
    final: prev: {
      blender = (
        nixpkgs-unstable.pkgs.blender.overrideAttrs (
          old: {
            version = "3.0-alpha";
            src = builtins.fetchGit {
              url = "https://git.blender.org/blender.git";
              ref = "master";
              rev = "8d8ce6443530ac3e39276c7b7219e2a8ca61040f";
              submodules = true;
            };
            buildInputs = old.buildInputs ++ [ nixpkgs-unstable.pkgs.zstd ];
          }
        )
      ).override { cudaSupport = true; cudatoolkit = nixpkgs-unstable.pkgs.cudatoolkit_11_4; };
    }
  )
]

