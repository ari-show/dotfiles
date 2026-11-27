# Docker のビルドキャッシュ

macOS の Docker Desktop では、Docker CLI を Nix で管理しても、Linux VM 内の
ビルドキャッシュは Nix store や Nix の GC の対象になりません。Docker Desktop の
BuildKit GC を使って容量を管理できます。これは定期実行のジョブではなく、ビルド時に
容量や経過時間に基づいてキャッシュを整理する仕組みです。

## インストールと設定の反映

Apple Silicon Mac 向けに、公式 DMG の版と SHA-256 を `nix/docker-desktop-source.json` に
固定し、`dotfiles-tools` に含めています。マージ後に `make nix-sync` で取得し、Docker
Desktop を終了して `make docker-install` を実行します。初回インストールには sudo が必要です。
既存の同じ版はそのまま使い、別の版が入っている場合は自動で置き換えません。更新時は
固定版と公式リリースノートを確認し、公式インストーラーで手動更新してください。
DMG は Docker の配布期限により後日取得できなくなる場合があるため、固定版は更新が必要です。
Docker Desktop 自身の更新機能を使った場合も、固定版との差を確認してください。
4.100.0 / 4.100.1 には、更新時にイメージストアの切り替えで既存のイメージや
コンテナが見えなくなる既知の問題があります。対処方法は
[公式リリースノート](https://docs.docker.com/desktop/release-notes/#41001) を確認してください。

Engine 設定は `config/mac/docker-engine.json` で管理します。Docker Desktop を終了して
`make docker-config` を実行すると、管理対象のキーだけを `~/.docker/daemon.json` に
マージし、既存ファイルを同じディレクトリにバックアップします。認証情報、context、
Desktop のその他の設定は管理しません。再起動すると設定が反映されます。GUI で管理対象の
設定を変更した場合、次回の `make docker-config` でリポジトリの値に戻ります。
どちらのターゲットも `make setup` からは自動実行しません。

## 使用状況を確認

Docker Desktop を起動してから実行します。

```bash
docker context show
docker system df -v
docker buildx ls
docker buildx du
```

`docker system df -v` はイメージやボリュームも含む使用状況を示します。
`docker buildx du` は選択中の builder のキャッシュを表示します。複数の builder を
使う場合は `docker buildx du --builder <名前>` でそれぞれ確認します。

## Docker Desktop の自動 GC を調整

リポジトリでは `builder.gc` を次のように設定しています。

```json
{
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "10GB"
    }
  }
}
```

これは JSON 全体の置き換え用ではなく、管理する部分です。Docker Desktop の標準値は 20GB です。10GB は容量を抑えるための設定で、
再ビルドが遅くなる場合は増やせます。GC の目安であり常時の厳密な上限ではありません。
この設定は `docker` driver の builder に適用され、`docker-container` 等の独立した
builder には適用されません。そちらは builder ごとの `buildkitd.toml` で設定します。

今すぐ選択中の builder の不要なキャッシュを 10GB 以下に減らしたい場合は、対象を
`docker buildx ls` で確認したうえで次を実行します。

```bash
docker buildx prune --max-used-space 10GB
```

確認画面が表示されます。キャッシュの削除後、次回のビルドは遅くなる場合があります。
このコマンドは選択中の builder のみを対象にします。イメージ・コンテナ・ボリュームの
整理には `docker system prune` など別の操作が必要です。

参考: [Docker の Build GC](https://docs.docker.com/build/cache/garbage-collection/)、
[buildx prune](https://docs.docker.com/reference/cli/docker/buildx/prune/)

## その他の設定候補

### コンテナログのローテーション

ビルドキャッシュとは別に、コンテナの標準出力ログもディスクを消費します。
現在のデフォルトは Docker Desktop の起動後に次で確認できます。

```bash
docker info --format '{{.LoggingDriver}}'
docker inspect -f '{{json .HostConfig.LogConfig}}' <コンテナ名>
```

Docker Engine の `json-file` でローテーションが設定されていない場合は、
次のように 1 コンテナあたり 10MB × 3 ファイルを目安に設定できます。

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

`log-opts` の値は文字列で指定します。再起動後に**新規作成するコンテナ**に適用され、
既存のコンテナは再作成するまで変更されません。古いログは削除されるため、長期保存が
必要な場合は別途保存先を用意してください。コンテナ単位で指定した設定はそちらが優先されます。
`local` ドライバーもローテーションを備えていますが、ログ形式や既存設定への影響を確認して
選んでください。この例は現在の管理設定には含めていません。

### Docker Desktop のリソース

- **Resource Saver**: コンテナを使わない間 VM を停止して CPU・メモリの消費を抑えます。
  デフォルトで有効ですが、常時稼働するコンテナがある場合は休止しません。再開時は数秒かかります。
- **Disk usage limit**: VM 全体のディスク上限です。キャッシュだけでなくイメージや
  ボリュームも含むため、小さくしすぎるとビルドや書き込みに失敗します。
- **メモリ・CPU**: Mac の使用状況に合わせて Docker Desktop の Settings → Resources で
  調整します。複数コンテナや重いビルドが遅い場合は増やします。

これらの Desktop 設定は Engine の `daemon.json` とは別で、このリポジトリではまだ自動反映しません。
参考: [ログ設定](https://docs.docker.com/engine/logging/configure/)、
[Resource Saver](https://docs.docker.com/desktop/use-desktop/resource-saver/)、
[Desktop の設定](https://docs.docker.com/desktop/settings-and-maintenance/settings/)
