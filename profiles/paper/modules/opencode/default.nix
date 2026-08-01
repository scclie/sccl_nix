{ pkgs, ... }:
let
  devops-skills = pkgs.fetchFromGitHub {
    owner = "abdullahkhawer";
    repo = "devops-skills";
    rev = "b9a5f86d043b3c7336ea4447b9a204e076286b9d";
    sha256 = "sha256-khhaVjvjlEdK1dA2sg99sdTorP95y8XDhPv6LLTlqdw=";
  };

  superpowers = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "44c9b2d6e889982ac18c27d05a19fefe335194e1";
    sha256 = "sha256-fnl+HbPL2qD5Zgz8a1NctjFJSqu6UsyHJAhQMLQNXXc=";
  };
in {
  home.packages = [ pkgs.opencode ];

  home.file.".opencode" = {
    source = pkgs.runCommand "opencode-config" { } ''
      mkdir -p $out/skills
      cp -r ${devops-skills}/skills/* $out/skills/
      cp -r ${superpowers}/skills/* $out/skills/
      cp ${./opencode.json} $out/opencode.json
    '';
    recursive = true;
  };
}
