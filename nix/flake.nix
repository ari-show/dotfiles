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

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      omnigentWorkspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = ./omnigent;
      };
      omnigentOverlay = omnigentWorkspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "raycast";
          };
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              python = pkgs.python312;
            }).overrideScope
              (
                pkgs.lib.composeManyExtensions [
                  pyproject-build-systems.overlays.wheel
                  omnigentOverlay
                ]
              );
          omnigentEnv = pythonSet.mkVirtualEnv "omnigent-env" {
            omnigent = [
              "databricks"
              "modal"
            ];
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
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.bubblewrap ];
            meta = {
              description = "Omnigent CLI with the Databricks and Modal integrations";
              homepage = "https://omnigent.ai";
              mainProgram = "omnigent";
            };
          };
          ghtkn = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) rec {
            pname = "ghtkn";
            version = "0.4.3";
            src = pkgs.fetchFromGitHub {
              owner = "suzuki-shunsuke";
              repo = "ghtkn";
              rev = "v${version}";
              hash = "sha256-G4oM14ErcRp3c0V9fN1XK/kIwPFepZQdLxwDzt3+J7E=";
            };
            subPackages = [ "cmd/ghtkn" ];
            vendorHash = "sha256-AGoHsstyvCxe0i2xzwdTLvWGtl2x6z0gn6aQlbA4KBA=";
            ldflags = [
              "-s"
              "-w"
              "-X main.version=${version}"
            ];
            doCheck = false;
            meta = {
              description = "CLI to create GitHub User Access Tokens for GitHub Apps via Device Flow";
              homepage = "https://github.com/suzuki-shunsuke/ghtkn";
              mainProgram = "ghtkn";
            };
          };
          # nixpkgs の codex は Rust ソースからのビルドで、キャッシュが無いと CI で 1 時間近くかかる。
          # 公式リリースのビルド済みパッケージを固定して使う（版と hash は codex-source.json）。
          # codex は実行ファイルを実パスに解決し、bin/ の親にある codex-package.json を目印に
          # bin/codex-code-mode-host・codex-exec-server や codex-resources/（Linux の bwrap など）、
          # codex-path/rg を探す。そのためパッケージを libexec/codex にそのまま置き、bin/codex は symlink にする。
          codexSource = builtins.fromJSON (builtins.readFile ./codex-source.json);
          codexTarget =
            {
              aarch64-darwin = "aarch64-apple-darwin";
              x86_64-linux = "x86_64-unknown-linux-musl";
              aarch64-linux = "aarch64-unknown-linux-musl";
            }
            .${system};
          codex = pkgs.stdenvNoCC.mkDerivation {
            pname = "codex";
            version = codexSource.version;
            src = pkgs.fetchurl {
              url = "https://github.com/openai/codex/releases/download/rust-v${codexSource.version}/codex-package-${codexTarget}.tar.gz";
              hash = codexSource.hashes.${system};
            };
            sourceRoot = ".";
            nativeBuildInputs = [ pkgs.installShellFiles ];
            # 署名済みの公式バイナリと、digest を埋め込まれた bwrap をそのまま使う。
            dontStrip = true;
            dontPatchELF = true;
            installPhase = ''
              runHook preInstall
              mkdir -p "$out/libexec/codex" "$out/bin"
              cp -R codex-package.json bin codex-resources codex-path "$out/libexec/codex/"
              ln -s "$out/libexec/codex/bin/codex" "$out/bin/codex"
              installShellCompletion --cmd codex \
                --bash <("$out/bin/codex" completion bash) \
                --fish <("$out/bin/codex" completion fish) \
                --zsh <("$out/bin/codex" completion zsh)
              runHook postInstall
            '';
            meta = {
              description = "Lightweight coding agent that runs in your terminal";
              homepage = "https://github.com/openai/codex";
              mainProgram = "codex";
            };
          };
          # 全環境（Mac / Linux サーバー）で使う CLI。
          commonTools = [
            codex
            pkgs.uv
            pkgs.gnumake
            pkgs.perl
            pkgs.gh
            pkgs.ripgrep
            pkgs.fd
            pkgs.jq
            pkgs.asdf-vm
            pkgs.sops
            pkgs.tmux
            pkgs.tree
            pkgs.neovim
            pkgs.lazygit
            pkgs.oh-my-zsh
            pkgs.tree-sitter
            pkgs.stylua
            pkgs.shfmt
            pkgs.poppler-utils
            ghtkn
            omnigent
          ];
          # nixpkgs の更新を待たずに公式リリースを固定する。
          cmuxSource = builtins.fromJSON (builtins.readFile ./cmux-source.json);
          cmux = pkgs.cmux.overrideAttrs (old: {
            version = cmuxSource.version;
            src = pkgs.fetchurl {
              url = "https://github.com/manaflow-ai/cmux/releases/download/v${cmuxSource.version}/cmux-macos-arm64.dmg";
              hash = cmuxSource.hash;
            };
            # CLI はアプリ本体ではなく Resources/bin に同梱される。
            postInstall = (old.postInstall or "") + ''
              rm "$out/bin/cmux"
              makeBinaryWrapper "$out/Applications/cmux.app/Contents/Resources/bin/cmux" "$out/bin/cmux"
            '';
          });
          # Raycast も nixpkgs の更新を待たずに公式の最新版を固定する。
          raycastSource = builtins.fromJSON (builtins.readFile ./raycast-source.json);
          raycast = pkgs.raycast.overrideAttrs {
            version = raycastSource.version;
            src = pkgs.fetchurl {
              name = "Raycast.dmg";
              inherit (raycastSource) url hash;
            };
          };
          # Karabiner-Elements はデーモンとドライバを root で /Applications・/Library に置く必要があり、
          # nix profile からは動かせない。公式の署名済みインストーラー（.pkg）を版と hash で固定して
          # share/karabiner-elements に置き、`make karabiner` が `sudo installer` で入れる。
          karabinerSource = builtins.fromJSON (builtins.readFile ./karabiner-source.json);
          karabiner-elements = pkgs.stdenvNoCC.mkDerivation {
            pname = "karabiner-elements";
            version = karabinerSource.version;
            src = pkgs.fetchurl {
              url = "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v${karabinerSource.version}/Karabiner-Elements-${karabinerSource.version}.dmg";
              inherit (karabinerSource) hash;
            };
            nativeBuildInputs = [ pkgs.undmg ];
            sourceRoot = ".";
            # 署名を壊さないよう .pkg には手を加えない。
            dontFixup = true;
            installPhase = ''
              runHook preInstall
              dir="$out/share/karabiner-elements"
              mkdir -p "$dir"
              cp Karabiner-Elements.pkg "$dir/"
              echo "$version" > "$dir/version"
              runHook postInstall
            '';
            meta = {
              description = "Official signed installer of Karabiner-Elements (installed by make karabiner)";
              homepage = "https://karabiner-elements.pqrs.org/";
              license = pkgs.lib.licenses.unlicense;
              platforms = [ "aarch64-darwin" ];
            };
          };
          # GUI アプリは Apple Silicon Mac 専用。Linux の profile には含めない。
          darwinTools = pkgs.lib.optionals (system == "aarch64-darwin") [
            cmux
            pkgs.ghostty-bin
            pkgs.hidden-bar
            karabiner-elements
            raycast
            pkgs.sketchybar
          ];
          # Linux（サーバー）でのみ使う CLI。
          linuxTools = [ ];
          dotfilesTools = pkgs.buildEnv {
            name = "dotfiles-tools";
            paths =
              commonTools
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin darwinTools
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux linuxTools;
          };
        in
        {
          inherit omnigent ghtkn codex;
          dotfiles-tools = dotfilesTools;
          default = dotfilesTools;
        }
        // pkgs.lib.optionalAttrs (system == "aarch64-darwin") { inherit cmux karabiner-elements raycast; }
      );

      # `make fmt` / `make fmt-check` が使う整形ツール。checks.formatting と同じ版を使う。
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # `make check`（= `nix flake check ./nix`）と CI で実行する検査。
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # nix/ 以下の *.nix が nixfmt で整形済みか。
          formatting = pkgs.runCommand "check-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            cd ${self}
            find . -name '*.nix' -print0 | xargs -0 nixfmt --check
            touch "$out"
          '';
          # profile に入れるパッケージがビルドできるか。
          dotfiles-tools = self.packages.${system}.dotfiles-tools;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [ self.packages.${system}.dotfiles-tools ];
          };
        }
      );
    };
}
