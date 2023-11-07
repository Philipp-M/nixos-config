{
  allowUnfree = true;
  cudaSupport = true;
  cudnnSupport = true;
  # cudaCapabilities = [ "8.6" ]; # TODO put this into separate machines...
  permittedInsecurePackages = [ "libdwarf-20181024" "qtwebkit-5.212.0-alpha4" "electron-24.8.6" ];
}
