#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
tmp_dir="$(cd "$tmp_dir" && pwd -P)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/dotfiles/.config/ghostty" "$tmp_dir/dotfiles/.config/nix"
cp "$repo_dir/.config/ghostty/config" "$tmp_dir/dotfiles/.config/ghostty/config"
cp "$repo_dir/.config/nix/nix.conf" "$tmp_dir/dotfiles/.config/nix/nix.conf"

for setting in unset empty relative absolute; do
  home="$tmp_dir/$setting/home"
  mkdir -p "$home"
  case "$setting" in
    unset) xdg_env=(env -u XDG_CONFIG_HOME); dest="$home/.config" ;;
    empty) xdg_env=(env XDG_CONFIG_HOME=); dest="$home/.config" ;;
    relative) xdg_env=(env XDG_CONFIG_HOME=relative); dest="$home/.config" ;;
    absolute) dest="$tmp_dir/$setting/custom config"; xdg_env=(env "XDG_CONFIG_HOME=$dest") ;;
  esac
  for app in ghostty nix; do
    "${xdg_env[@]}" HOME="$home" DOTFILES="$tmp_dir/dotfiles" perl "$repo_dir/bootstrap/$app.pm" > /dev/null
    "${xdg_env[@]}" HOME="$home" DOTFILES="$tmp_dir/dotfiles" perl "$repo_dir/bootstrap/$app.pm" > /dev/null
    case "$app" in ghostty) file=config ;; nix) file=nix.conf ;; esac
    test "$(readlink "$dest/$app/$file")" = "$tmp_dir/dotfiles/.config/$app/$file"
  done
done
