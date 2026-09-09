#!/bin/bash
# macOS のメジャーアップグレード等で消えた Nix (multi-user install) の
# システム設定を復元し、"Nix Store" ボリュームを /nix にマウントし直す。
#
# 症状: `nix: command not found`、/nix が存在しない、
#       "Nix Store" ボリュームが /Volumes/Nix Store にマウントされている。
#
# 復元対象:
#   1. /etc/synthetic.conf                               (/nix ディレクトリの定義)
#   2. /etc/fstab                                        (/nix へのマウント行)
#   3. /Library/LaunchDaemons/org.nixos.darwin-store.plist (起動時の復号 + マウント)
#   4. /etc/zshrc                                        (nix 初期化フック)
#
# 使い方: sudo bash nix-repair.sh   (make nix-repair でも可)
# 何度実行しても安全（済んでいる手順はスキップする）。
set -euo pipefail

LABEL="${NIX_VOLUME_LABEL:-Nix Store}"
PLIST="/Library/LaunchDaemons/org.nixos.darwin-store.plist"
NIX_DAEMON_PLIST="/Library/LaunchDaemons/org.nixos.nix-daemon.plist"
APFS_UTIL="/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util"

step() { printf '\n==> %s\n' "$*"; }

if [ "$(uname)" != "Darwin" ]; then
  echo "[ERROR] macOS 専用のスクリプトです" >&2
  exit 1
fi
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] root で実行してください: sudo bash $0" >&2
  exit 1
fi

# ---------------------------------------------------------------- 0. ボリュームの検出
step "\"$LABEL\" ボリュームを検出"
volume_info="$(diskutil info "$LABEL" 2>/dev/null || true)"
if [ -z "$volume_info" ]; then
  echo "[ERROR] \"$LABEL\" ボリュームが見つからない。Nix が未インストールなら nix-install.sh を使う。" >&2
  exit 1
fi
UUID="${NIX_VOLUME_UUID:-$(printf '%s\n' "$volume_info" | awk '/Volume UUID/ {print $3}')}"
ENCRYPTED="$(printf '%s\n' "$volume_info" | awk '/FileVault:/ {print $2}')"
CURRENT_MOUNT="$(printf '%s\n' "$volume_info" | sed -n 's/^ *Mount Point: *//p')"
echo "UUID        = $UUID"
echo "Encrypted   = ${ENCRYPTED:-unknown}"
echo "Mount Point = ${CURRENT_MOUNT:-(not mounted)}"
if [ -z "$UUID" ]; then
  echo "[ERROR] Volume UUID を取得できなかった" >&2
  exit 1
fi

if [ "$ENCRYPTED" = "Yes" ]; then
  if ! security find-generic-password -s "$UUID" /Library/Keychains/System.keychain >/dev/null 2>&1; then
    echo "[WARN] System キーチェーンに復号パスワード (service=$UUID) が無い。"
    echo "       起動時の自動マウントは動かないので、手動で unlock が必要になる。"
  fi
fi

# ---------------------------------------------------------------- 1. synthetic.conf
step "/etc/synthetic.conf に nix を登録"
if grep -qE '^nix([[:space:]]|$)' /etc/synthetic.conf 2>/dev/null; then
  echo "[SKIP] 登録済み"
else
  printf 'nix\n' >> /etc/synthetic.conf
  chmod 644 /etc/synthetic.conf
  echo "[DONE] 追記した"
fi

# ---------------------------------------------------------------- 2. fstab
step "/etc/fstab に /nix のマウント行を登録"
if grep -qE '[[:space:]]/nix[[:space:]]' /etc/fstab 2>/dev/null; then
  echo "[SKIP] 登録済み"
else
  printf 'UUID=%s /nix apfs rw,noauto,nobrowse,suid,owners\n' "$UUID" >> /etc/fstab
  chmod 644 /etc/fstab
  echo "[DONE] 追記した"
fi

# ---------------------------------------------------------------- 3. darwin-store LaunchDaemon
step "$PLIST を作成（起動時に /nix へマウント）"
if [ -f "$PLIST" ]; then
  echo "[SKIP] 存在する"
