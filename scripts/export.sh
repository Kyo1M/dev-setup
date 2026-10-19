#!/usr/bin/env bash
# 個人 PC で実行する。今の設定のうち、会社 PC に持っていくものだけを config/ に書き出す。
# 載せてよいキーだけを抜く許可リスト方式。最後に scrub.sh で禁止語を検索する。
# 置き場は環境変数で差し替え可: DEV_DIR CLAUDE_DIR ORCA_PROFILE_DIR GHOSTTY_CONFIG
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEV_DIR="${DEV_DIR:-$HOME/Developer}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
ORCA_PROFILE_DIR="${ORCA_PROFILE_DIR:-$HOME/Library/Application Support/orca/profiles/local-default}"
GHOSTTY_CONFIG="${GHOSTTY_CONFIG:-$HOME/Library/Application Support/com.mitchellh.ghostty/config}"
CONFIG="$REPO_DIR/config"

# 会社 PC に持っていかないプラグイン
EXCLUDED_PLUGINS='["codex@openai-codex"]'
# Claude Code の settings.json から持っていくキー
CLAUDE_KEYS='["model","language","effortLevel","modelSettings","advisorModel","tui","voice","voiceEnabled"]'
# Orca の settings から持っていくキー(見た目・操作感。パス・アカウント・状態・agentDefaultArgs は入れない)
ORCA_KEYS='[
  "theme","appFontFamily","editorWordWrap","editorMinimapEnabled","editorAutoSave",
  "terminalFontFamily","terminalFontSize","terminalFontWeight","terminalFontWeightBold","terminalLineHeight",
  "terminalCursorStyle","terminalCursorBlink","terminalThemeDark","terminalThemeLight","terminalUseSeparateLightTheme",
  "terminalColorOverrides","terminalBackgroundOpacity","terminalPaddingX","terminalPaddingY",
  "terminalInactivePaneOpacity","terminalDividerThicknessPx","terminalScrollSensitivity","terminalFastScrollSensitivity",
  "terminalScrollbackRows","terminalMouseHideWhileTyping","windowBackgroundBlur",
  "terminalShortcutPolicy","terminalMacOptionAsAlt",
  "branchPrefix","refreshLocalBaseRefOnWorktreeCreate","defaultTuiAgent","diffWordWrap",
  "skipDeleteWorktreeConfirm","skipCloseTerminalWithRunningProcessConfirm"
]'

fail() { echo "export: $*" >&2; exit 1; }

# 1. 会社 PC は 3 リポジトリの main を GitHub から取るので、手元が main で GitHub と一致していることを確かめる
for name in Skills claude-mods project-context-template; do
  dir="$DEV_DIR/$name"
  [ -d "$dir/.git" ] || fail "$dir がありません"
  git -C "$dir" fetch -q origin main
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  [ "$branch" = "main" ] || fail "$name が main ではなく $branch にいます"
  [ -z "$(git -C "$dir" status --porcelain)" ] || fail "$name に未コミットの変更があります"
  [ "$(git -C "$dir" rev-parse HEAD)" = "$(git -C "$dir" rev-parse origin/main)" ] || fail "$name の main が origin/main と一致しません(push か pull が要ります)"
  echo "ok    $name は main で origin/main と一致"
done

# 2. そのまま持っていくファイル
mkdir -p "$CONFIG/helix" "$CONFIG/yazi" "$CONFIG/ghostty/themes" "$CONFIG/claude" "$CONFIG/orca"
# 個人 PC 側も dev-setup への symlink にしている場合は、同じファイルなのでコピーしない
copy() { [ "$1" -ef "$2" ] || cp "$1" "$2"; }
copy "$HOME/.config/helix/config.toml" "$CONFIG/helix/config.toml"
copy "$HOME/.config/starship.toml" "$CONFIG/starship.toml"
# yazi のプラグインの中身(plugins/)は持たず、package.toml の一覧から ya pkg install で入れる
for f in yazi.toml keymap.toml init.lua package.toml; do
  copy "$HOME/.config/yazi/$f" "$CONFIG/yazi/$f"
done
copy "$CLAUDE_DIR/keybindings.json" "$CONFIG/claude/keybindings.json"
# Ghostty の設定と、theme = で指す配色ファイル(Orca の「Import from Ghostty」が読む。会社 PC に Ghostty 本体が無くても配色を引けるよう同梱する)
copy "$GHOSTTY_CONFIG" "$CONFIG/ghostty/config"
theme="$(sed -nE 's/^theme *= *"?([^"#]*[^"# ])"? *(#.*)?$/\1/p' "$CONFIG/ghostty/config" | tail -1)"
if [ -n "$theme" ]; then
  src=""
  for d in "$HOME/.config/ghostty/themes" /Applications/Ghostty.app/Contents/Resources/ghostty/themes; do
    [ -f "$d/$theme" ] && src="$d/$theme" && break
  done
  [ -n "$src" ] || fail "Ghostty の配色 $theme が見つかりません"
  copy "$src" "$CONFIG/ghostty/themes/$theme"
fi
echo "ok    helix・starship・yazi・ghostty・keybindings を書き出し"

# 3. Claude Code の設定(許可リストのキーと defaultMode)
jq --argjson keys "$CLAUDE_KEYS" '
  with_entries(select(.key as $k | $keys | index($k)))
  + {permissions: {defaultMode: "auto"}}
' "$CLAUDE_DIR/settings.json" > "$CONFIG/claude/settings.partial.json"
echo "ok    settings.partial.json を書き出し"

# 4. 入れるプラグインの一覧(有効なもののうち、持っていかないものを除く)
jq -r --argjson ex "$EXCLUDED_PLUGINS" '
  .enabledPlugins | to_entries[] | select(.value == true) | .key | select(. as $k | $ex | index($k) | not)
' "$CLAUDE_DIR/settings.json" | sort > "$CONFIG/claude/plugins.txt"
echo "ok    plugins.txt を書き出し($(wc -l < "$CONFIG/claude/plugins.txt" | tr -d ' ') 件)"

# 5. Orca の設定。正本は SQLite なので読み取り専用で開く
db="$ORCA_PROFILE_DIR/profile-state.db"
[ -f "$db" ] || fail "$db がありません"
sqlite3 "file:$db?mode=ro" "select payload from profile_state_documents where domain='settings'" \
  | jq --argjson keys "$ORCA_KEYS" 'with_entries(select(.key as $k | $keys | index($k)))' \
  > "$CONFIG/orca/settings.json"
echo "ok    orca/settings.json を書き出し($(jq 'length' "$CONFIG/orca/settings.json") 項目)"

# 6. 禁止語の検索
"$REPO_DIR/scripts/scrub.sh"
