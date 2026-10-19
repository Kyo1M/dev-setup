# ~/.zshrc から source する。brew の PATH が通っている前提(~/.zprofile の brew shellenv)。
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v starship >/dev/null && eval "$(starship init zsh)"
if command -v bat >/dev/null; then
  alias cat='bat --paging=never'
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export BAT_THEME="OneHalfDark"
fi
