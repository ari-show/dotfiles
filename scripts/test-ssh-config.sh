#!/usr/bin/env bash
# bootstrap/ssh.pm が ~/.ssh/config を「無ければ追加」で扱い、
# 何度実行しても同じ結果になることを一時的な HOME で確かめる。
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
tmp_dir="$(cd "$tmp_dir" && pwd -P)"
trap 'rm -rf "$tmp_dir"' EXIT

include='Include ~/.ssh/config.d/*.conf'
agent='IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'

run() { HOME="$1" DOTFILES="$repo_dir" perl "$repo_dir/bootstrap/ssh.pm" > /dev/null; }
count() { grep -c -F -- "$2" "$1" || true; }
backups() { find "$1/.ssh" -name 'config.before-dotfiles.*' | wc -l | tr -d ' '; }

# 1. ~/.ssh が無い: config を新しく作り、2 回目は何も変えない。
home="$tmp_dir/fresh"; mkdir -p "$home"
run "$home"; run "$home"
test "$(cat "$home/.ssh/config")" = "$include"
test "$(readlink "$home/.ssh/config.d/1password.conf")" = "$repo_dir/.config/ssh/1password.conf"
test "$(backups "$home")" = 0

# 2. 既存の config: 先頭に 1 行だけ足し、元の内容と権限は保つ。
home="$tmp_dir/existing"; mkdir -p "$home/.ssh"
printf 'Host side\n  HostName side.example\n  User me\n' > "$home/.ssh/config"
chmod 600 "$home/.ssh/config"
run "$home"
test "$(head -n 1 "$home/.ssh/config")" = "$include"
test "$(backups "$home")" = 1
run "$home"; run "$home"
test "$(count "$home/.ssh/config" "$include")" = 1
test "$(count "$home/.ssh/config" 'HostName side.example')" = 1
test "$(backups "$home")" = 1
test "$(perl -e 'printf "%o", (stat shift)[2] & 07777' "$home/.ssh/config")" = 600

# 3. 直接書かれた 1Password の Host * ブロック (重複あり) は取り除く。
#    ほかの設定を含む Host * ブロックは残す。
home="$tmp_dir/legacy"; mkdir -p "$home/.ssh"
{
  printf 'Host side\n  HostName side.example\n\n'
  printf 'Host *\n\t%s\n\n' "$agent"
  printf 'Host *\n\t%s\n\n' "$agent"
  printf 'Host *\n  ServerAliveInterval 60\n  %s\n' "$agent"
} > "$home/.ssh/config"
run "$home"; run "$home"
test "$(count "$home/.ssh/config" "$include")" = 1
test "$(count "$home/.ssh/config" "$agent")" = 1
test "$(count "$home/.ssh/config" 'ServerAliveInterval 60')" = 1
test "$(count "$home/.ssh/config" 'HostName side.example')" = 1
test "$(backups "$home")" = 1

# 4. Include が既にある: 何も変えず、バックアップも作らない。
home="$tmp_dir/included"; mkdir -p "$home/.ssh"
printf '%s\n\nHost side\n  User me\n' "$include" > "$home/.ssh/config"
before="$(cat "$home/.ssh/config")"
run "$home"
test "$(cat "$home/.ssh/config")" = "$before"
test "$(backups "$home")" = 0

# 5. config がシンボリックリンク: リンク先は書き換えない。
home="$tmp_dir/symlink"; mkdir -p "$home/.ssh"
printf 'Host side\n  User me\n' > "$home/real-config"
ln -s "$home/real-config" "$home/.ssh/config"
run "$home"
test -L "$home/.ssh/config"
test "$(count "$home/real-config" "$include")" = 0

echo "test-ssh-config: ok"
