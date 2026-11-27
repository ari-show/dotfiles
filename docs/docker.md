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
