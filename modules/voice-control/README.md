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

  whisperCommand = {
    enable = true;
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

Holding `Mod+A` starts the same English dictation session; releasing either
key stops it. Holding `Mod+Shift+A` does the same for German. Set
`services.voiceControl.keyboard.englishShortcut` or `.germanShortcut` to
change either binding. The keyboard listener reads key state without taking
events from niri; extra modifiers do not trigger the other shortcut. One
`midi-voice-control` user service handles both MIDI and keyboard input.

Keyboard dictation queues phrases until the shortcut letter and all modifiers
have been released. Text, transform keystrokes, and automatic Enter wait for
release, so held Super/Shift keys cannot turn dictation into niri shortcuts.
MIDI dictation still streams when no keyboard dictation shortcut is held.

The patched whisper-command accepts:

- `WHISPER_COMMAND_POLL_MS`
- `WHISPER_COMMAND_AUDIO_MS`
- `WHISPER_COMMAND_VAD_MS`
- `WHISPER_COMMAND_STARTUP_MS`
- `WHISPER_COMMAND_GATE_FILE`

When enabled (the default), the command process stays warm. While the gate file
does not exist it clears buffered audio and skips recognition.

Set `services.voiceControl.whisperCommand.enable = false;` and rebuild/switch
your NixOS configuration to disable the command service entirely. Its model
will not load into VRAM. Dictation remains enabled and uses its own model.

## Dictation casing and command aliases

The repository configuration leaves `dictation.vocabulary` empty and disables
LLM rewriting. Whisrs embeds vocabulary in Whisper's initial prompt, so a long
lowercase list can bias normal transcription. Regex transforms run after
recognition and provide an offline command vocabulary without that prompt.
Completed English utterances of one to three words are lowercased in full and
lose trailing dots. German utterances of the same length lose trailing dots
without changing capitalization. Longer sentences and streamed fragments do not
receive these short-recording corrections.

`terminal-transforms.nix` contains the offline vocabulary, including the user's
recorded misrecognitions for `rg`, `ll`, `nixpkgs`, `cargo`, `nix flake update`,
`codex`, `ssh`, `htop`, `fd`, and `git clone`. Terminal input is treated primarily
as commands, including ordinary argument tails and Rust/JavaScript/TypeScript
tooling. Command names are normalized; argument casing is retained except when
the English short-recording rule has already lowercased the entire input.
Spelled SSH forms such as `s.s.h.`, `s. s. h.`, and `s s h` normalize to `ssh`,
including when followed by a host and options.

Git prefixes also accept `kid`/`kids`/`kidz` (`kid push` → `git push`) and
`skip` (`skip status` → `git status`). `skid` and `skit` also mean `git`,
alone or before known subcommands. `diff` accepts `different`, `div`, `def`,
`tiff`, and `dev`: `good. def`, `kids. diff`, `kidz def`, `good. tiff`, and `good dev` all
become `git diff`. `Git logger`, `git longer`, and `good luck` become `git log`.
Recognition-added `a`/`the`/`that`/`to` before a diff variant are also accepted:
`git a diff`, `git the diff`, `git that div`, and `git to diff` → `git diff`,
including flags and file arguments.
`git a pull` and `git the pull` → `git pull`, including remote/branch arguments
and attached flags.
`git to push` → `git push`, also with remote/branch arguments and flags.
`git there` also means `git diff`. The exact complete utterance
`git the fuck out of here` is treated as a misrecognition of `git diff`.
Punctuation variants such as `git the,diff` and `git the diff,--stat` are
supported too. Sentence mentions and later streamed fragments remain literal.
These Git prefixes work with the other known subcommands, including punctuation
between command words and attached options.
Command corrections apply only at the beginning of a recording. Later words
in a sentence, including fragments emitted after a pause, remain literal.
Spoken punctuation and the global `draw x` correction still apply throughout.
`droics` and `droix` normalize to lowercase `droix` in every application and
within prose, including casing and inserted straight/curly apostrophes
(`DROICS`, `DROIC'S`, `Droi’cs`, `DROI'X`). Surrounding quotes and possessives
are retained; longer identifiers such as `droicsAdapter` stay unchanged.

Nested Nix flake commands normalize even with arguments:
`nix Flake Update LLM-Agents` → `nix flake update llm-agents`.
Leading bare input names use the canonical spelling declared in this repository's
`flake.nix`. Unknown names, quoted arguments, paths, and flag values keep their
casing; flake check/show/lock also normalize their command words with arguments.

Spoken slash joins paths (`something, slash, blub` → `something/blub`). Dash and
minus join identifiers (`some dash kebab minus case` → `some-kebab-case`), or
form options after known command heads (`rg dash e double dash something` →
`rg -e --something`). Commas adjacent to these spoken separators are absorbed.
Explicitly quoted literals preserve slash/dash/minus words. Spoken `dot` always
becomes `.`, even inside quotes; the sole exception is the complete `z dot`
directory command. Dot conversion follows trailing-dot cleanup, so deliberately
spoken dots survive. Filenames join (`file dot rs` → `file.rs`), while terminal
command arguments stay separated (`rg dot` → `rg .`).
Spoken `underscore` (also `under score`/`under-score`, any casing) becomes `_`
and joins adjacent words in every application, including quotes and streamed
fragments: `snake underscore case` → `snake_case`, and
`file underscore name dot rs` → `file_name.rs`. Recognition commas are absorbed.
After a terminal command, argument spacing is kept (`rg underscore` → `rg _`).
Outside terminal mode, dash/minus still join identifiers and slash still joins
paths; shell option spacing is enabled only in terminal context.

Common spoken forms such as `git c dash a`, `git add Punkt`, and
`git commit minus m "Fix Casing"` have dedicated rules.

These rules apply in the terminal mode only. Codex and Helix have higher-priority
modes, so shell aliases do not rewrite their prose. Shell corrections type text
without pressing Enter. Repeated command aliases within one transcript (such as
`commit git commit`) collapse to one command; repeated prose and argument text
are retained. This does not deduplicate separate streamed fragments or separate
recordings. Removing the prompt may help recognition, but microphone testing is
still needed to assess recognition errors and the source of repetitions.

Run `bash modules/voice-control/test-transforms.sh` in a Rust environment with
ALSA available to the linker. It evaluates the actual configured rules and checks
command variants, repetition, case-sensitive arguments, German/English prose,
and application-mode isolation using the runtime's Rust regex engine.

## Helix voice commands

While holding the explicit voice-command control with Helix focused:

- `go to` / `goto` / `go-to` / `go too` / `go two` / `definition`: `Esc`, `gd` (definition).
- `back` / `beck` / `backward(s)` / `go back` / `jump back`: `Esc`, `Ctrl+o`.
- `into` / `in to` / `in-to` / `forward(s)` / `go forward` / `jump forward`: `Esc`, `Ctrl+i`.
- `up` / `half page up` / `page up`: `Esc`, `Ctrl+u` (half page).
- `down` / `half page down` / `page down`: `Esc`, `Ctrl+d` (half page).

Matching currently knows the foreground Helix process, not its editor mode.
Explicit commands intentionally leave insert mode via Escape. Existing dictation
shortcuts also lack an insert-mode guard. Reliable automatic gating would require
Helix to publish per-process mode state (its internal `OnModeSwitch` hook is a
possible integration point), including initial state, cleanup and prompt/picker
focus; remembering injected keys is insufficient to infer actual editor state.

Terminal zoxide dictation always emits lowercase `z` and lowercases the entire
following path/query, even for German and streamed or multi-word input. For
example, `Z MyProject` → `z myproject` and `Z My minus Project slash Src` →
`z my-project/src`. In zoxide queries, spoken dash/minus join path-name segments;
`z dot` remains literal. These rules do not apply inside Codex/Helix dictation.

A leading whole word `the` is also a terminal zoxide alias for German-accented
`z`: `the MyProject` → `z myproject`, and `the dot` → `z dot`. It follows the
same recording-start restriction; later sentence mentions remain literal.

Joined leading `z` forms in terminal dictation are also zoxide commands:
`zm/` → `z m/`, `zMyProject/Src` → `z myproject/src`. The application exception
is `zathura`: `Satura` (any casing), `Sathura`, and `Zatura` normalize to `zathura`
before zoxide splitting, including when followed by arguments. These aliases
and splitting rules stay out of other application contexts.

Spoken `colon` becomes `:` everywhere, including quotes. Leading spaces/commas
are removed, while following spacing is retained (`label colon value` →
`label: value`); combined with slash it also supports `https://…`.

Terminal Git correction separates attached flags and joins recognized multiword
long-option names: `git diff--compact summary` → `git diff --compact-summary`,
`git push --force with lease` → `git push --force-with-lease`, and
`git diff --ignore all space` → `git diff --ignore-all-space`. Quoted literals,
option values, unknown options and paths after standalone `--` are retained.
The offline catalogue `runtime/src/git-long-options.txt` was collected from
Git 2.55.0's `--git-completion-helper` for diff, log, show, commit, status, push,
fetch, pull, branch, rebase, clone, add, restore, switch, checkout, merge and reset.
Only known option names are joined; this is not a general shell parser.

Command-boundary comma/period cleanup is shared across terminal commands:
`git,diff` → `git diff`, `cargo. test` → `cargo test`, and
`nix.flake.update` → `nix flake update`. Recognized nested Git/Nix subcommands
are supported too. Punctuation inside argument tokens, URLs and quoted strings
is preserved, as are `.config`, `./path`, standalone dots and `.#`/`.hashtag`
flake references. The cleanup does not apply in browser/Codex/Helix dictation.
