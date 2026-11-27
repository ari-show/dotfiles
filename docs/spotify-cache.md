# Spotify の容量確認

macOS の LaunchAgent で毎週月曜 12:00 に Spotify のキャッシュディレクトリの
使用容量を確認し、5 GiB 以上なら通知します。スリープ中に予定時刻を迎えた場合は
復帰時に実行されます。Mac の電源が切れていた場合、その回は実行されません。
ファイルの削除や Spotify の終了は行いません。

監視対象は `~/Library/Caches/com.spotify.client` 全体です。Spotify の設定画面に
表示されるキャッシュ容量や実際に解放できる容量とは一致しない場合があります。
Spotify の保存先を変更している場合、その場所はこの監視対象に含まれません。
オフライン保存分は対象としていません。容量が大きい場合は Spotify の
「設定 → ストレージ → キャッシュを削除」から整理できます。

## 有効化

リポジトリを `~/dotfiles` に置いた macOS のログインユーザーで実行します。
他の場所に置く場合は plist の `ProgramArguments` 内のパスを修正してください。
`make setup` では自動的に有効化しません。

```bash
mkdir -p ~/Library/LaunchAgents
cp ~/dotfiles/.config/launchd/com.dotfiles.spotify-cache-monitor.plist ~/Library/LaunchAgents/
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.spotify-cache-monitor.plist
```

通知が届かない場合は、macOS の通知設定でスクリプトの通知が許可されているか確認します。
閾値は plist に `EnvironmentVariables` の `SPOTIFY_CACHE_THRESHOLD_KIB` を
正の整数で追加して変更できます（単位 KiB、既定値 5242880）。plist を変更した場合は
下記の停止を実行し、コピーと bootstrap をやり直します。

## 動作確認と停止

```bash
# 実際の通知を送らず、現在のサイズを確認
SPOTIFY_CACHE_DRY_RUN=1 ~/dotfiles/scripts/spotify-cache-monitor
# ジョブの登録状態
launchctl print "gui/$(id -u)/com.dotfiles.spotify-cache-monitor"
# 停止
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.dotfiles.spotify-cache-monitor.plist
rm ~/Library/LaunchAgents/com.dotfiles.spotify-cache-monitor.plist
```

ディレクトリが存在しない場合は何も通知しません。再有効化するときは plist を再コピーして
bootstrap してください。
