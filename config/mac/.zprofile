# ~/.zprofile

# --- 1) システム標準 PATH を確保（既存 PATH を保持）
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"

# --- 2) Homebrew（Apple Silicon）
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3) Nix
if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # nix-daemon.sh は __ETC_PROFILE_NIX_SOURCED があると PATH を確かめずに抜ける。
  # シェルから open された GUI アプリ (Raycast など) 配下では、この変数だけが継承されて
  # PATH は既定値に戻るので、PATH に Nix が無ければ外して読み直させる。
  case ":$PATH:" in
    *:/nix/var/nix/profiles/default/bin:*) ;;
    *) unset __ETC_PROFILE_NIX_SOURCED ;;
  esac
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# --- 4) MATLAB 追加
if [ -d "/Applications/MATLAB_R2025b.app/bin" ]; then
  export PATH="$PATH:/Applications/MATLAB_R2025b.app/bin"
fi
