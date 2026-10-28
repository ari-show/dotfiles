# aliasの設定

# ========= Linuxエイリアス設定 ==========
# ls系
alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -A'

# git系
alias g='git'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gs='git status'
alias gco='git checkout'
alias gpl='git pull'
alias gb='git branch'
alias gd='git diff'

# dotfiles管理
alias zshrc='vi ~/.zshrc'
alias zprofile='vi ~/.zprofile'
alias reloadzrc='source ~/.zshrc && echo ".zshrc reloaded!"'
alias reloadzpro='source ~/.zprofile && echo ".zprofile reloaded!"'

# docker系
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dcps='docker compose ps'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dbuild='docker build -t'


# 安全策
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'
alias rmdir='rmdir -v'

# その他便利なエイリアス
alias tree='tree -C'
alias -g C='| pbcopy' # copy
alias -g G='| grep --color=auto' # 鉄板

# ========= MATLABのエイリアス設定 ==========
# GUIなし（ターミナルのみで MATLAB 起動）
alias mlterm="/Applications/MATLAB_R2025b.app/bin/matlab -nodesktop"

# GUIあり（標準の MATLAB を開く）
alias mlgui="/Applications/MATLAB_R2025b.app/bin/matlab"



# ========== Gitのプロンプト設定 ==========
# git-promptの読み込み
source ~/.zsh/git-prompt.sh

# git-completionの読み込み
fpath=(~/.zsh $fpath)
zstyle ':completion:*:*:git:*' script ~/.zsh/git-completion.bash
autoload -Uz compinit && compinit

# プロンプトのオプション表示設定
GIT_PS1_SHOWDIRTYSTATE=true
GIT_PS1_SHOWUNTRACKEDFILES=true
GIT_PS1_SHOWSTASHSTATE=true
GIT_PS1_SHOWUPSTREAM=auto

# プロンプトの表示設定(好きなようにカスタマイズ可)
setopt PROMPT_SUBST ; PS1='%F{green}%n@%m%f: %F{cyan}%~%f %F{red}$(__git_ps1 "(%s)")%f
\$ '
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

# ~/.local/bin (claude, codex, herdr など) は Nix profile より後ろに置く
case ":${PATH}:" in
    *:"$HOME/.local/bin":*) ;;
    *) export PATH="$PATH:$HOME/.local/bin" ;;
esac

