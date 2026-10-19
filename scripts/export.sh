#!/usr/bin/env bash
# 個人 PC で実行する。今の設定のうち、会社 PC に持っていくものだけを config/ に書き出す。
# 載せてよいキーだけを抜く許可リスト方式。最後に scrub.sh で禁止語を検索する。
# 置き場は環境変数で差し替え可: DEV_DIR CLAUDE_DIR ORCA_PROFILE_DIR
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEV_DIR="${DEV_DIR:-$HOME/Developer}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
ORCA_PROFILE_DIR="${ORCA_PROFILE_DIR:-$HOME/Library/Application Support/orca/profiles/local-default}"
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
mkdir -p "$CONFIG/helix" "$CONFIG/claude" "$CONFIG/orca"
cp "$HOME/.config/helix/config.toml" "$CONFIG/helix/config.toml"
cp "$HOME/.config/starship.toml" "$CONFIG/starship.toml"
cp "$CLAUDE_DIR/keybindings.json" "$CONFIG/claude/keybindings.json"
echo "ok    helix・starship・keybindings を書き出し"

# 3. Claude Code の設定(許可リストのキーと defaultMode)
jq --argjson keys "$CLAUDE_KEYS" '
  with_entries(select(.key as $k | $keys | index($k)))
  + {permissions: {defaultMode: "auto"}}
' "$CLAUDE_DIR/settings.json" > "$CONFIG/claude/settings.partial.json"
grep -q '"Japaese"' "$CONFIG/claude/settings.partial.json" && fail "language が誤字(Japaese)のままです"
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
