# Ghostty のセットアップ

## インストール

Apple Silicon macOS では `dotfiles-tools` に Ghostty が含まれる。
まず [Nix profile のセットアップ](../../../README.md#3-dotfiles-用ツールを-nix-profile-に追加する)を行い、以下でアプリを起動する。

```bash
open ~/.nix-profile/Applications/Ghostty.app
```

Raycast から起動するには、Raycast の Settings → Script Commands → Add Script Directory で
`~/dotfiles/scripts/raycast` を追加する。登録後、Raycast で
「Open Ghostty」を検索して実行できる。同じディレクトリを cmux 用に登録済みなら、
再登録は不要。

その他の環境でのインストール方法は [公式ドキュメント](https://ghostty.org/docs/install) を参照。

## 設定ファイルのリンク

`make` で `~/.config/ghostty/config` へシンボリックリンクを貼る。

```bash
cd ~/dotfiles
make ghostty
```

- リンク元はリポジトリ内の `.config/ghostty/config`
- Ghostty がテーマ等を `~/.config/ghostty` 配下に書き込む可能性があるため、ディレクトリごとではなく `config` ファイルだけをリンクする（`~/.config/ghostty` 自体は実体のまま残る）
- リンク先に実体ファイルが存在する場合は `back-up/<日時>/` へ退避してからリンクを貼る
- すでにリンク済みの場合はスキップされる（何度実行しても安全）

手動でリンクを貼る場合:

```bash
mkdir -p ~/.config/ghostty
ln -s ~/dotfiles/.config/ghostty/config \
  ~/.config/ghostty/config
```

## 設定の反映

設定ファイルを編集した後は、Ghostty 上で `Cmd + Shift + ,`（Reload Configuration）で再読み込みできる。

## 設定内容の概要

| 項目 | 内容 |
|---|---|
| テーマ | Catppuccin Frappe |
| フォント | JetBrains Mono / 16pt |
| ウィンドウ | 余白 10px、透明度 0.40 + 背景ぼかし |
| 操作 | Option を Alt として扱う、選択時自動コピー、閉じる際の確認なし |
