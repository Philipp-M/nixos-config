{ ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.mpv.enable = lib.mkEnableOption "Enable personal mpv config";

  config = lib.mkIf config.modules.gui.mpv.enable {
    programs.mpv = {
      enable = true;
      config = {
        x11-netwm = "yes"; # necessary for xmonads fullscreen
        profile = "gpu-high";
        # video-sync = "audio";
        af = "scaletempo2";
        video-sync = "display-resample";
        sub-font-size = 23;
      };
      profiles = {
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
          vo = "gpu";
          profile = "gpu-hq";
          video-sync = "display-resample";
          interpolation = "yes";
          tscale = "oversample";
          ytdl-format = "bestvideo+bestaudio/best";
          x11-bypass-compositor = "yes";
          glsl-shader = "" + builtins.path { path = ./FSRCNN_x2_r2_32-0-2.glsl; };
        };
        gpu-low = {
          vo = "gpu";
          profile = "gpu-hq";
          video-sync = "display-resample";
          ytdl-format = "bestvideo+bestaudio/best";
          glsl-shader = "" + builtins.path { path = ./FSRCNNX_x2_8-0-4-1.glsl; };
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
