{ mpv-ai-upscale, mpv-default-shader-pack, ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.mpv.enable = lib.mkEnableOption "Enable personal mpv config";

  config = lib.mkIf config.modules.gui.mpv.enable {
    programs.mpv = {
      enable = true;
      config = {
        x11-netwm = "yes"; # necessary for xmonads fullscreen
        # gpu-api="vulkan";
        profile = "gpu-high";
        # video-sync = "audio";
        af = "scaletempo2";
        video-sync = "display-resample";
        sub-font-size = 23;
        cache = "yes";
        demuxer-max-bytes = "2000M";
        vo = "gpu-next";
        gpu-context = "auto";
        gpu-api = "vulkan";
        vulkan-queue-count = 3;
        fbo-format = "rgba16f";

        # hwdec = "nvdec";
        hwdec = "auto";

        hr-seek = "yes";
        osd-font = "Segoe UI";
        osd-font-size = 55;
        osd-scale = 0.5;

        save-position-on-quit = "yes";
        watch-later-options = "start";
        reset-on-next-file = "pause";

        cache-pause = "yes";
        cache-pause-initial = "yes";
        cache-secs = 300;
        demuxer-max-back-bytes = "12009999M";
        demuxer-cache-wait = "yes";

        profile-restore = "copy-equal";

        volume = 100;
        volume-max = 100;

        blend-subtitles = "video";
        alang = "jpn";
        slang = "eng";

        dither = "fruit";
        dither-depth = "auto";
        deband = "yes";
        deband-iterations = 4;
        deband-threshold = 48;
        deband-range = 16;
        deband-grain = 48;

        screenshot-format = "png";
        screenshot-directory = "~~/screenshots/";
        screenshot-template = "%F__%P__%04n";

        image-display-duration = "inf";

        glsl-shader = [
          "${mpv-default-shader-pack}/shaders/noise_static_luma.hook"
          "${mpv-default-shader-pack}/shaders/noise_static_chroma.hook"
        ];
      };

      profiles = {
        # Profiles from JSON "profiles":
        nvscaler = {
          # Nvidia Image Scaler
          glsl-shader = [ "${mpv-default-shader-pack}/shaders/NVScaler.glsl" ];
        };

        "AMD FidelityFX Super Resolution" = {
          glsl-shader = [ "${mpv-default-shader-pack}/shaders/FSR.glsl" ];
        };

        "AMD FidelityFX Contrast Adaptive Sharpening" = {
          glsl-shader = [ "${mpv-default-shader-pack}/shaders/CAS-scaled.glsl" ];
        };

        anime4k-high-a = {
          # Anime4K A (HQ) - For Very Blurry/Compressed
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/Anime4K_Clamp_Highlights.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x2.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x4.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
          ];
        };

        anime4k-high-b = {
          # Anime4K B (HQ) - For Blurry/Ringing
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/Anime4K_Clamp_Highlights.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_Soft_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x2.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x4.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
          ];
        };

        anime4k-high-c = {
          # Anime4K C (HQ) - For Crisp/Sharp
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/Anime4K_Clamp_Highlights.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x2.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x4.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
          ];
        };

        anime4k-high-aa = {
          # Anime4K AA (HQ) - For Very Blurry/Compressed
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/Anime4K_Clamp_Highlights.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x2.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x4.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_M.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
          ];
        };

        anime4k-high-bb = {
          # Anime4K BB (HQ) - For Blurry/Ringing
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/Anime4K_Clamp_Highlights.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_Soft_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x2.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x4.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_Soft_M.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
          ];
        };

        anime4k-high-ca = {
          # Anime4K CA (HQ) - For Crisp/Sharp
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/Anime4K_Clamp_Highlights.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x2.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_AutoDownscalePre_x4.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Restore_CNN_M.glsl"
            "${mpv-default-shader-pack}/shaders/Anime4K_Upscale_CNN_x2_M.glsl"
          ];
        };

        generic = {
          # FSRCNNX: composed of groups "fsrcnnx", "ssim-downscaler", "krig-bilateral"
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/FSRCNNX_x2_8-0-4-1.glsl"
            "${mpv-default-shader-pack}/shaders/SSimDownscaler.glsl"
            "${mpv-default-shader-pack}/shaders/KrigBilateral.glsl"
          ];
          scale = "ewa_lanczos";
        };

        "generic-high" = {
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/FSRCNNX_x2_16-0-4-1.glsl"
            "${mpv-default-shader-pack}/shaders/SSimDownscaler.glsl"
            "${mpv-default-shader-pack}/shaders/KrigBilateral.glsl"
          ];
          scale = "ewa_lanczos";
        };

        "nnedi-high" = {
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/nnedi3-nns64-win8x6.hook"
            "${mpv-default-shader-pack}/shaders/SSimDownscaler.glsl"
            "${mpv-default-shader-pack}/shaders/KrigBilateral.glsl"
          ];
        };

        "nnedi-very-high" = {
          glsl-shader = [
            "${mpv-default-shader-pack}/shaders/nnedi3-nns128-win8x6.hook"
            "${mpv-default-shader-pack}/shaders/SSimDownscaler.glsl"
            "${mpv-default-shader-pack}/shaders/KrigBilateral.glsl"
          ];
        };

        vdpau-high = {
          vo = "vdpau";
          profile = "gpu-hq";
          scale = "ewa_lanczossharp";
          cscale = "ewa_lanczossharp";
          video-sync = "display-resample";
          interpolation = "yes";
          tscale = "oversample";
          vf = "vdpaupp:deint=yes:deint-mode=temporal-spatial:hqscaling=1";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
        };
        vdpau-low = {
          vo = "vdpau";
          profile = "gpu-hq";
          video-sync = "display-resample";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
        };
        gpu-high = {
          vo = "gpu-next";
          profile = "gpu-hq";
          video-sync = "display-resample";
          interpolation = "yes";
          tscale = "oversample";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
          glsl-shader = "${mpv-ai-upscale}/mpv user shaders/Photo/4x/AiUpscale_HQ_Sharp_4x_Photo.glsl";
        };
        gpu-low = {
          vo = "gpu-next";
          profile = "gpu-hq";
          video-sync = "display-resample";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
        };
        xv-high = {
          vo = "xv";
          profile = "gpu-hq";
          scale = "ewa_lanczossharp";
          cscale = "ewa_lanczossharp";
          video-sync = "display-resample";
          interpolation = "yes";
          tscale = "oversample";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
        };
        xv-low = {
          vo = "xv";
          profile = "gpu-hq";
          video-sync = "display-resample";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
        };
        fun = { vo = "tct"; };
      };
    };
  };
}
