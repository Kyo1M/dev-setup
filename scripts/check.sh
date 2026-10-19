#!/usr/bin/env bash
# 会社 PC で SETUP.md の最後に実行する。1 項目ずつ ok / ng を出し、ng が 1 つでもあれば exit 1。
#   check.sh --skip <key>,<key>  SETUP.md のステップ 0 で飛ばした settings のキーを照合から外す
# 置き場は環境変数で差し替え可: DEV_DIR CLAUDE_DIR ORCA_PROFILE_DIR
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEV_DIR="${DEV_DIR:-$HOME/Developer}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
ORCA_PROFILE_DIR="${ORCA_PROFILE_DIR:-$HOME/Library/Application Support/orca/profiles/local-default}"
ORCA_BIN=/Applications/Orca.app/Contents/Resources/bin/orca
CONFIG="$REPO_DIR/config"
SKIP='[]'
if [ "${1-}" = "--skip" ] && [ -n "${2-}" ]; then
  SKIP="$(printf '%s' "$2" | jq -R 'split(",")')"
fi

ng_count=0
ok() { echo "ok    $*"; }
ng() { echo "ng    $*"; ng_count=$((ng_count + 1)); }

# brew のパッケージ
for pkg in $(awk '$1 == "brew" { gsub(/"/, "", $2); print $2 }' "$REPO_DIR/Brewfile"); do
  brew list --formula "$pkg" >/dev/null 2>&1 && ok "brew $pkg" || ng "brew $pkg が入っていない(brew bundle)"
done
for cask in $(awk '$1 == "cask" { gsub(/"/, "", $2); print $2 }' "$REPO_DIR/Brewfile"); do
  brew list --cask "$cask" >/dev/null 2>&1 && ok "cask $cask" || ng "cask $cask が入っていない(brew bundle)"
done

# Orca
if [ -x "$ORCA_BIN" ]; then
  ok "Orca $("$ORCA_BIN" --version 2>/dev/null | head -1)"
else
  ng "$ORCA_BIN が無い(Orca を公式サイトから入れて /Applications に置く)"
fi

# シェル・エディタ・git
visual="$(env -i HOME="$HOME" PATH="$PATH" zsh -c 'echo $VISUAL')"
[ "$visual" = "hx" ] && ok "非対話シェルの VISUAL = hx" || ng "非対話シェルの VISUAL が '$visual'(~/.zshenv の source を確認)"
grep -qs "dev-setup/config/zsh/zshrc.zsh" "$HOME/.zshrc" && ok "~/.zshrc が zshrc.zsh を読む" || ng "~/.zshrc に zshrc.zsh の source が無い"
for pair in "$HOME/.config/helix/config.toml:$CONFIG/helix/config.toml" "$HOME/.config/starship.toml:$CONFIG/starship.toml" "$CLAUDE_DIR/keybindings.json:$CONFIG/claude/keybindings.json"; do
  link="${pair%%:*}"; target="${pair#*:}"
  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then ok "$link -> dev-setup"; else ng "$link が dev-setup への symlink になっていない"; fi
done
git config --global --get-all include.path 2>/dev/null | grep -q "dev-setup/config/git/gitconfig" \
  && ok "~/.gitconfig が dev-setup の gitconfig を include" || ng "~/.gitconfig に include が無い"
[ -n "$(git config --global user.email 2>/dev/null)" ] && ok "git の user.email が入っている" || ng "git の user.email が空"

# Claude Code: keybindings
kb="$CLAUDE_DIR/keybindings.json"
if jq -e '[.bindings[] | select(.context == "Chat") | .bindings["ctrl+g"]] | any(. == null)' "$kb" >/dev/null 2>&1 \
  && jq -e '[.bindings[] | select(.context == "Global") | .bindings["ctrl+g"]] | any(. == "app:toggleReplTab")' "$kb" >/dev/null 2>&1; then
  ok "keybindings: Ctrl+G が mod に回っている"
else
  ng "keybindings: Ctrl+G の割り当てが違う"
fi

# Claude Code: settings.json に settings.partial.json のキーが入っている
diff_keys="$(jq -n -r --slurpfile want "$CONFIG/claude/settings.partial.json" --slurpfile have "$CLAUDE_DIR/settings.json" --argjson skip "$SKIP" '
  $want[0] | paths(scalars) as $p
  | select(($p | map(tostring) | join(".")) as $k | $skip | index($k) | not)
  | select(($have[0] | getpath($p)) != ($want[0] | getpath($p)))
  | $p | map(tostring) | join(".")
' 2>/dev/null)"
[ -z "$diff_keys" ] && ok "settings.json に settings.partial.json の値が入っている" || ng "settings.json で値が違うキー: $(echo $diff_keys)"

# Claude Code: プラグイン
if plugins_json="$(claude plugin list --json 2>/dev/null)"; then
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if printf '%s' "$plugins_json" | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled == true)' >/dev/null; then
      ok "plugin $id"
    else
      ng "plugin $id が入っていないか無効"
    fi
  done < "$CONFIG/claude/plugins.txt"
else
  ng "claude plugin list --json が動かない"
fi

# skill
if [ -x "$DEV_DIR/Skills/scripts/link-skills.sh" ]; then
  (cd "$DEV_DIR/Skills" && scripts/link-skills.sh --check >/dev/null 2>&1) && ok "link-skills.sh --check" || ng "link-skills.sh --check が通らない(~/Developer/Skills で実行して内容を確認)"
else
  ng "$DEV_DIR/Skills が無い"
fi
for s in orca-cli orchestration; do
  [ -e "$HOME/.agents/skills/$s/SKILL.md" ] && ok "Orca の skill $s" || ng "Orca の skill $s が無い(orca skills install)"
done
command -v worklog >/dev/null && ok "worklog CLI" || ng "worklog CLI が無い(uv tool install git+https://github.com/Kyo1M/claude-worklog)"

# コンテキストテンプレート
[ -f "$DEV_DIR/project-context-template/AGENTS.md" ] && ok "project-context-template" || ng "$DEV_DIR/project-context-template が無い"

# Orca の設定(SQLite を読み取り専用で開く)
db="$ORCA_PROFILE_DIR/profile-state.db"
if [ -f "$db" ]; then
  orca_diff="$(sqlite3 "file:$db?mode=ro" "select payload from profile_state_documents where domain='settings'" 2>/dev/null \
    | jq -r --slurpfile want "$CONFIG/orca/settings.json" '. as $have | $want[0] | to_entries[] | select($have[.key] != .value) | .key' 2>/dev/null)"
  [ -z "$orca_diff" ] && ok "Orca の設定が config/orca/settings.json と一致" || ng "Orca の設定で値が違う項目: $(echo $orca_diff)"
else
  ng "$db が無い(Orca を一度起動する)"
fi

echo
if [ "$ng_count" -eq 0 ]; then echo "check: すべて ok"; else echo "check: ng が $ng_count 件"; exit 1; fi
