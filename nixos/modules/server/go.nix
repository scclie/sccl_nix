{ go_1_26, fetchurl }:

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# remove this override once stable nixpkgs includes the sec release

go_1_26.overrideAttrs (final: _: {
  version = "1.26.10";
  src = fetchurl {
    url = "https://go.dev/dl/go${final.version}.src.tar.gz";
    hash = "sha256-/WPog7ovK/ypPBZGsx6+9j4rHk0rMXyXidl2po2B828=";
  };
})
