{
  description = "dotfiles utilities";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs = { self, nixpkgs, pyproject-nix, uv2nix, pyproject-build-systems, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      omnigentWorkspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = ./omnigent;
      };
      omnigentOverlay = omnigentWorkspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python312;
          }).overrideScope (pkgs.lib.composeManyExtensions [
            pyproject-build-systems.overlays.wheel
            omnigentOverlay
          ]);
          omnigentEnv = pythonSet.mkVirtualEnv "omnigent-env" {
            omnigent = [ "databricks" "modal" ];
          };
          omnigentCli = pkgs.runCommand "omnigent-cli-0.9.0" { } ''
            mkdir -p "$out/bin"
            ln -s "${omnigentEnv}/bin/omnigent" "$out/bin/omnigent"
            ln -s "${omnigentEnv}/bin/omni" "$out/bin/omni"
            ln -s "${omnigentEnv}/bin/modal" "$out/bin/modal"
          '';
          omnigent = pkgs.buildEnv {
            name = "omnigent-0.9.0";
            paths = [
              omnigentCli
              pkgs.nodejs_22
              pkgs.tmux
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.bubblewrap ];
            meta = {
              description = "Omnigent CLI with the Databricks and Modal integrations";
              homepage = "https://omnigent.ai";
              mainProgram = "omnigent";
            };
          };
          dotfilesTools = pkgs.buildEnv {
            name = "dotfiles-tools";
            paths = [
              pkgs.uv
              pkgs.gnumake
              pkgs.perl
              pkgs.gh
              omnigent
            ];
          };
        in
        {
          inherit omnigent;
          dotfiles-tools = dotfilesTools;
          default = dotfilesTools;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [ self.packages.${system}.dotfiles-tools ];
          };
        });
    };
}
