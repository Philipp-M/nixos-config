{ lib, buildNpmPackage, fetchzip }:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.0.28";

  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-S8Qp6xzbEnU0GOx8BfblHMsjmOZkPuTvSeCAHEZN8+E=";
  };

  npmDepsHash = "sha256-EjvkOHRwhiBBMV9xZuYqObuz93CxbqUwNgc2enBA5go=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  env.AUTHORIZED = "1";

  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --unset DEV
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    maintainers = [ ];
    mainProgram = "claude";
  };
}
