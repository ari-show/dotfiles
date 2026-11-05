<!--
Dependabot アラートを解消する依存更新 PR 用のテンプレート。
使い方: gh pr create --template dependabot-alert.md
  （Web では PR 作成 URL に ?template=dependabot-alert.md を付ける）
-->

## 概要
`nix/omnigent/uv.lock` の推移的依存を更新し、Dependabot アラートを解消します。`omnigent` 本体のバージョンは変えていません。

## 変更されるパッケージ
<!-- 一緒に上がったパッケージも含めて全部書く -->
- `<package>`: <old> → <new>

## 補足
<!-- 他のパッケージも一緒に上がった理由（バージョン制約など）。なければこの節ごと消す -->

## 解消するアラート
<!-- #N と書くと PR / Issue 番号へのリンクになってしまうので、アラートの URL を貼る -->
- https://github.com/ari-show/dotfiles/security/dependabot/<number>

## 確認
- [ ] CI（`make check`）が通る
