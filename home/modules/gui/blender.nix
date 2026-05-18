# blender-photogrammetry.nix
{ pkgs }:

let
  lib = pkgs.lib;

  laspy = ps: ps.laspy.overridePythonAttrs (old: {
    dependencies = builtins.filter (dep: (lib.getName dep) != "laszip-python") old.dependencies;
    pythonImportsCheck = builtins.filter (name: name != "laszip") old.pythonImportsCheck;
  });

  pyntcloud = ps: ps.buildPythonPackage rec {
    pname = "pyntcloud";
    version = "0.3.1";

    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-YotFln4cl6lH3wY3JnGXprOKNssEFz+YN/BbwxgDSLg=";
    };

    build-system = [ ps.setuptools ];

    dependencies = with ps; [
      numpy
      scipy
      pandas
      (laspy ps)
      lazrs
    ];

    pythonImportsCheck = [ "pyntcloud" ];

    # Upstream is old; keep this off unless you want to patch the test suite.
    doCheck = false;
  };

  photogrammetryImporter = pkgs.fetchFromGitHub {
    owner = "SBCV";
    repo = "Blender-Addon-Photogrammetry-Importer";

    # Pick a tag matching your Blender version.
    # Current release shown upstream: v2026.02.16 for Blender 5.x.
    rev = "v2026.02.16";

    hash = "sha256-CTtqtvDgnajACSTochLc/50DEWqsm8yxevZOl+sbtck=";
  };

  blenderWithDeps = pkgs.blender.withPackages (ps: [
    ps.setuptools
    ps.pillow
    (laspy ps)
    ps.lazrs
    (pyntcloud ps)
  ]);

in
blenderWithDeps.overrideAttrs (old: {
  pname = "blender-photogrammetry";

  installPhase = old.installPhase + ''
    addon_dir="$out/share/blender/${lib.versions.majorMinor pkgs.blender.version}/scripts/addons"
    chmod -R u+w "$out/share/blender"
    mkdir -p "$addon_dir"

    ln -s \
      ${photogrammetryImporter}/photogrammetry_importer \
      "$addon_dir/photogrammetry_importer"
  '';
})
