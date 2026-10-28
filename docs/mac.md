# MacOS用セットアップ

## 前提条件
- Zshターミナルである
- 以下のコマンドが実行できる
    - `git`
    - `perl`
    - `make`

## 1. 初回設定

### 1-i. dotfilesリポジトリのクローン

```bash
$ git clone https://github.com/ShotaArima/dotfiles.git ~/dotfiles
$ cd ~/dotfiles
```

### 1-ii. セットアップを実行

```bash
$ make setup
```

> `make setup` は macOS を自動判定し、`config/mac/` → `config/` の順で設定ファイルを探してリンクします。

## 2. 更新時手順

### 2-i 変更を行う端末（普段使っている Mac）
- 変更は **`~/dotfiles/config/`（必要に応じて `mac/`）** の中で行う。
- 例）`.zshrc` を編集する：

```bash
$ vim ~/dotfiles/config/.zshrc
```

- 変更したら、リモートへ反映：

```bash
$ cd ~/dotfiles
$ git add .
$ git commit -m "Update zshrc"
$ git push
```

### 2-ii 設定を反映したい端末（別の Mac）

- リポジトリを最新化して、再適用する：

```bash
$ cd ~/dotfiles
$ git pull
$ make setup
```

- これで最新設定が適用される。

## 3. Nix 管理のツール（uv など）を更新する

`uv` / `gh` / `tmux` / `ghtkn` / `omnigent` などは `nix/flake.nix` の `dotfiles-tools` として
`nix profile`（entry 名 `nix`）に入っています。実体は読み取り専用の `/nix/store` にあるため、
`uv self update` のようなツール自身の自己更新は使えません。版はすべて Nix 側で管理します。

> `~/.local/bin` に standalone 版の `uv` を入れると Nix 版より先に見つかり二重管理になります。
> `.zshrc` では `~/.local/bin` を PATH の末尾に置いているので、standalone 版は入れないでください。

### 3-i. 更新する端末（普段使っている Mac）

```bash
$ cd ~/dotfiles
$ make nix-update   # flake.lock 更新 → build 確認 → nix profile upgrade nix
$ uv --version      # Nix 版 (~/.nix-profile/bin/uv) が新しくなっていることを確認
$ git add nix/flake.lock
$ git commit -m "chore(nix): update flake.lock"
$ git push
```

`ghtkn` の版は `nix/flake.nix` の `version` / `hash` / `vendorHash` を、
`omnigent` の版は `nix/omnigent/pyproject.toml` と `uv.lock` を手で更新してから同じ手順を行います。

### 3-ii. 反映する端末（別の Mac）

lock は 3-i で固定済みなので、他の端末では `nix flake update` を実行せず pull と入れ直しだけ行います。

```bash
$ cd ~/dotfiles
$ git pull
$ make nix-sync     # nix profile upgrade nix
```

GitHub 上の flake を直接 profile に入れている端末では `nix profile upgrade nix --refresh` を使います。

### 3-iii. 戻したいとき

```bash
$ nix profile rollback          # 1 世代前に戻す
$ nix profile wipe-history      # 問題なければ古い世代を削除
```
