{
  description = "Fleet: fleetix, canix-toolbelt, infernix and their managers, qualified together";

  inputs = {
    # Components are git submodules; evaluate them as part of this flake's source.
    self.submodules = true;

    # One shared Rust toolchain and project framework, at the revisions Canix
    # consumes. Every other input stays the component's own.
    harbor-rs.url = "github:caniko/harbor-rs/088186303fc68c839c047549c471874654e07bd4";
    nixpkgs.follows = "harbor-rs/nixpkgs";
    plinth.url = "github:caniko/plinth/a21321fddd3d06eecf3399765d720923ff055780";
    nix-pklx = {
      url = "github:caniko/nix-pklx/683b7c69dad5a6e531dd17f980c79f1e53e099f0";
      inputs.harbor-rs.follows = "harbor-rs";
      inputs.plinth.follows = "plinth";
    };
    # CI shell only. Its own lock keeps the derivation the prebuild cached.
    simit.url = "github:caniko/simit/baac868484bc4761f0be08611b8458fc60960711";

    # Components. Sibling inputs follow the gitlinked checkout, so a consumer
    # is always qualified against its producers' exact revisions.
    nix-manager-core = {
      url = "./components/nix-manager-core";
      inputs.harbor-rs.follows = "harbor-rs";
    };
    fleetix.url = "./components/fleetix";
    secret-manager = {
      url = "./components/secret-manager";
      inputs.harbor-rs.follows = "harbor-rs";
      inputs.nix-manager-core.follows = "nix-manager-core";
      inputs.nix-pklx.follows = "nix-pklx";
      inputs.plinth.follows = "plinth";
    };
    dns-manager = {
      url = "./components/dns-manager";
      inputs.harbor-rs.follows = "harbor-rs";
      inputs.nix-manager-core.follows = "nix-manager-core";
      inputs.plinth.follows = "plinth";
    };
    canix-toolbelt = {
      url = "./components/canix-toolbelt";
      inputs.fleetix.follows = "fleetix";
      inputs.dns-manager.follows = "dns-manager";
      inputs.secret-manager.follows = "secret-manager";
      inputs.plinth.follows = "plinth";
    };
    infernix = {
      url = "./components/infernix";
      inputs.fleetix.follows = "fleetix";
      inputs.harbor-rs.follows = "harbor-rs";
      inputs.nix-pklx.follows = "nix-pklx";
      inputs.plinth.follows = "plinth";
    };
    bootswain = {
      url = "./components/bootswain";
      inputs.harbor-rs.follows = "harbor-rs";
      inputs.plinth.follows = "plinth";
    };
    ignitix = {
      url = "./components/ignitix";
      inputs.bootswain.follows = "bootswain";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.plinth.follows = "plinth";
    };
  };

  outputs = inputs @ {nixpkgs, ...}: let
    lib = nixpkgs.lib;
    # The component list has one owner: simit.toml.
    componentNames = map (c: c.id) (builtins.fromTOML (builtins.readFile ./simit.toml)).monorepo.components;
    systems = ["x86_64-linux"];
    forSystems = lib.genAttrs systems;
  in {
    # `component-<x>` realizes every check component <x> exports, evaluated
    # through this graph. These are what the simit component gates build.
    checks = forSystems (system:
      lib.genAttrs (map (name: "component-${name}") componentNames) (
        attr: let
          name = lib.removePrefix "component-" attr;
        in
          nixpkgs.legacyPackages.${system}.linkFarm attr (inputs.${name}.checks.${system} or {})
      ));

    devShells = forSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      ci = pkgs.mkShell {
        packages = [inputs.simit.packages.${system}.default pkgs.cargo pkgs.git pkgs.jq];
      };
    });
  };
}
