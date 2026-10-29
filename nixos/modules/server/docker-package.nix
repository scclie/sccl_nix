{ docker, containerd, buildGoModule, callPackage, lib }:
let
  revision = docker.docker-containerd.src.rev;
  version = lib.removePrefix "refs/tags/v" revision;
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # remove this override once stable nixpkgs includes the sec release
  fixedContainerd = (containerd.override {
    buildGoModule = buildGoModule.override {
      go = callPackage ./go.nix {};
    };
  }).overrideAttrs (prev: {
    makeFlags = map (lib.replaceStrings
      [ "REVISION=${prev.src.rev}" "VERSION=v${prev.version}" ]
      [ "REVISION=${revision}" "VERSION=v${version}" ]) prev.makeFlags;
  });
in docker.override { containerd = fixedContainerd; }
