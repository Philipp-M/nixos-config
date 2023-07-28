{ ... }:
{ lib, config, ... }: {
  options.modules.create-directories.enable = lib.mkEnableOption "Creates all kind of common directories (dev mostly)";

  config = lib.mkIf config.modules.create-directories.enable {
    home.activation.createDirectories =
      (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # home
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/screenshots/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/wallpaper/

        # development
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/c/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/deep-learning/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/desktop-environment/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/dev-ops/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/gfx/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/haskell/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/python/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/rust/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/rust/playground
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/www/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/www/spa-test/
             $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/personal/www/frontend-libs/
      '');
  };
}
