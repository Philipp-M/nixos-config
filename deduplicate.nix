# some slop to deduplicate dependencies often used between different packages
# Keep CUDA applications shared, and other applications on stock non-CUDA packages.
# Uses the same nixpkgs pin for both scopes; no separate version pin or downgrade.
final: prev:
let
  # Keep desktop/Vulkan applications and their entire dependency graphs on stock
  # nixpkgs defaults. Inheriting config/packageOverrides or system overlays
  # here would reintroduce CUDA and change otherwise cacheable derivations.
  desktopPkgs = import prev.path {
    system = prev.stdenv.hostPlatform.system;
    config = {
      inherit (prev.config) allowUnfree allowBroken permittedInsecurePackages;
      cudaSupport = false;
    };
    overlays = [ ];
  };
  # Keep cuDNN clients on the RTX 3090, but reuse the common NCCL/GDRCopy
  # binaries containing both sm_61 and sm_86. Override the scope so nested
  # consumers also see these shared dependencies.
  cudnnCuda = (final.cudaPackages.override {
    config = final.config // { cudaCapabilities = [ "8.6" ]; };
  }).overrideScope (_: _: {
    inherit (final.cudaPackages) nccl gdrcopy;
  });
in
{
  inherit (desktopPkgs)
    firefox firefox-unwrapped
    thunderbird thunderbird-unwrapped
    freecad calibre;

  # This application uses Vulkan. Its ncnn dependency still lists OpenCV,
  # so use the complete stock scope to avoid the global CUDA OpenCV override
  # while preserving ncnn's Vulkan acceleration and official cache identities.
  realesrgan-ncnn-vulkan = desktopPkgs.realesrgan-ncnn-vulkan;

  # PCL's CUDA modules do not require CUDA-enabled VTK dependencies. Reuse
  # FreeCAD's cached, Python-enabled VTK for C++ and Python consumers instead
  # of rebuilding VTK against the global CUDA scientific-library stack.
  vtk = desktopPkgs.python3Packages.vtk;

  # MLT explicitly overrides OpenCV to use ffmpeg_8. Making that the common
  # default, with Python bindings enabled, unifies all three observed builds.
  opencv4 = prev.opencv4.override {
    enablePython = true;
    pythonPackages = final.python3Packages;
    ffmpeg_8-headless = final.ffmpeg_8;
  };

  onnxruntime = prev.onnxruntime.override { cudaPackages = cudnnCuda; };
  dlib = prev.dlib.override { cudaPackages = cudnnCuda; };
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pythonPrev: {
      torch = pythonPrev.torch.override {
        cudaPackages = cudnnCuda;
        # rembg reaches Torch through Gradio's check inputs. Keep CUDA/NCCL,
        # but omit the specialized distributed symmetric-memory backend and
        # its source-built NVSHMEM dependency.
        withNvshmem = false;
      };
    })
  ];
}

