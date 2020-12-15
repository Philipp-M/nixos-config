{ lib, ... }: {
  home.activation.createDirectories =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/work/scripts/
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/work/playground/
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/dev/work/frontend-libs/
    '';

  home.activation.linkConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG $HOME/.config/nvim/
    $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
      ${builtins.toPath ../../config/nvim/init.vim} $HOME/.config/nvim/init.vim
    $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
      ${
        builtins.toPath ../../config/nvim/coc-settings.json
      } $HOME/.config/nvim/coc-settings.json

    # temporary for xmonad debugging/testing/prototyping
    $DRY_RUN_CMD ln -fs $VERBOSE_ARG \
      ${builtins.toPath ../../xmonad/xmonad.hs} $HOME/.xmonad/xmonad.hs
  '';
}
