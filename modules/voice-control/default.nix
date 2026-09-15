{ config, lib, pkgs, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.services.voiceControl;

  useCuda = lib.elem "nvidia" config.services.xserver.videoDrivers;

  niri = pkgs.niri-unstable;

  whisperLargeV3 = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin";
    hash = "sha256-ZNGCtEC5jVIDxPm9VBVE2ExgUZbE97hF36EfsjWU0eI=";
  };

  whisperSmallEn = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
    hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
  };

  qwen = pkgs.fetchurl {
    name = "Qwen3.5-9B-Q4_K_M.gguf";
    url = "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf";
    hash = "sha256-A7dHJ6hgpWM44ELEQguz8Esv7Fc0F19MufqFPa9St+g=";
  };

  niriAction = action:
    "${niri}/bin/niri msg action ${action}";

  modeMatchType = types.submodule {
    options = {
      overview = mkOption {
        type = types.nullOr types.bool;
        default = null;
      };

      process = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      appId = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      layerNamespace = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  transformType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
      };

      pattern = mkOption {
        type = types.str;
      };

      replace = mkOption {
        type = types.str;
      };

      lowercase = mkOption {
        type = types.bool;
        default = false;
      };

      lowercaseFirst = mkOption {
        type = types.bool;
        default = false;
      };

      trimEndPunctuation = mkOption {
        type = types.bool;
        default = false;
      };

    };
  };

  defaultCommands = {
    left = niriAction "focus-column-left";
    right = niriAction "focus-column-right";
    up = niriAction "focus-window-up";
    down = niriAction "focus-window-down";
    overview = niriAction "toggle-overview";
    firefox = "focus_app firefox";
  };

  defaultModes = {
    overview = {
      priority = 100;
      match = {
        overview = true;
      };
      commands = {
        up = niriAction "focus-workspace-up";
        down = niriAction "focus-workspace-down";
      };
    };

    firefox = {
      priority = 50;
      match = {
        overview = false;
        appId = "firefox";
      };
      commands = {
        back = "key alt+left";
        forward = "key alt+right";
      };
    };
  };

  allCommandAttrs = lib.foldl'
    (acc: mode: acc // mode.commands)
    cfg.commands.default
    (builtins.attrValues cfg.commands.modes);

  commandList = pkgs.writeText "voice-commands.txt"
    (lib.concatStringsSep "\n" (builtins.attrNames allCommandAttrs) + "\n");

  dictationInstruction = ''
    Return only the resulting text. Never explain your changes.
    Never translate. Preserve the language of the speaker exactly, including mixed-language input.
    Use the injected desktop context only to resolve ambiguous recognition, spelling, capitalization, technical terms and identifiers.
    Preserve wording and meaning. Correct only obvious recognition errors.
    Preserve technical terms, identifiers, acronyms and intentional casing, often unix commands are dictated.
    Do not append sentence-ending punctuation.
    Do not add quotation marks around the result.
    NEVER Capitalise the first word! and never add the stop at the end! this is an absolute requirement!!!
    never add a Stop (".") at the end!
    recognize commands like z (with the following folder) or nvtop or htop or hx.
  '';

  whisrsConfig = (pkgs.formats.toml { }).generate "whisrs-config.toml" {
    general = {
      backend = "local-whisper";
      language = "auto";
      notify = false;
      remove_filler_words = false;
      audio_feedback = false;
      llm_post_process = true;
      llm_instruction = dictationInstruction;
    };

    "local-whisper" = {
      model_path = "${whisperLargeV3}";
      segmentation = "silence";
      phrase_silence_ms = 500;
    };

    llm = {
      api_key = "not-needed";
      model = "qwen3.5-9b";
      api_url = "http://127.0.0.1:2814/v1/chat/completions";
    };

    llm_commands = [
      {
        name = "dictate";
        hotkey = "Super+Shift+F24";
        instruction = dictationInstruction;
      }
    ];
  };

  installWhisrsConfig = pkgs.writeShellScript "install-whisrs-config" ''
    mkdir -p "$HOME/.config/whisrs"
    install -m600 ${whisrsConfig} "$HOME/.config/whisrs/config.toml"
  '';

  runtimeConfig = pkgs.writeText "voice-control-runtime.json" (builtins.toJSON {
    llmEnabled = cfg.dictation.enableLlm;
    llmDefault = cfg.llmContext.default;

    llmModes = lib.mapAttrsToList
      (name: mode: {
        inherit name;
        inherit (mode) priority context match;
      })
      cfg.llmContext.modes;

    dictationTransforms = cfg.dictation.transforms;

    dictationModes = lib.mapAttrsToList
      (name: mode: {
        inherit name;
        inherit (mode) priority match transforms;
      })
      cfg.dictation.modes;

    submitDelayMs = cfg.dictation.submitDelayMs;

    commandDefault = cfg.commands.default;

    commandModes = lib.mapAttrsToList
      (name: mode: {
        inherit name;
        inherit (mode) priority match commands;
      })
      cfg.commands.modes;
  });

  voiceControlRuntime = pkgs.rustPlatform.buildRustPackage {
    pname = "voice-control-runtime";
    version = "0.1.0";
    src = ./runtime;
    cargoLock.lockFile = ./runtime/Cargo.lock;
    buildInputs = [ pkgs.alsa-lib ];
  };
in
{
  options.services.voiceControl = {
    enable = mkEnableOption "MIDI-triggered dictation and contextual niri voice control";

    user = mkOption {
      type = types.str;
      example = "philm";
    };

    midi = {
      port = mkOption {
        type = types.str;
        example = "Osmose";
      };

      commandNote = mkOption {
        type = types.int;
        default = 48;
      };

      germanNote = mkOption {
        type = types.int;
        default = 50;
      };

      enterNote = mkOption {
        type = types.int;
        default = 52;
      };

      dictationNote = mkOption {
        type = types.int;
        default = 53;
      };
    };

    whisperCommand = {
      model = mkOption {
        type = types.package;
        default = whisperSmallEn;
      };

      pollMs = mkOption {
        type = types.int;
        default = 50;
      };

      audioMs = mkOption {
        type = types.int;
        default = 800;
      };

      vadMs = mkOption {
        type = types.int;
        default = 400;
      };

      startupMs = mkOption {
        type = types.int;
        default = 0;
      };

      audioCtx = mkOption {
        type = types.int;
        default = 128;
      };

      threads = mkOption {
        type = types.int;
        default = 4;
      };

      vadThreshold = mkOption {
        type = types.float;
        default = 0.6;
      };
    };

    commands = {
      default = mkOption {
        type = types.attrsOf types.lines;
        default = defaultCommands;
      };

      modes = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            priority = mkOption {
              type = types.int;
              default = 0;
            };

            match = mkOption {
              type = modeMatchType;
              default = { };
            };

            commands = mkOption {
              type = types.attrsOf types.lines;
              default = { };
            };
          };
        });

        default = defaultModes;
      };
    };

    dictation = {
      enableLlm = mkOption {
        type = types.bool;
        default = true;
      };

      submitDelayMs = mkOption {
        type = types.ints.unsigned;
        default = 500;
      };

      transforms = mkOption {
        type = types.listOf transformType;
        default = [ ];
      };

      modes = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            priority = mkOption {
              type = types.int;
              default = 0;
            };

            match = mkOption {
              type = modeMatchType;
              default = { };
            };

            transforms = mkOption {
              type = types.listOf transformType;
              default = [ ];
            };
          };
        });

        default = { };
      };
    };

    llmContext = {

      default = mkOption {
        type = types.lines;
        default = ''
          Use the desktop context only to resolve ambiguous speech recognition, spelling, capitalization, application names, technical terminology and identifiers.
          Never translate. Preserve the speaker's language and intended wording.
          Do not paraphrase or infer text that was not spoken.
        '';
      };

      modes = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            priority = mkOption {
              type = types.int;
              default = 0;
            };

            match = mkOption {
              type = modeMatchType;
              default = { };
            };

            context = mkOption {
              type = types.lines;
            };

          };
        });

        default = { };
      };
    };
  };

  config = mkIf cfg.enable {
    nixpkgs = {
      config.allowUnfree = lib.mkDefault true;
      overlays = [
        (import ./overlay.nix {
          whisrsSrc = inputs.whisrs;
          inherit useCuda;
        })
      ];
    };

    hardware.uinput.enable = true;

    users.users.${cfg.user}.extraGroups =
      lib.mkAfter [ "input" "uinput" ];

    services.udev.packages = [
      pkgs.whisrs-voice-control
    ];

    environment.systemPackages = [
      pkgs.whisrs-voice-control
      pkgs.whisper-command-env
      pkgs.alsa-utils
      pkgs.dotool
      niri
    ];

    services.llama-cpp = {
      enable = cfg.dictation.enableLlm;

      package = pkgs.llama-cpp.override {
        cudaSupport = useCuda;
        vulkanSupport = !useCuda;
      };

      settings = {
        host = "127.0.0.1";
        port = 2813;
        model = "${qwen}";
        alias = "qwen3.5-9b";
        n-gpu-layers = "all";
        flash-attn = "on";
        ctx-size = 131072;
        reasoning = "off";
        n-predict = 512;
        parallel = 1;
      };
    };

    systemd.user.services.whisrs-context-proxy = {
      description = "Context-aware whisrs LLM proxy";
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionUser = cfg.user;

      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${voiceControlRuntime}/bin/voice-control-runtime"
          "proxy"
          "--config"
          "${runtimeConfig}"
          "--dotool"
          "${pkgs.dotool}/bin/dotool"
        ];
        Restart = "always";
        RestartSec = 1;
      };
    };

    systemd.user.services.whisrs = {
      description = "whisrs speech-to-text";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "whisrs-context-proxy.service" ];
      after = [
        "whisrs-context-proxy.service"
      ];
      unitConfig.ConditionUser = cfg.user;
      environment = {
        XKB_DEFAULT_LAYOUT = "us";
        XKB_DEFAULT_VARIANT = "colemak";
      };

      serviceConfig = {
        ExecStartPre = installWhisrsConfig;
        ExecStart = "${pkgs.whisrs-voice-control}/bin/whisrsd";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    systemd.user.services.voice-command = {
      description = "Guided Whisper contextual niri voice commands";
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionUser = cfg.user;

      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${voiceControlRuntime}/bin/voice-control-runtime"
          "commands"
          "--config"
          "${runtimeConfig}"
          "--whisper"
          "${pkgs.whisper-command-env}/bin/whisper-command"
          "--model"
          "${cfg.whisperCommand.model}"
          "--command-list"
          "${commandList}"
          "--dotool"
          "${pkgs.dotool}/bin/dotool"
          "--gate"
          "%t/voice-command.enabled"
          "--poll-ms"
          (toString cfg.whisperCommand.pollMs)
          "--audio-ms"
          (toString cfg.whisperCommand.audioMs)
          "--vad-ms"
          (toString cfg.whisperCommand.vadMs)
          "--startup-ms"
          (toString cfg.whisperCommand.startupMs)
          "--audio-ctx"
          (toString cfg.whisperCommand.audioCtx)
          "--threads"
          (toString cfg.whisperCommand.threads)
          "--vad-threshold"
          (toString cfg.whisperCommand.vadThreshold)
        ];
        Restart = "always";
        RestartSec = 1;
      };
    };

    systemd.user.services.midi-voice-control = {
      description = "MIDI controls for dictation and niri voice commands";
      wantedBy = [ "graphical-session.target" ];
      wants = [
        "whisrs.service"
        "voice-command.service"
      ];
      after = [
        "whisrs.service"
        "voice-command.service"
      ];
      unitConfig.ConditionUser = cfg.user;

      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${voiceControlRuntime}/bin/voice-control-runtime"
          "midi"
          "--port"
          cfg.midi.port
          "--whisrs"
          "${pkgs.whisrs-voice-control}/bin/whisrs"
          "--dotool"
          "${pkgs.dotool}/bin/dotool"
          "--gate"
          "%t/voice-command.enabled"
          "--command-note"
          (toString cfg.midi.commandNote)
          "--german-note"
          (toString cfg.midi.germanNote)
          "--enter-note"
          (toString cfg.midi.enterNote)
          "--dictation-note"
          (toString cfg.midi.dictationNote)
        ];
        ExecStopPost = pkgs.writeShellScript "voice-control-midi-cleanup" ''
          rm -f "$XDG_RUNTIME_DIR/voice-command.enabled"
          printf 'keyup enter\n' | ${pkgs.dotool}/bin/dotool || true
        '';
        Restart = "always";
        RestartSec = 1;
      };
    };
  };
}
