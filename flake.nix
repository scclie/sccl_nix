{
  description = "sacculos NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05"; # stable packages frfr

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # fresh packages, might break tho

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix/release-26.05";
    zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };

outputs = { self, nixpkgs, nixpkgs-unstable, disko, home-manager, stylix, chaotic, ... }@inputs:
let
  system = "x86_64-linux";

  pkgs = import nixpkgs {
    inherit system;
  };

  pkgs-unstable = import nixpkgs-unstable {
    inherit system;
  };

  # host builder go brrr
  mkHost = hostName: nixpkgs.lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit inputs pkgs-unstable;
    };

    modules = [
      ./hosts/${hostName}/configuration.nix
      (if builtins.pathExists ./hosts/${hostName}/disko.nix
       then ./hosts/${hostName}/disko.nix
       else {})
      ./nixos/modules/zapret.nix
      stylix.nixosModules.stylix
      disko.nixosModules.disko
      home-manager.nixosModules.home-manager
      chaotic.nixosModules.default
    ];
  };

  # validate
  isValidHost = name: type:
    type == "directory" &&
    builtins.pathExists (./hosts + "/${name}/configuration.nix");

  # auto-discover hosts from the hosts/ directory
  hostEntries = builtins.readDir ./hosts;
  validHosts = builtins.filter
    (name: isValidHost name hostEntries.${name})
    (builtins.attrNames hostEntries);

  # convert list of host names to attribute set
  hostsAttrSet = builtins.listToAttrs (
    map (name: {
      name = name;
      value = mkHost name;
    }) validHosts
  );
in {
  nixosConfigurations = hostsAttrSet;

  devShells.${system} = {
    playground = pkgs.mkShell {
      packages = with pkgs; [
        # Kubernetes
        kubectl krew minikube kubernetes-helm k9s stern popeye

        # Docker
        dive lazydocker docker-compose

        # Monitoring
        prometheus grafana

        # Databases
        postgresql

        # Other
        kind yq-go jq
      ];

      shellHook = ''
        echo "🎮 Playground shell — type 'exit' to return to paper"
      '';
    };
  };
};
}
