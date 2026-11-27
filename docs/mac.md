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
$ make nix-sync   # Nix のツールを入れ直す
```

- これで最新設定が適用される。

## 3. Nix 管理のツール（uv など）を更新する

### cmux（Apple Silicon Mac）

cmux は `dotfiles-tools` に含まれます。Nix プロファイルの更新後に次を実行すると、
設定と `~/Applications/cmux.app` がリンクされます。

```bash
make nix-sync
make cmux
```

既存の同名ファイルは `back-up/` に退避します。cmux は Ghostty の表示設定も読みます。
アプリ全体の設定は `.config/cmux/cmux.json`、このリポジトリ専用のコマンドは
`.cmux/cmux.json` で管理します。Raycast では Script Commands のディレクトリに
`~/dotfiles/scripts/raycast` を登録すると「Open cmux」を使えます。

#### 既存の Git worktree を別ペインで開く

Git リポジトリ内の cmux ターミナルで、コマンドパレットから
「Open Git worktree in split」を選び、一覧の番号を入力します。
選択した worktree を右側の新しいペインで開きます。空入力でキャンセルできます。
上下左右を指定したい場合は、次のように直接実行します。

```bash
bash "${DOTFILES:-$HOME/dotfiles}/scripts/cmux-worktree" down
```

同じ worktree を複数ペインから開くこともできます。その場合はファイルとブランチを共有します。
別々の変更を並行して隔離するには、あらかじめ別ブランチの worktree を作成してください。
この操作では worktree やブランチの作成・削除は行いません。通常のペイン分割も変更しません。
設定の反映には `make cmux` の後に `cmux reload-config` を実行してください。

cmux の版と SHA-256 は `nix/cmux-source.json` で固定しています。
`Update pinned Nix packages` workflow が毎週月曜に公式の最新安定版を確認し、Apple Silicon macOS で
ビルドと CLI を検証してから更新 PR を作ります。Actions に PR 作成が許可されている必要があります。
`GITHUB_TOKEN` による PR では通常の push CI が自動実行されないため、必要に応じて手動実行します。

Raycast も `dotfiles-tools` に含まれます。Nix プロファイルの更新後に `make raycast` を実行すると、
`~/Applications/Raycast.app` がリンクされます（`make setup` にも含まれます）。
既存の同名ファイルは `back-up/<日時>/raycast` に退避します。

```bash
make nix-sync
make raycast
```

Raycast も cmux と同様に `nix/raycast-source.json` で版・DMG の URL・SHA-256 を固定しています。
同じ workflow が Raycast 公式の最新版ダウンロード先を確認し、Apple Silicon macOS で
ビルド・版番号・コード署名と公証を検証してから更新 PR を作ります。

### Karabiner-Elements（Apple Silicon Mac）

Karabiner-Elements は root 権限のデーモンとドライバを `/Applications`・`/Library` に置く必要があり、
`nix profile` から直接は動かせません。そのため公式の署名済みインストーラー（`.pkg`）を
`nix/karabiner-source.json` で版と SHA-256 を固定して `dotfiles-tools` に含め、
`make karabiner` が次の処理を行います（`make setup` にも含まれます）。

- `~/.config/karabiner` をディレクトリごと `.config/karabiner` にリンクする（既存のものは `back-up/<日時>/karabiner` に退避）
- 入っている版が固定版より古い、または未インストールなら、pkg の署名（Team ID `G43BCU2T37`）と公証を確認してから
  `sudo installer` で入れる。同じ版なら何もせず、新しい版が入っている場合はダウングレードしない

```bash
make nix-sync
make karabiner
```

初回インストール時は、Karabiner-Elements の案内に従ってシステム設定でドライバと入力監視を許可します。
同じ workflow が公式の最新安定版を確認し、Apple Silicon macOS でビルドと pkg の署名・公証を検証してから更新 PR を作ります。

#### 設定の変更

設定は `.config/karabiner/karabiner.json` で管理します。GUI で変更してもリンク先のこのリポジトリに
直接書き込まれるので、GUI で操作したらそのつどブランチを切って差分を PR にします。
`.config/karabiner/assets/complex_modifications/` はインポート用のルール定義、
`automatic_backups/` は Karabiner が自動で作るバックアップで、Git の管理対象外です。

ghtkn v0.4.0 以降は `ghtkn get` から device flow が自動起動しないため、
cmux 向けの gh ラッパーは不要です。認証が必要な場合は手動で `ghtkn auth` を実行します。

`uv` / `gh` / `tmux` / `ghtkn` / `omnigent` などは `nix/flake.nix` の `dotfiles-tools` として
`nix profile` に入っています（entry 名は端末により `nix` や `nix-1` などで、`make nix-update` / `make nix-sync` が自動で探します）。実体は読み取り専用の `/nix/store` にあるため、
`uv self update` のようなツール自身の自己更新は使えません。版はすべて Nix 側で管理します。

> `~/.local/bin` に standalone 版の `uv` を入れると Nix 版より先に見つかり二重管理になります。
> `.zshrc` では `~/.local/bin` を PATH の末尾に置いているので、standalone 版は入れないでください。

### 3-i. 更新する端末（普段使っている Mac）

```bash
$ cd ~/dotfiles
$ make nix-update   # flake.lock 更新 → build 確認 → dotfiles-tools の entry を upgrade
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
$ make nix-sync     # dotfiles-tools の entry を upgrade
```

GitHub 上の flake を直接 profile に入れている端末では `nix profile upgrade <entry 名> --refresh` を使います
（entry 名は `perl scripts/nix-profile-entry` で確認できます）。

### 3-iii. 戻したいとき

```bash
$ make rollback                 # nix profile rollback（1 世代前に戻す）
$ nix profile wipe-history      # 問題なければ古い世代を削除
```

### 3-iv. 更新が必要か調べる / 変更を確認する

```bash
$ make outdated     # flake inputs の経過日数と、固定パッケージ（ghtkn など）の最新リリースを表示
$ make fmt          # nix/**/*.nix を nixfmt で整形
$ make check        # CI と同じ検査（Perl 構文 / nixfmt / 全 system の評価 / dotfiles-tools のビルド）
```

`nix/` を変更したら push 前に `make check` を通してください。
GitHub Actions（`.github/workflows/check.yml`）も毎 push で `make check` を実行します。
