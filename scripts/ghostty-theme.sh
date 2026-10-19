#!/usr/bin/env bash
# Ghostty の設定ファイルから theme の値を 1 つ出す(無ければ空)。Orca の「Import from Ghostty」と同じく、
# = の前後の空白を除き、行末の「 #」以降を捨て、引用符を外し、最後に書いた値を使う。
set -euo pipefail
awk '
  { line = $0; sub(/^[ \t]+/, "", line) }
  line == "" || substr(line, 1, 1) == "#" { next }
  {
    i = index(line, "="); if (!i) next
    k = substr(line, 1, i - 1); sub(/[ \t]+$/, "", k); if (k != "theme") next
    v = substr(line, i + 1); sub(/[ \t]+#.*$/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
    if (length(v) >= 2 && (v ~ /^".*"$/ || v ~ /^\047.*\047$/)) v = substr(v, 2, length(v) - 2)
    last = v
  }
  END { print last }
' "$1"
