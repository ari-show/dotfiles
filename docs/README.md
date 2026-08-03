# ドキュメント一覧

dotfiles リポジトリの各種ドキュメントのインデックス。

## ディレクトリ構成

```
docs/
├── README.md                     # このファイル（ドキュメントの入り口）
├── mac.md                        # macOS 向けセットアップ・更新手順
├── ghostty/
│   └── installing/README.md      # Ghostty のインストールと設定
├── wezterm/
│   └── installing/README.md      # WezTerm 設定のシンボリックリンク手順
└── herdr/
    └── agent-orchestration.md    # herdr で AI エージェントを動かす方法
```

## OS セットアップ

| ドキュメント | 内容 |
|---|---|
| [macOS セットアップ](./mac.md) | クローンから `make setup`、複数端末間での更新手順、Nix での uv 導入 |

## ターミナル

| ドキュメント | 内容 |
|---|---|
| [Ghostty](./ghostty/installing/README.md) | Homebrew でのインストール、`make ghostty` での設定リンク、設定内容の概要 |
| [WezTerm（インストール）](./wezterm/installing/README.md) | 手動でシンボリックリンクを貼る手順 |
| [WezTerm（設定の構成）](../.config/wezterm/README.md) | 設定ファイルのモジュール構成、`make wezterm` でのリンク、開発時の反映方法 |

## ツール

| ドキュメント | 内容 |
|---|---|
| [herdr エージェントオーケストレーション](./herdr/agent-orchestration.md) | herdr CLI で claude 等の AI エージェントを起動・タスク投入・完了検知する方法 |

## 関連

- リポジトリ全体のセットアップ手順は [トップの README](../README.md) を参照
