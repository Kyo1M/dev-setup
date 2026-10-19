#!/usr/bin/env bash
# 公開リポジトリに出してはいけない語を検索する。1 件でもあれば該当箇所を表示して exit 1。
#   scrub.sh           追跡中のファイル(git ls-files)と、まだ追跡していない新規ファイル
#   scrub.sh --staged  commit 予定の内容(pre-commit hook から呼ぶ)
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
# 一覧に書かなくても止める形: ホームディレクトリの絶対パス、メールアドレス、よくあるトークンの形
printf '%s\n' \
  '/Users/[A-Za-z0-9._-]+/' \
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
  'gh[pousr]_[A-Za-z0-9]{20,}' \
  'sk-[A-Za-z0-9_-]{20,}' \
  'AIza[0-9A-Za-z_-]{30,}' \
  'xox[baprs]-[A-Za-z0-9-]{10,}' >> "$patterns"

# noreply のアドレス(commit の Co-Authored-By 等)は許す
allow='noreply@'

found=0
if [ "${1-}" = "--staged" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    hits="$(git show ":$f" 2>/dev/null | LC_ALL=C grep -I -n -i -E -f "$patterns" | grep -v -e "$allow" || true)"
    if [ -n "$hits" ]; then echo "$hits" | sed "s|^|$f:|"; found=1; fi
  done < <(git diff --cached --name-only --diff-filter=ACMR)
else
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    hits="$(LC_ALL=C grep -I -n -i -E -f "$patterns" "$f" | grep -v -e "$allow" || true)"
    if [ -n "$hits" ]; then echo "$hits" | sed "s|^|$f:|"; found=1; fi
  done < <(git ls-files --cached --others --exclude-standard)
fi

if [ "$found" -ne 0 ]; then
  echo "scrub: 公開してはいけない語が見つかりました。上の箇所を直してください" >&2
  exit 1
fi
echo "scrub: 問題なし"
