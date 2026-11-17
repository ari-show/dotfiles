#!/bin/bash
# Nix をインストールする。すでに入っている場合は何もしない。
#
# `command -v nix` だけで判定すると、Nix は入っているのに PATH から抜けている
# シェルでインストーラが走り、既存の "Nix Store" ボリュームを消しにいく。
# (例: __ETC_PROFILE_NIX_SOURCED だけを継承した GUI アプリ配下のシェル)
# そのため PATH に依存しない固定パスとボリュームの有無も確認する。

NIX_BIN=/nix/var/nix/profiles/default/bin/nix
NIX_VOLUME_LABEL="${NIX_VOLUME_LABEL:-Nix Store}"

# Nix が入っていれば 0 を返す。壊れた状態を見つけたら案内を出して終了する。
nix_installed() {
    if command -v nix >/dev/null 2>&1; then
        echo "nix is already installed."
        return 0
    fi
    if [ -x "$NIX_BIN" ]; then
        echo "nix is already installed ($NIX_BIN), but it is not on PATH."
        echo "Open a new terminal, or run 'make nix-doctor' to see how to fix this shell."
        return 0
    fi
    if [ "$(uname)" == 'Darwin' ] && diskutil info "$NIX_VOLUME_LABEL" >/dev/null 2>&1; then
        echo "[ERROR] \"$NIX_VOLUME_LABEL\" ボリュームはあるが、$NIX_BIN が見つからない。" >&2
        echo "        インストーラを実行すると既存のボリュームを削除するため中止した。" >&2
        echo "        macOS アップグレード後なら 'make nix-repair' を実行する。" >&2
        exit 1
    fi
    return 1
}

if [ "$(uname)" == 'Darwin' ]; then
    echo 'Mac'
    if ! nix_installed; then
        sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
    fi
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
    echo 'Linux'
    if ! nix_installed; then
        sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
    fi
else
    echo "Your platform ($(uname -a)) is not supported."
    exit 1
fi
