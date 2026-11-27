# Homebrew の管理

`Brewfile` は 2026-11-28 時点の直接インストールされた formula と cask を
暫定的に記録したものです。依存関係は Homebrew が管理します。この一覧は
すべてが今も必要であることを意味せず、別の Mac に適用する前に内容を確認します。
macOS の CLI は原則 Nix の `dotfiles-tools`、必要な GUI アプリは Homebrew で
管理します。用途を確認してから不要な項目を Brewfile と環境の両方から整理します。

## 棚卸しと重複の確認

```bash
brew list --installed-on-request  # 直接インストールした formula
brew list --cask
brew leaves                     # 他の formula に必要とされていない formula
brew bundle check --file=./Brewfile
```

`brew leaves` は直接インストールした一覧とは一致せず、依存として必要な
直接インストール済みパッケージを含まないことがあります。`brew list --versions`
には依存ライブラリも含まれるため、一覧だけで不要とは判断しません。

この棚卸しでは `fd`、`tree`、`poppler`、`make` が Nix と重複しています。
`make` は macOS にもあります。実際に使われるコマンドは PATH で変わるため、
例えば zsh で `whence -a fd tree pdftotext make` と各コマンドのバージョンを
確認し、用途に必要な動作を Nix 版で確かめてから移行してください。
Brewfile の変更は専用ブランチで検証し PR を作成します。PR 前に常用環境へ
反映しないでください（明示的に先行適用を依頼された場合を除く）。

## 容量と削除候補の確認

```bash
brew cleanup --dry-run
brew autoremove --dry-run
brew bundle cleanup --file=./Brewfile
```

`brew cleanup` は古いバージョンやキャッシュを整理します。`brew autoremove` は
不要になった依存関係を対象とします。最後のコマンドは Brewfile に記載されて
いないインストール済みパッケージを表示します。空や不完全な Brewfile では
必要なものも対象になるため、一覧と依存関係を確認せずに `--force` を付けて
実行しないでください。削除前に、利用状況と代替コマンドを確認します。

2026-11-28 の確認では Homebrew が `libtiff` と `webp` の依存関係情報に
循環の警告を出しました。警告が続く場合は状態を調べてから対処してください。
警告に表示された強制アンインストールを無確認で実行しないでください。
