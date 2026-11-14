#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT
# Evaluate the actual configured modes, without realizing models or a full OS.
nix eval --json --impure --expr '
  let voice = (import ./configuration.nix {
    config = {}; pkgs = {}; lib = {}; inputs = {};
  }).services.voiceControl;
  d = voice.dictation;
  in {
    llmEnabled = d.enableLlm;
    llmDefault = "";
    dictationTransforms = d.transforms;
    dictationModes = builtins.attrValues
      (builtins.mapAttrs (name: mode: mode // { inherit name; }) d.modes);
    commandModes = [ (voice.commands.modes.helix // { name = "helix"; }) ];
  }
' > "$fixture"
VOICE_CONTROL_TEST_CONFIG="$fixture" cargo test \
  --manifest-path modules/voice-control/runtime/Cargo.toml \
  configured_dictation -- --include-ignored
