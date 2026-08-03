# WezTerm のセットアップ

`make` でリンクする場合:

```bash
cd ~/dotfiles
make wezterm
```

手動でシンボリックリンクを貼る場合:

```bash
mkdir -p ~/.config/wezterm
ln -s ~/dotfiles/.config/wezterm/wezterm.lua \
  ~/.config/wezterm/wezterm.lua
```

設定ファイルのモジュール構成や開発時の反映方法は [.config/wezterm/README.md](../../../.config/wezterm/README.md) を参照。
