{ ... }:
{ lib, config, ... }:
{
  options.modules.cli.git.enable = lib.mkEnableOption "Enable personal git config";

  config = lib.mkIf config.modules.cli.git.enable {
    programs.gitui.enable = true;
    programs.difftastic = {
      enable = true;
      git = {
        enable = true;
        diffToolMode = true;
      };
      options = {
        background = "light";
        sort-paths = true;
      };
    };
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "Philipp Mildenberger";
          email = "philipp@mildenberger.me";
        };
        init.defaultBranch = "main";
        safe.directory = "*";
        pull.rebase = true;
        rebase.autostash = true;
        rerere.enabled = true;
        submodule.recurse = true;
        alias = {
          pushall = "!git remote | xargs -L1 git push --all";
          c = "commit -v";
        };
      };
      lfs.enable = true;
    };
  };
}