else
  if [ "$ENCRYPTED" = "Yes" ]; then
    mount_cmd="/usr/bin/security find-generic-password -s \"$UUID\" -w | /usr/sbin/diskutil apfs unlockVolume \"$UUID\" -mountpoint /nix -stdinpassphrase"
  else
    mount_cmd="/usr/sbin/diskutil mount -mountPoint /nix \"$UUID\""
  fi
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>RunAtLoad</key>
  <true/>
  <key>Label</key>
  <string>org.nixos.darwin-store</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>$mount_cmd</string>
  </array>
</dict>
</plist>
EOF
  chown root:wheel "$PLIST"
  chmod 644 "$PLIST"
  plutil -lint "$PLIST"
  echo "[DONE] 作成した"
fi

# ---------------------------------------------------------------- 4. shell hook
add_hook() {
  local rc="$1"
  if grep -q 'nix-daemon.sh' "$rc" 2>/dev/null; then
    echo "[SKIP] $rc は追加済み"
    return
  fi
  cp "$rc" "$rc.before-nix-repair.$(date +%Y%m%d_%H%M%S)"
  local tmp
  tmp="$(mktemp)"
  {
    cat <<'EOF'

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix

EOF
    cat "$rc"
  } > "$tmp"
  cat "$tmp" > "$rc"
  rm -f "$tmp"
  echo "[DONE] $rc に追加した"
}
step "/etc/zshrc と /etc/bashrc に Nix 初期化フックを追加"
add_hook /etc/zshrc
add_hook /etc/bashrc

# ---------------------------------------------------------------- 5. /nix マウントポイント作成
step "/nix (synthetic ディレクトリ) を作成"
if [ -d /nix ]; then
  echo "[SKIP] 存在する"
else
  "$APFS_UTIL" -t || true
  if [ ! -d /nix ]; then
    echo "[WARN] /nix を再起動なしで作成できなかった。"
    echo "       Mac を再起動すると /nix が作られ、darwin-store daemon が自動でマウントする。"
    echo "       再起動後にもう一度このスクリプトを実行すると残りの確認が行われる。"
    exit 2
  fi
  echo "[DONE] 作成した"
fi

# ---------------------------------------------------------------- 6. /nix にマウントし直す
step "ボリュームを /nix にマウント"
if mount | grep -q ' on /nix '; then
  echo "[SKIP] マウント済み"
else
  if [ -n "$CURRENT_MOUNT" ] && [ "$CURRENT_MOUNT" != "/nix" ]; then
    diskutil unmount "$CURRENT_MOUNT" || diskutil unmount force "$CURRENT_MOUNT"
  fi
  if [ "$ENCRYPTED" = "Yes" ]; then
    # 暗号化ボリュームは unmount するとロックされるので、キーチェーンのパスワードで unlock + mount する
    security find-generic-password -s "$UUID" -w \
      | diskutil apfs unlockVolume "$UUID" -mountpoint /nix -stdinpassphrase
  else
    diskutil mount -mountPoint /nix "$UUID"
  fi
  echo "[DONE] マウントした"
fi
ls -d /nix/store /nix/var/nix/profiles/default >/dev/null

# ---------------------------------------------------------------- 7. LaunchDaemon の読み込み
step "LaunchDaemon を読み込み"
# darwin-store は次回起動時に動けばよい。今は既にマウント済みなので実行は失敗するが問題ない。
launchctl bootstrap system "$PLIST" 2>/dev/null || true
if launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
  launchctl kickstart -k system/org.nixos.nix-daemon
else
  launchctl bootstrap system "$NIX_DAEMON_PLIST"
fi
echo "[DONE] nix-daemon を再起動した"

# ---------------------------------------------------------------- 8. 確認
step "確認"
sleep 2
# sudo で呼ばれた場合は元のユーザーとして daemon 経由の動作を確認する
if [ -n "${SUDO_USER:-}" ]; then
  sudo -u "$SUDO_USER" -H /nix/var/nix/profiles/default/bin/nix --version
  sudo -u "$SUDO_USER" -H /nix/var/nix/profiles/default/bin/nix store info
else
  HOME=/var/root /nix/var/nix/profiles/default/bin/nix --version
  HOME=/var/root /nix/var/nix/profiles/default/bin/nix store info
fi
echo
echo "[OK] 修復完了。新しいターミナルを開いて 'nix --version' を確認してください。"
