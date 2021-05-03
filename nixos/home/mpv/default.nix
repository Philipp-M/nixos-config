{ pkgs, lib, config, ... }: {
  programs.mpv = {
    enable = true;
    config = {
      x11-netwm = "yes"; # necessary for xmonads fullscreen
      profile = "opengl-high";
      video-sync = "audio";
    };
    profiles = {
      vdpau-high = {
        vo = "vdpau";
        profile = "opengl-hq";
        scale = "ewa_lanczossharp";
        cscale = "ewa_lanczossharp";
        video-sync = "display-resample";
        interpolation = "yes";
        tscale = "oversample";
        vf = "vdpaupp:deint=yes:deint-mode=temporal-spatial:hqscaling=1";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      vdpau-low = {
        vo = "vdpau";
        profile = "opengl-hq";
        video-sync = "display-resample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      opengl-high = {
        vo = "opengl";
        profile = "opengl-hq";
        video-sync = "display-resample";
        interpolation = "yes";
        tscale = "oversample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
        glsl-shader = "" + builtins.path { path = ./FSRCNN_x2_r2_32-0-2.glsl; };
        display-fps = "60";
      };
      opengl-low = {
        vo = "opengl";
        profile = "opengl-hq";
        video-sync = "display-resample";
        ytdl-format = "bestvideo+bestaudio/best";
        glsl-shader = "" + builtins.path { path = ./FSRCNNX_x2_8-0-4-1.glsl; };
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      xv-high = {
        vo = "xv";
        profile = "opengl-hq";
        scale = "ewa_lanczossharp";
        cscale = "ewa_lanczossharp";
        video-sync = "display-resample";
        interpolation = "yes";
        tscale = "oversample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      xv-low = {
        vo = "xv";
        profile = "opengl-hq";
        video-sync = "display-resample";
        ytdl-format = "bestvideo+bestaudio/best";
        x11-bypass-compositor = "yes";
        af = "acompressor";
      };
      fun = { vo = "tct"; };
    };
  };
}
