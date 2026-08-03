{
  description = "dotfiles utilities";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          dotfilesTools = pkgs.buildEnv {
            name = "dotfiles-tools";
            paths = with pkgs; [ uv gnumake perl gh ];
          };
        in
        {
          dotfiles-tools = dotfilesTools;
          default = dotfilesTools;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [ uv gnumake perl gh ];
          };
        });
    };
}
