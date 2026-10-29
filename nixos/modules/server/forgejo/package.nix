{ callPackage, path, buildGoModule }:

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# remove this override once stable nixpkgs includes the sec release
callPackage (import (path + "/pkgs/by-name/fo/forgejo/generic.nix") {
  version = "16.0.7";
  hash = "sha256-Wvvpm4qSvNgtFrVkCrKB69gizNE3HJ3uOyeWBZESuCE=";
  npmDepsHash = "sha256-l2gP1IYR9d3H6lDBSM2so+IXRPO1QKdE7DVydmWVs3I=";
  vendorHash = "sha256-wOAbZ6eEwlavMIcTOmqPpdgLNcgylCX4MwxuI/35YZw=";
}) {
  buildGoModule = buildGoModule.override {
    go = callPackage ../go.nix {};
  };
}
