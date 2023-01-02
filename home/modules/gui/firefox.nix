{ ... }:
{ pkgs, lib, config, ... }: {
  options.modules.gui.firefox.enable = lib.mkEnableOption "Enable personal firefox config";

  config = lib.mkIf config.modules.gui.firefox.enable {
    programs.firefox = {
      enable = true;

      profiles = {
        default = {
          isDefault = true;
          settings = {
            "beacon.enabled" = false;
            "browser.safebrowsing.appRepURL" = "";
            "browser.send_pings" = false;
            "browser.startup.page" = 3;
            "browser.tabs.closeWindowWithLastTab" = true;
            "browser.tabs.tabMinWidth" = 30;
            "browser.urlbar.speculativeConnect.enabled" = false;
            "devtools.theme" = "${config.theme.base16.kind}";
            "dom.battery.enabled" = false;
            "dom.event.clipboardevents.enabled" = false;
            "dom.webgpu.enabled" = true;
            "extensions.pocket.enabled" = false;
            "general.smoothScroll" = false;
            "geo.enabled" = false;
            "gfx.webrender.all" = true;
            "gfx.webrender.precache-shaders" = true;
            "gfx.webrender.compositor" = true;
            "gfx.webrender.compositor.force-enabled" = true;
            "gfx.webrender.program-binary-disk" = true;
            "layout.css.devPixelsPerPx" = "1.25";
            "media.gpu-process-decoder" = true;
            "media.navigator.enabled" = false;
            "media.video_stats.enabled" = false;
            "mousewheel.acceleration.factor" = 0;
            "mousewheel.acceleration.start" = 0;
            "mousewheel.default.delta_multiplier_y" = 20;
            "network.IDN_show_punycode" = true;
            "network.allow-experiments" = false;
            "network.dns.disablePrefetch" = true;
            "network.http.referer.XOriginPolicy" = 2;
            "network.http.referer.XOriginTrimmingPolicy" = 2;
            "network.http.referer.trimmingPolicy" = 1;
            "network.prefetch-next" = false;
            "permissions.default.shortcuts" = 2; # Don't steal my shortcuts!
            "privacy.donottrackheader.enabled" = true;
            "privacy.donottrackheader.value" = 1;
            "privacy.firstparty.isolate" = true;
            "signon.rememberSignons" = false;
            "svg.context-properties.content.enabled" = true;
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "widget.content.gtk-theme-override" = config.theme.base16.name;
            "widget.content.allow-gtk-dark-theme" = true;
            "services.sync.prefs.sync.extensions.activeThemeID" = false;
          };
        };
      };
    };
  };
}
