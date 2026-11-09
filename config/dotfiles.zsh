# シェル設定の構文を確認してから、現在のシェルに読み込む。
rz() {
    zsh -n "$HOME/.zshrc" && source "$HOME/.zshrc"
}

rzp() {
    zsh -n "$HOME/.zprofile" && source "$HOME/.zprofile"
}

rzz() {
    rzp && rz
}

# リンク前に移行先の構文を確認し、成功した場合だけ現在のシェルに反映する。
dotlink() {
    local dotfiles_dir="${DOTFILES:-$HOME/dotfiles}" os config_dir rc profile
    case "$OSTYPE" in
        darwin*) os=mac ;;
        linux*) os=linux ;;
        *) print -u2 "Unsupported OS: $OSTYPE"; return 1 ;;
    esac
    config_dir="$dotfiles_dir/config"
    rc="$config_dir/$os/.zshrc"
    profile="$config_dir/$os/.zprofile"
    [[ -f "$rc" ]] || rc="$config_dir/.zshrc"
    [[ -f "$profile" ]] || profile="$config_dir/.zprofile"
    zsh -n "$config_dir/dotfiles.zsh" && zsh -n "$rc" && zsh -n "$profile" || return
    command make -C "$dotfiles_dir" os || return
    rzz
}
