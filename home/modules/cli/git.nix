{ ... }:
{ lib, config, ... }: {
  options.modules.cli.git.enable = lib.mkEnableOption "Enable personal git config";

  config = lib.mkIf config.modules.cli.git.enable {
    programs.gitui.enable = true;
    programs.git = {
      enable = true;
      userName = "Philipp Mildenberger";
      userEmail = "philipp@mildenberger.me";
      lfs.enable = true;
      diff-so-fancy.enable = true;
      extraConfig = {
        safe.directory = "*";
        pull.rebase = true;
        rebase.autostash = true;
        rerere.enabled = true;
        submodule.recurse = true;
      };
      extraConfig.init.defaultBranch = "main";
      aliases = {
        pushall = "!git remote | xargs -L1 git push --all";
        c = "commit -v";
      };
    };
  };
}
