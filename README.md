# dotfiles

macOS / Linux 向けの個人設定ファイル（dotfiles）を管理するリポジトリ。
Nix + make + perl でセットアップを自動化している。

## 目次

- [構成](#構成)
- [セットアップ方法](#セットアップ方法)
- [セットアップ方式の使い分け](#セットアップ方式の使い分け)
- [補足: dotfiles-tools の取得方法について](#補足-dotfiles-tools-の取得方法について)
- [ドキュメント](#ドキュメント)

## 構成

```
dotfiles/
├── bootstrap/      # セットアップ用の perl スクリプト
├── config/         # OS ごとの設定ファイル（mac / linux）
├── .config/        # ~/.config 配下にリンクする設定（wezterm / ghostty / herdr / nix）
├── docs/           # 各種ドキュメント（docs/README.md が入り口）
├── nix/            # flake.nix（dotfiles-tools の定義）
├── makefile        # セットアップ用ターゲット（make help で一覧）
└── nix-install.sh  # Nix のインストールスクリプト
```

## セットアップ方法

### 0) リポジトリのクローン

SSH 鍵を GitHub に登録済みの場合:

```bash
git clone git@github.com:ShotaArima/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

SSH 鍵を未設定の場合は HTTPS でも clone できます。

```bash
git clone https://github.com/ShotaArima/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

---

### 1) Nix の確認

以下のコマンドが実行できれば、Nix はすでに利用可能です。

```bash
command -v nix
nix --version
```

表示される場合は、`2) Flakes の有効化` に進んでください。

---

### 1-1) Nix のインストール
- このShell Scriptを実行し、Nixをインストールしてください

```bash
bash nix-install.sh
```

- インストール後、新しいターミナルを開き直してください。

```bash
nix --version
```

> 補足: `nix: command not found` になる場合は、ターミナルを開き直すか、shell の初期化ファイルで PATH を上書きしていないか確認してください。

---

### 2) Flakes の有効化

このリポジトリでは `flake.nix` を使うため、Nix の experimental features を有効にします。

- ユーザー単位で設定する場合:

```bash
mkdir -p /etc/nix
${EDITOR:-vi} /etc/nix/nix.conf
```

- 以下を追記してください。

```conf
experimental-features = nix-command flakes
```

- 確認します。

```bash
nix flake --help
nix develop --help
```

> 補足: ユーザー単位で設定したい場合は `~/.config/nix` に同じ設定を書きます。
```bash
~/.config/nix
${EDITOR:-vi} ~/.config/nix/nix.conf
```

---
### 3) dotfiles 用ツールを Nix profile に追加する

このリポジトリでは、`make` / `perl` / `uv` / `gh` などのセットアップに必要なツールを `dotfiles-tools` として定義しています。

`dotfiles-tools` を Nix profile に追加すると、通常の shell からこれらのコマンドを使えるようになります。

```bash
cd ~/dotfiles
git pull
```

既存の `dotfiles-tools` が profile に入っている場合、同じものを何度も `nix profile add` すると重複することがあります。  
そのため、先に既存の `dotfiles-tools` を削除してから追加します。

```bash
nix profile list
```

`packages.x86_64-linux.dotfiles-tools` や `dotfiles-tools` が表示されている場合は、`Name` を指定して削除します。

例:

```bash
nix profile remove nix-1
```

複数ある場合は、まとめて削除します。

```bash
nix profile remove nix-1 nix-2 nix-3
```

その後、`dotfiles-tools` を追加します。

```bash
nix profile add ./nix#dotfiles-tools
```

追加後、通常の shell で以下が使えることを確認します。

```bash
hash -r
uv --version
make --version
perl --version
gh --version
```

これで、毎回 `nix develop` に入らなくても、通常の shell から `uv` / `make` / `perl` / `gh` が使えるようになります。

---

### 4) セットアップの実行

`dotfiles-tools` を Nix profile に追加した後は、通常の shell で `make setup` を実行できます。

```bash
cd ~/dotfiles
make setup
```

`make setup` は Nix のユーザー設定もリンクします。

```text
~/.config/nix/nix.conf -> ~/dotfiles/.config/nix/nix.conf
```

Nix の設定だけを適用する場合は、次を実行します。

```bash
make nix
```

---

### 5) GitHub 上の flake から直接 profile に追加する場合

ローカルの `~/dotfiles/nix/flake.nix` ではなく、GitHub 上の flake を直接使う場合は以下を実行します。

```bash
nix profile add "github:ShotaArima/dotfiles?dir=nix#dotfiles-tools" --no-write-lock-file --refresh
```

ただし、すでに `dotfiles-tools` が profile に入っている場合は、先に削除してください。

```bash
nix profile list
nix profile remove <Name>
```

例:

```bash
nix profile remove nix-1
nix profile add "github:ShotaArima/dotfiles?dir=nix#dotfiles-tools" --no-write-lock-file --refresh
```

> 補足: `nix profile add` は「既存の package を自動で置き換える」コマンドではありません。
> 同じ `dotfiles-tools` を何度も追加すると profile に重複することがあるため、更新したい場合は既存の entry を削除してから追加してください。

## セットアップ方式の使い分け

| 方法 | 用途 |
|---|---|
| `nix develop ./nix` | 一時的に dotfiles 用の開発環境へ入る |
| `nix develop ./nix -c make setup` | 開発シェルに入らずセットアップだけ実行する |
| `nix profile install ...#dotfiles-tools` | `make` や `perl` を普段の profile に入れて使う |
| ホストの `make` / `perl` を使う | Nix を使わず従来通り実行する |

## 補足: dotfiles-tools の取得方法について

`nix profile add "github:ShotaArima/dotfiles?dir=nix#dotfiles-tools"` は、GitHub Actions でビルド済みの成果物を直接取得するコマンドではありません。

このコマンドは GitHub 上の `nix/flake.nix` を取得し、そこに定義された `dotfiles-tools` を手元の Nix で評価して profile に追加します。

`dotfiles-tools` に含まれる `uv` / `gnumake` / `perl` などは、利用可能であれば Nix の binary cache から取得されます。取得できない場合はローカルでビルドされます。

GitHub Actions でビルドした成果物を配布したい場合は、別途 binary cache や artifact を用意し、`nix copy` などで closure を取り込む構成にします。

## ドキュメント

各ツール・OS ごとの詳細な手順は [docs/README.md](./docs/README.md) にまとめています。

- [macOS セットアップ](./docs/mac.md) — クローンから `make setup`、複数端末間での更新手順
- [Ghostty](./docs/ghostty/installing/README.md) — インストールと設定リンク
- [WezTerm](./.config/wezterm/README.md) — 設定の構成とリンク手順
- [herdr エージェントオーケストレーション](./docs/herdr/agent-orchestration.md) — AI エージェントの自動運用
