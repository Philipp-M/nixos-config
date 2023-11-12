{ pkgs, stdenv, fetchFromGitHub, pkgconfig, writeText, libX11, ncurses
, libXft, conf ? null, patches ? [], extraLibs ? []}:

with stdenv.lib;

stdenv.mkDerivation rec {
  name = "st-patched-0.8.2";

  src = fetchFromGitHub {
          owner = "ethragur";
          repo = "st-patched";
          rev = "1c335163b6bdff6a2d09d38eb86066403e6636aa";
          sha256 = "1gzhxznfjgqz51g9pfpffwl5646bxzp2sck3hyrjmaf9rr0j7bgl";
        };

  inherit patches;

  prePatch = optionalString (conf != null) ''
    cp ${writeText "config.def.h" conf} config.def.h
  '';

  nativeBuildInputs = [ pkgconfig ncurses ];
  buildInputs = [ libX11 libXft pkgs.harfbuzz ] ++ extraLibs;

  installPhase = ''
    TERMINFO=$out/share/terminfo make install PREFIX=$out
  '';

  meta = {
    homepage = "https://st.suckless.org/";
    description = "Simple Terminal for X from Suckless.org Community";
    license = licenses.mit;
    maintainers = with maintainers; [andsild];
    platforms = platforms.linux;
  };
}
