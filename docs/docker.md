# Docker のビルドキャッシュ

macOS の Docker Desktop では、Docker CLI を Nix で管理しても、Linux VM 内の
ビルドキャッシュは Nix store や Nix の GC の対象になりません。Docker Desktop の
BuildKit GC を使って容量を管理できます。これは定期実行のジョブではなく、ビルド時に
容量や経過時間に基づいてキャッシュを整理する仕組みです。

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

Docker Desktop の **Settings → Docker Engine** で既存の JSON を確認し、他の設定を
残したまま `builder.gc` を次のように設定します。

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

これは JSON 全体の置き換え用ではなく、変更する部分の例です。Apply & Restart で
反映します。Docker Desktop の標準値は 20GB です。10GB は容量を抑えるための例で、
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
