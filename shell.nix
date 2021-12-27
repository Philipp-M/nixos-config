let agenix-default = (import
  (builtins.fetchTarball {
    url = "https://github.com/ryantm/agenix/archive/53aa91b4170da35a96fab1577c9a34bc0da44e27.tar.gz";
    sha256 = "sha256:1y9ic1hg7nlcspwnbq6lci61yxd5z5shkyswf7a8n2a2l9izc8r7";
  })
  { }).agenix;
in
{ pkgs ? import <nixpkgs> { }, agenix ? agenix-default }:

with pkgs;
let nixBin =
  writeShellScriptBin "nix" ''
    ${nixFlakes}/bin/nix --option experimental-features "nix-command flakes" "$@"
  '';
in
mkShell {
  buildInputs = [
    git
    nix-zsh-completions
    git-crypt
    agenix
    (nixos { nix.package = nixFlakes;}).nixos-rebuild
  ];
  shellHook = ''
    export FLAKE="$(pwd)"
    export PATH="$FLAKE/bin:${nixBin}/bin:$PATH"
  '';
}
