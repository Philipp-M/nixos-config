# voice-control NixOS module

Flake input:

```nix
inputs.whisrs.url = "github:y0sif/whisrs";
```

Pass `inputs` via `specialArgs` and import the module:

```nix
nixosConfigurations.zen = nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs; };
  modules = [
    ./configuration.nix
    ./modules/voice-control
  ];
};
```

Configuration:

```nix
services.voiceControl = {
  enable = true;
  user = "philm";
  midi.port = "YOUR CONTROLLER";

  # Defaults already match this setup:
  # 48 = hold for voice-command mode
  # 50 = hold for German dictation
  # 52 = Enter (real held uinput key)
  # 53 = hold for English dictation

  command = {
    pollMs = 50;
    audioMs = 800;
    vadMs = 400;
    startupMs = 0;
  };

  commands = {
    escape = "key esc";
    # foo = "some shell command";
  };
};
```

The dictation notes use daemon-side, idempotent `start` and `stop` commands:
note-on starts only from idle, and note-off stops only while recording. Lost or
duplicate MIDI edges therefore cannot invert the dictation state.
The Rust controller uses an exclusive ALSA sequencer subscription, handles
typed note events directly (including note-on events with zero velocity), and
deduplicates repeated edges. Another sequencer client cannot subscribe to
either end while voice control owns it.

Explicit MIDI-started dictation is push-to-talk streaming. Pauses flush
recognized phrases for immediate typing but cannot auto-stop the session; the
same audio stream resumes afterward and remains open until MIDI note-off sends
`stop`. Whisrs accumulates those phrases as one session result.

The patched whisper-command accepts:

- `WHISPER_COMMAND_POLL_MS`
- `WHISPER_COMMAND_AUDIO_MS`
- `WHISPER_COMMAND_VAD_MS`
- `WHISPER_COMMAND_STARTUP_MS`
- `WHISPER_COMMAND_GATE_FILE`

The process stays warm. While the gate file does not exist it clears buffered audio and skips recognition.
