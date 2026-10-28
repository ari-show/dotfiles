# ~/.zprofile

# --- 1) システム標準 PATH を確保（既存 PATH を保持）
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"

# --- 2) Homebrew（Apple Silicon）
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3) Nix
if [ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# --- 4) MATLAB 追加
if [ -d "/Applications/MATLAB_R2025b.app/bin" ]; then
  export PATH="$PATH:/Applications/MATLAB_R2025b.app/bin"
fi

# Added by Obsidian
export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
