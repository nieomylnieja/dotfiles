{
  description = "The nixos configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-experimental.url = "github:nixos/nixpkgs/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-experimental,
    home-manager,
    nur,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    overlay-stable = final: prev: {
      stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    };
    overlay-experimental = final: prev: {
      experimental = import nixpkgs-experimental {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in {
    nixosConfigurations = {
      home = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ({
            config,
            pkgs,
            ...
          }: {nixpkgs.overlays = [overlay-stable overlay-experimental];})
          ./config/nixos/home/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.mh = import ./config/home-manager/home.nix;
            nixpkgs.overlays = [nur.overlays.default];
          }
        ];
      };
      work = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ({
            config,
            pkgs,
            ...
          }: {nixpkgs.overlays = [overlay-stable overlay-experimental];})
          ./config/nixos/work/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.mh = import ./config/home-manager/home.nix;
            nixpkgs.overlays = [nur.overlays.default];
          }
        ];
      };
    };
  };
}
