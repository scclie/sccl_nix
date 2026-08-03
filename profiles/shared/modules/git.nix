{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "scclie";
        email = "git@sccl.cc";
        signingKey = "CF8645060B459DAFE7897056E75EFAEC7946D96A";
      };

      commit.gpgsign = true;

      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "vim";

      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "log --graph --oneline --all";
      };
    };
  };
}
