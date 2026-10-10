{
  allowBroken = true;
  allowUnfree = true;
  cudaSupport = true;
  cudnnSupport = true;
  cudaForwardCompat = false;
  # Target our GTX 1080 Ti and RTX 3090 only when the toolkit supports them.
  # Override each versioned set so aliases follow nixpkgs' future defaults.
  packageOverrides = pkgs:
    let
      desiredCapabilities = [ "6.1" "8.6" ];
      cudaPackageNames = builtins.filter
        (name: builtins.match "cudaPackages_[0-9]+_[0-9]+" name != null)
        (builtins.attrNames pkgs);
      withCapabilities = cuda: requestedCapabilities:
        let
          capabilities = pkgs.lib.intersectLists
            cuda.backendStdenv.supportedCudaCapabilities
            requestedCapabilities;
        in
        cuda.override {
          config = pkgs.config // {
            # An empty list would restore nixpkgs' broad default targets.
            cudaCapabilities =
              if capabilities != [ ] then capabilities
              else throw "CUDA ${cuda.cudaMajorMinorVersion} supports none of the requested GPU targets";
          };
        };
      cudnnCuda = withCapabilities pkgs.cudaPackages [ "8.6" ];
    in
    builtins.listToAttrs (map
      (name: {
        inherit name;
        value = withCapabilities pkgs.${name} desiredCapabilities;
      })
      cudaPackageNames) // {
      # Modern cuDNN no longer supports Pascal. Keep consumers' CUDA
      # dependencies consistent and target only the RTX 3090.
      onnxruntime = pkgs.onnxruntime.override {
        cudaPackages = cudnnCuda;
      };
      dlib = pkgs.dlib.override { cudaPackages = cudnnCuda; };
      pythonPackagesExtensions = pkgs.pythonPackagesExtensions ++ [
        (_: prev: {
          torch = prev.torch.override { cudaPackages = cudnnCuda; };
        })
      ];
    };
  permittedInsecurePackages = [ "libdwarf-20181024" "qtwebkit-5.212.0-alpha4" "electron-24.8.6" "dotnet-sdk-6.0.428" "dotnet-runtime-6.0.36" "freeimage-3.18.0-unstable-2024-04-18" ];
}
