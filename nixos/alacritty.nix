{ stdenv
, lib
, fetchFromGitHub
, rustPlatform

, cmake
, gzip
, installShellFiles
, makeWrapper
, ncurses
, pkgconfig
, python3

, expat
, fontconfig
, freetype
, libGL
, libX11
, libXcursor
, libXi
, libXrandr
, libXxf86vm
, libxcb
, libxkbcommon
, wayland
, xdg_utils

  # Darwin Frameworks
, AppKit ? null
, CoreGraphics ? null
, CoreServices ? null
, CoreText ? null
, Foundation ? null
, OpenGL ? null
}:
let
  rpathLibs = [
    stdenv.cc.cc
    expat
    fontconfig
    freetype
    libGL
    libX11
    libXcursor
    libXi
    libXrandr
    libXxf86vm
    libxcb
  ] ++ lib.optionals stdenv.isLinux [
    libxkbcommon
    wayland
  ];
in
rustPlatform.buildRustPackage rec {
  pname = "alacritty";
  version = "0.7.0-dev-ligatures-mod-fix";


  src = fetchFromGitHub {
    owner = "Philipp-M";
    repo = pname;
    rev = "494d3d2f8dc10019f8f4f9086ac297d86fb7158f";
    sha256 = "0h1689y3n3f3jkyknw740kk2n7jl63qq4ksk4hc88v1zsf76h54v";
  };

  cargoSha256 = "0zag84p0ihv1b1macg64hsyip3mv6p7mnrznf0n8qqf720880ri1";

  nativeBuildInputs = [
    cmake
    gzip
    installShellFiles
    makeWrapper
    ncurses
    pkgconfig
    python3
  ];

  buildInputs = rpathLibs
  ++ lib.optionals stdenv.isDarwin [
    AppKit
    CoreGraphics
    CoreServices
    CoreText
    Foundation
    OpenGL
  ];

  outputs = [ "out" "terminfo" ];

  postPatch = ''
    substituteInPlace alacritty/src/config/mouse.rs \
      --replace xdg-open ${xdg_utils}/bin/xdg-open
  '';

  installPhase = ''
    runHook preInstall

    install -D $releaseDir/alacritty $out/bin/alacritty

  '' + (
    if stdenv.isDarwin then ''
      mkdir $out/Applications
      cp -r extra/osx/Alacritty.app $out/Applications
      ln -s $out/bin $out/Applications/Alacritty.app/Contents/MacOS
    '' else ''
      install -D extra/linux/Alacritty.desktop -t $out/share/applications/
      install -D extra/logo/compat/alacritty-term.svg $out/share/icons/hicolor/scalable/apps/Alacritty.svg

      # patchelf generates an ELF that binutils' "strip" doesn't like:
      #    strip: not enough room for program headers, try linking with -N
      # As a workaround, strip manually before running patchelf.
      strip -S $out/bin/alacritty

      patchelf --set-rpath "${lib.makeLibraryPath rpathLibs}" $out/bin/alacritty
    ''
  ) + ''

    installShellCompletion --zsh extra/completions/_alacritty
    installShellCompletion --bash extra/completions/alacritty.bash
    installShellCompletion --fish extra/completions/alacritty.fish

    install -dm 755 "$out/share/man/man1"
    gzip -c extra/alacritty.man > "$out/share/man/man1/alacritty.1.gz"

    install -Dm 644 alacritty.yml $out/share/doc/alacritty.yml

    install -dm 755 "$terminfo/share/terminfo/a/"
    tic -xe alacritty,alacritty-direct -o "$terminfo/share/terminfo" extra/alacritty.info
    mkdir -p $out/nix-support
    echo "$terminfo" >> $out/nix-support/propagated-user-env-packages

    runHook postInstall
  '';

  dontPatchELF = true;

  meta = with lib; {
    description = "A cross-platform, GPU-accelerated terminal emulator";
    homepage = "https://github.com/alacritty/alacritty";
    license = licenses.asl20;
    maintainers = with maintainers; [ filalex77 mic92 cole-h ma27 ];
    platforms = platforms.unix;
  };
}
