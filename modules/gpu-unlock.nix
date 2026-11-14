{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.nvidia.gpuUnlock;
  kernel = config.boot.kernelPackages.kernel;
  version = "1.0.0-unstable-2026-10-24";
  nv = "610.43.03";
  src = pkgs.fetchFromGitHub {
    owner = "Zagitta";
    repo = "gpu-unlock";
    rev = "af28cbbfd3d922a659227ecfb7369adfd924cf03";
    hash = "sha256-6FaDuPojB707ds7gkQY/g/+m4Tnz1xHZ95UjNfFxBJc=";
  };
  githubPrPatch = rev: sha256: pkgs.fetchurl {
    url = "https://github.com/Zagitta/gpu-unlock/commit/${rev}.patch";
    inherit sha256;
  };
  nvidiaSource = pkgs.fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-${nv}.tar.xz";
    sha256 = "7e118923c7a23edc36114d63273a46e3e04e9af98695a42203e7ac2dfe9fc1dc";
  };
  nvidiaUtils = pkgs.fetchurl {
    url = "https://archive.cachyos.org/archive/cachyos-v3/nvidia-utils-${nv}-1-x86_64_v3.pkg.tar.zst";
    sha256 = "e17e7c92eeffa178b0fe1f40eb17a47095f8fc3ce4a77bf115cf5bd5a4df86e9";
  };
  meta = {
    homepage = "https://github.com/Zagitta/gpu-unlock";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
  firmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "gpu-unlock-firmware";
    inherit version src;
    nativeBuildInputs = [ pkgs.python3 pkgs.zstd ];
    dontConfigure = true;
    buildPhase = ''
      mkdir nvidia-source
      tar -xf ${nvidiaSource} --strip-components=1 -C nvidia-source
      python3 firmware/generate_v67.py ${nvidiaUtils} assets
      python3 firmware/extract_boot_assets.py nvidia-source assets
    '';
    installPhase = ''
      install -Dm644 assets/*.bin -t "$out/lib/firmware/gpu-unlock/${nv}"
      install -Dm644 assets/NVIDIA-LICENSE firmware/NOTICE.md licenses/GPL-2.0.txt \
        -t "$out/share/licenses/gpu-unlock-firmware"
    '';
    meta = meta // {
      license = [ lib.licenses.gpl2Only lib.licenses.unfreeRedistributableFirmware ];
    };
  };
  gpuUnlock = kernel.stdenv.mkDerivation {
    pname = "gpu-unlock";
    inherit version src meta;
    patches = [
      # https://github.com/Zagitta/gpu-unlock/pull/35 — validate and align firmware DMA.
      (githubPrPatch "fb457b1f266414d23c68c8ca8aef35bed57325d4" "e290fd59090435b29d88f9d654cd71216bd09c8e5ed203c9166179484bba9a46")
      # https://github.com/Zagitta/gpu-unlock/pull/70 — await firmware before reading layout.
      (githubPrPatch "524822309479f5fe760fc3ab675c5c15ae4163bd" "186f4efd1e0bddf18864769a0281734d7b133db8a393d782217f9f8bd6395e19")
      # https://github.com/Zagitta/gpu-unlock/pull/72 — retry transient register-read errors.
      (githubPrPatch "1cb357f62336adb0537ebcc933ec89c3fe636baf" "0cb39c4373f496e6faad3c75689591c2d8d59f5c93669c7719979df137001fcf")
    ];
    nativeBuildInputs = kernel.moduleBuildDependencies ++ [ pkgs.python3 ];
    hardeningDisable = [ "pic" "format" ];
    dontConfigure = true;
    enableParallelBuilding = true;
    makeFlags = config.boot.kernelPackages.kernelModuleMakeFlags ++ [
      "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];
    buildPhase = ''
      make -C kernel/gpu_unlock -j$NIX_BUILD_CORES ''${makeFlags[@]}
    '';
    doCheck = true;
    checkPhase = "make test ASSETS=${firmware}/lib/firmware/gpu-unlock/${nv}";
    installPhase = ''
      install -Dm644 kernel/gpu_unlock/gpu_unlock.ko \
        -t "$out/lib/modules/${kernel.modDirVersion}/extra"
      install -Dm644 licenses/GPL-2.0.txt -t "$out/share/licenses/gpu-unlock"
    '';
  };
in
{
  options.hardware.nvidia.gpuUnlock = {
    enable = lib.mkEnableOption "the Ampere tensor throughput unlock";
    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "all" ];
      description = "PCI addresses to unlock, or [ \"all\" ] for every supported GPU.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.boot.initrd.systemd.enable;
      message = "hardware.nvidia.gpuUnlock requires a systemd initrd.";
    }];
    hardware.firmware = [ firmware ];
    boot.extraModulePackages = [ gpuUnlock ];
    boot.kernelParams = [
      "gpu_unlock.targets=${lib.concatStringsSep "," cfg.targets}"
      "gpu_unlock.resume=0"
    ];
    boot.initrd.availableKernelModules = [ "gpu_unlock" ];
    # Finish before either modules-load or udev can bind NVIDIA.
    boot.initrd.systemd.services.gpu-unlock = {
      description = "Unlock Ampere tensor throughput";
      wantedBy = [ "sysinit.target" ];
      before = [
        "systemd-modules-load.service"
        "systemd-udevd.service"
        "systemd-udev-trigger.service"
        "sysinit.target"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/bin/modprobe gpu_unlock";
      };
    };
  };
}
