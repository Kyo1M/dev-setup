#!/usr/bin/env bash
# 公開リポジトリに出してはいけない語を検索する。1 件でもあれば該当箇所を表示して exit 1。
#   scrub.sh                 追跡中のファイルと、まだ追跡していない新規ファイル
#   scrub.sh --staged        commit 予定の内容(pre-commit hook から呼ぶ)
#   scrub.sh --message <f>   commit メッセージ(commit-msg hook から呼ぶ)
#   scrub.sh --range <a..b>  push する commit のメッセージと差分(pre-push hook から呼ぶ)
# 禁止語の一覧は git 管理外の .scrub-words(1 行 1 語、大文字小文字を区別しない、# で始まる行は注釈)。
# 一覧が無いときは止める。画像などのバイナリは、圧縮データの偶然の一致を拾うので対象にしない。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORDS_FILE="$REPO_DIR/.scrub-words"
cd "$REPO_DIR"

if [ ! -f "$WORDS_FILE" ]; then
  echo "scrub: $WORDS_FILE が無いので止めます(メールアドレス・案件名などを 1 行 1 語で書く)" >&2
  exit 1
fi

patterns="$(mktemp)"
trap 'rm -f "$patterns"' EXIT
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$WORDS_FILE" | sed 's/[][\.*^$/+?(){}|]/\\&/g' > "$patterns"
# 一覧に書かなくても止める形: ホームディレクトリの絶対パス、メールアドレス、よくあるトークン・鍵の形
printf '%s\n' \
  '/Users/[A-Za-z0-9._-]+' \
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
  'gh[pousr]_[A-Za-z0-9]{20,}' \
  'github_pat_[A-Za-z0-9_]{20,}' \
  'sk-[A-Za-z0-9_-]{20,}' \
  'AIza[0-9A-Za-z_-]{30,}' \
  'AKIA[0-9A-Z]{16}' \
  'xox[baprs]-[A-Za-z0-9-]{10,}' \
  'lin_api_[A-Za-z0-9]{20,}' \
  'ntn_[A-Za-z0-9]{20,}' \
  '-----BEGIN [A-Z ]*PRIVATE KEY-----' >> "$patterns"

# 標準入力を検査し、見つかった行を「<名前>:<行番号>:<行>」で出して 1 を返す(パイプの先で呼ぶので変数でなく戻り値で伝える)。
# noreply のアドレス(Co-Authored-By 等)はアドレスだけを消してから照合する(行ごと外すと同じ行の禁止語を見逃すため)。
found=0
scan() {
  local label="$1" hits
  hits="$(sed -E 's/[A-Za-z0-9._%+-]*noreply@[A-Za-z0-9.-]*//g' | LC_ALL=C grep -I -n -i -E -f "$patterns" || true)"
  [ -z "$hits" ] && return 0
  printf '%s\n' "$hits" | sed "s|^|$label:|"
  return 1
}

# 日本語のファイル名を引用符つきで出さないよう quotePath を切り、NUL 区切りで読む
g() { git -c core.quotePath=off "$@"; }

case "${1-}" in
  --staged)
    while IFS= read -r -d '' f; do
      g show ":$f" | scan "$f" || found=1
    done < <(g diff --cached --name-only -z --diff-filter=ACMR)
    ;;
  --message)
    { grep -v '^#' "$2" || true; } | scan "commit メッセージ" || found=1
    ;;
  --range)
    while IFS= read -r c; do
      g log -1 --format=%B "$c" | scan "commit $c のメッセージ" || found=1
      { g show --format= "$c" | grep '^+' || true; } | scan "commit $c の差分" || found=1
    done < <(g rev-list "$2")
    ;;
  *)
    while IFS= read -r -d '' f; do
      [ -f "$f" ] || continue
      scan "$f" < "$f" || found=1
    done < <(g ls-files -z --cached --others --exclude-standard)
    ;;
esac

if [ "$found" -ne 0 ]; then
  echo "scrub: 公開してはいけない語が見つかりました。上の箇所を直してください" >&2
  exit 1
fi
echo "scrub: 問題なし"
