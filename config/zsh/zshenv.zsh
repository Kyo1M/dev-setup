# ~/.zshenv から source する。非対話シェルにも効くので、Orca の mod(Ctrl+G)が呼ぶエディタもここで決まる。
export EDITOR=hx
export VISUAL=hx
export SUDO_EDITOR=hx

# uv tool install で入れた CLI(worklog 等)の置き場
[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
