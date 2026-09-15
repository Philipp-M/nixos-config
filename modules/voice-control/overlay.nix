{ whisrsSrc, useCuda }:
final: prev:
let
  cuda = final.cudaPackages;
  cudaStubs = "${final.lib.getOutput "stubs" cuda.cuda_cudart}/lib/stubs";

  buildRustPackage =
    if useCuda then
      final.rustPlatform.buildRustPackage.override
        {
          stdenv = cuda.backendStdenv;
        }
    else
      final.rustPlatform.buildRustPackage;
in
{
  # Same automatic backend policy as whisrs:
  # NVIDIA-configured NixOS -> CUDA, otherwise Vulkan.
  whisper-command-env =
    (prev.whisper-cpp.override {
      cudaSupport = useCuda;
      vulkanSupport = !useCuda;
    }).overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            '#include <cstdio>' \
            $'#include <cstdlib>\n#include <cstdio>'

        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            'int main(int argc, char ** argv) {' \
            $'int main(int argc, char ** argv) {\n    setvbuf(stdout, nullptr, _IOLBF, 0);'

        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            'void whisper_print_usage(int argc, char ** argv, const whisper_params & params);' \
            $'static int env_ms(const char * name, int fallback) {\n    const char * value = std::getenv(name);\n    if (value == nullptr || value[0] == 0) return fallback;\n\n    char * end = nullptr;\n    const long parsed = std::strtol(value, &end, 10);\n    if (end == value || *end != 0 || parsed < 0) return fallback;\n\n    return static_cast<int>(parsed);\n}\n\nstatic bool command_gate(audio_async & audio) {\n    const char * path = std::getenv("WHISPER_COMMAND_GATE_FILE");\n    if (path == nullptr || path[0] == 0) return true;\n\n    static bool was_active = true;\n    const bool active = is_file_exist(path);\n\n    if (active == was_active) return active;\n\n    if (active) {\n        audio.resume();\n        audio.clear();\n    } else {\n        audio.clear();\n        audio.pause();\n    }\n\n    was_active = active;\n    return false;\n}\n\nvoid whisper_print_usage(int argc, char ** argv, const whisper_params & params);'

        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            'std::this_thread::sleep_for(std::chrono::milliseconds(100));' \
            'std::this_thread::sleep_for(std::chrono::milliseconds(std::max(1, env_ms("WHISPER_COMMAND_POLL_MS", 100))));'

        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            'audio.get(2000, pcmf32_cur);' \
            $'if (!command_gate(audio)) continue;\n        audio.get(std::max(1, env_ms("WHISPER_COMMAND_AUDIO_MS", 2000)), pcmf32_cur);'

        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            '::vad_simple(pcmf32_cur, WHISPER_SAMPLE_RATE, 1000, params.vad_thold, params.freq_thold, params.print_energy)' \
            '::vad_simple(pcmf32_cur, WHISPER_SAMPLE_RATE, std::min(std::max(1, env_ms("WHISPER_COMMAND_VAD_MS", 1000)), std::max(1, env_ms("WHISPER_COMMAND_AUDIO_MS", 2000))), params.vad_thold, params.freq_thold, params.print_energy)'

        substituteInPlace examples/command/command.cpp \
          --replace-fail \
            'std::this_thread::sleep_for(std::chrono::milliseconds(1000));' \
            'std::this_thread::sleep_for(std::chrono::milliseconds(env_ms("WHISPER_COMMAND_STARTUP_MS", 1000)));'
      '';
    });
  whisrs-voice-control = buildRustPackage {
    pname = "whisrs";
    version = "git";
    src = whisrsSrc;
    cargoLock.lockFile = whisrsSrc + "/Cargo.lock";
    patches = [
      ./whisrs-explicit-dictation.patch
      ./whisrs-llm-command-edges.patch
      ./whisrs-streaming-transform.patch
    ];
    doCheck = false;

    buildFeatures = [ (if useCuda then "cuda" else "vulkan") ];

    nativeBuildInputs = [
      final.pkg-config
      final.cmake
      final.llvmPackages.clang
      final.rustPlatform.bindgenHook
    ]
    ++ final.lib.optionals useCuda [
      cuda.cuda_nvcc
      final.autoAddDriverRunpath
    ]
    ++ final.lib.optionals (!useCuda) [
      final.shaderc
    ];

    buildInputs = [
      final.alsa-lib
      final.libxkbcommon
    ]
    ++ final.lib.optionals useCuda [
      cuda.cccl
      cuda.cuda_cudart
      cuda.libcublas
    ]
    ++ final.lib.optionals (!useCuda) [
      final.shaderc
      final.vulkan-headers
      final.vulkan-loader
      final.spirv-headers
    ];

    # whisper-rs-sys currently emits -lcuda with FHS-oriented search paths.
    # This is link-time only; autoAddDriverRunpath finds the real driver at runtime.
    RUSTFLAGS = final.lib.optionals useCuda [
      "-Lnative=${cudaStubs}"
    ];

    postInstall = ''
      substituteInPlace contrib/99-whisrs.rules \
        --replace-quiet /usr/bin/setfacl ${final.acl}/bin/setfacl

      install -Dm644 contrib/whisrs.1 $out/share/man/man1/whisrs.1
      install -Dm644 contrib/whisrsd.1 $out/share/man/man1/whisrsd.1
      install -Dm644 contrib/99-whisrs.rules $out/lib/udev/rules.d/99-whisrs.rules
      install -Dm644 contrib/whisrs.service $out/lib/systemd/user/whisrs.service
    '';
  };
}
