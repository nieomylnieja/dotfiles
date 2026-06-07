{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur.url = "github:nix-community/NUR";
    googleworkspace-cli.url = "github:googleworkspace/cli";
  };

  outputs = {
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    nur,
    googleworkspace-cli,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    overlay-stable = final: prev: {
      stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in {
    formatter.${system} = pkgs.alejandra;

    homeConfigurations.mh = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {
        googleworkspaceCliPkg = googleworkspace-cli.packages.${system}.default;
      };
      modules = [
        ./home.nix
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [overlay-stable nur.overlays.default];
        }
      ];
    };
  };
}
