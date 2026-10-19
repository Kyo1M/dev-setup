# SETUP.md(Claude Code が実行する手順)

この手順は、作者の個人 PC と同じ作業環境(Orca・Helix・Ctrl+G で開くエディタの mod・自作 skill・コンテキストテンプレート)をこの Mac に作るためのものです。上から順に実行してください。

## 進め方の約束

- 各ステップは「やること」「既にあるときの扱い」「確認」の順に書いてあります。確認が通らなかったら、次へ進まずに本人へ状況を伝えてください。
- 既存のファイルは消さずに、`.bak.<日時>` を付けて退避します。上書きの前に必ず中身を見てください。
- この Mac では GitHub のアカウントを使いません。clone と pull は HTTPS の匿名アクセスだけで行い、push はしません。
- コマンドのブロックは、シェルの状態が次のブロックに引き継がれない前提で書いてあります。各ブロックの先頭の `eval "$(...brew shellenv)"` の行は省かないでください。
- Claude Code の再起動は最後(ステップ 10)に 1 回だけ頼みます。途中で再起動すると、この手順を進めている文脈が切れるためです。
- 置き場は `~/Developer/` です(`~/Documents` は iCloud 同期で git が壊れることがあるので使いません)。
- 終わったら、ok だった項目、飛ばした項目とその理由、本人がやることを 1 つの報告にまとめてください。

### 始める前に本人の了承を取ること

次の操作は本人の環境の設定を書き換えるので、ステップ 0 の前にまとめて説明し、了承を取ってから進めます。Claude Code が操作ごとに許可を求めてきたら、本人に承認してもらいます。

- `~/.zprofile`・`~/.zshenv`・`~/.zshrc`・`~/.gitconfig` に 1 行ずつ追記する
- `~/.config/helix/config.toml`・`~/.config/starship.toml`・`~/.config/yazi/` の設定 4 つ・`~/.claude/keybindings.json` を dev-setup への symlink にする(既存は退避)
- `~/.claude/settings.json` にモデル・言語・権限モード(`auto`)などの値をマージする
- Homebrew のパッケージ、yazi のプラグイン、Claude Code のプラグイン、Orca の skill、worklog の CLI を入れる

## 0. 前提の確認

やること:

```sh
claude --version
curl -sI https://github.com | head -1
ls -la "/Library/Application Support/ClaudeCode/" 2>/dev/null
plutil -p "/Library/Managed Preferences/com.anthropic.claudecode.plist" 2>/dev/null
```

確認:

- Claude Code が 2.1.303 以上であること(Ctrl+G の mod と `app:toggleReplTab` が動くことを確かめた版)。古ければ `claude update` を本人に勧めます。
- `curl` が `HTTP/2 200` などを返すこと。返らなければ社内のプロキシや遮断の可能性があるので、本人に確認して止まります。
- 会社などの管理設定があるかを確かめます。`/Library/Application Support/ClaudeCode/` の `managed-settings.json` と `managed-settings.d/`、上の plist があれば中身を読みます。サーバーから配られる管理設定はファイルで見えないことがあるので、本人に Claude Code の `/status` で設定の出どころを見てもらいます。
- 管理設定で、プラグインやマーケットプレイスの制限、`permissions.defaultMode`・`voice`・`voiceEnabled`・`advisorModel`・`model` の指定があれば本人に伝えます。食い違うキーは、ステップ 6 でマージから外し、ステップ 10 の `--skip` に渡します。

## 1. Command Line Tools と Homebrew

やること:

```sh
xcode-select -p || echo "Command Line Tools が無い"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && echo "brew: $b" && break; done
grep -n "brew shellenv" ~/.zprofile
```

- Command Line Tools が無ければ `xcode-select --install` のダイアログを本人に進めてもらい、終わるまで待ちます(git もこれで入ります)。
- Homebrew は、`command -v brew` ではなく上の 2 つのパスで有無を判断します(`~/.zprofile` に設定が無いと、入っていても PATH に出ないため)。どちらにも無ければ https://brew.sh の導入コマンドを本人に案内して止まります(管理者パスワードが要るため)。
- `~/.zprofile` に `brew shellenv` が無ければ、見つかった brew のパスで `eval "$(<brew のパス> shellenv)"` を末尾に追記します。

## 2. dev-setup と brew のパッケージ

やること:

```sh
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
mkdir -p ~/Developer
[ -d ~/Developer/dev-setup ] || git clone https://github.com/Kyo1M/dev-setup ~/Developer/dev-setup
brew bundle --file ~/Developer/dev-setup/Brewfile
```

既にあるとき: dev-setup が既にあれば `git -C ~/Developer/dev-setup pull --ff-only` にします。

確認: `hx --version`、`starship --version`、`yazi --version`、`lazygit --version`、`node --version`、`pandoc --version`、`uv --version`、`jq --version` がそれぞれ版を返すこと。

## 3. Orca

やること: `ls /Applications/Orca.app/Contents/Resources/bin/orca` で確かめます。

- 無ければ、Orca を公式サイトから入れて `/Applications` に置くよう本人に頼んで止まります。brew の `orca` は別のソフトなので使いません。
- Ctrl+G の mod は `/Applications/Orca.app/Contents/Resources/bin/orca` を直接呼ぶので、置き場所を変えないでください。

確認: `/Applications/Orca.app/Contents/Resources/bin/orca --version` が版を返すこと。

## 4. シェル・Helix・starship・yazi・git

やること(既にある行は足しません。何度実行しても同じ結果になります):

```sh
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
D="$HOME/Developer/dev-setup/config"
ts="$(date +%Y%m%d%H%M%S)"
line_zshenv='[ -r "$HOME/Developer/dev-setup/config/zsh/zshenv.zsh" ] && source "$HOME/Developer/dev-setup/config/zsh/zshenv.zsh"'
line_zshrc='[ -r "$HOME/Developer/dev-setup/config/zsh/zshrc.zsh" ] && source "$HOME/Developer/dev-setup/config/zsh/zshrc.zsh"'
grep -qsF "$line_zshenv" ~/.zshenv || printf '\n%s\n' "$line_zshenv" >> ~/.zshenv
grep -qsF "$line_zshrc" ~/.zshrc || printf '\n%s\n' "$line_zshrc" >> ~/.zshrc

mkdir -p ~/.config/helix ~/.config/yazi
pairs=("$HOME/.config/helix/config.toml:$D/helix/config.toml" "$HOME/.config/starship.toml:$D/starship.toml")
for f in yazi.toml keymap.toml init.lua package.toml; do pairs+=("$HOME/.config/yazi/$f:$D/yazi/$f"); done
for pair in "${pairs[@]}"; do
  link="${pair%%:*}"; target="${pair#*:}"
  [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ] && continue
  { [ -e "$link" ] || [ -L "$link" ]; } && mv "$link" "$link.bak.$ts"
  ln -s "$target" "$link"
done
# yazi のプラグインは package.toml の一覧から GitHub の匿名アクセスで入れる
ya pkg install

# 既存の [include] 節に足すと後ろの設定に負けることがあるので、末尾に新しい節を書く
grep -qsF "$D/git/gitconfig" ~/.gitconfig || printf '\n[include]\n\tpath = %s\n' "$D/git/gitconfig" >> ~/.gitconfig
```

既にあるとき:

- `~/.zshenv` と `~/.zshrc` に `EDITOR`・`VISUAL`・starship・zoxide の設定が別にあれば、どちらを残すかを本人に聞きます(後に書いた方が勝ちます)。
- Helix・starship・yazi の既存の設定は `.bak.<日時>` に退避されます。退避したら本人に伝えます。
- `~/.config/yazi/plugins/` に package.toml に無いプラグインがあれば、消さずに本人に伝えます。

本人に聞くこと: git の名前とメールアドレス。聞いたら `git config --global user.name "<名前>"` と `git config --global user.email "<メール>"` を実行します。

確認:

- `env -i HOME="$HOME" PATH="$PATH" zsh -c 'echo $VISUAL'` が `hx` を返すこと。
- `ls ~/.config/yazi/plugins` に `git.yazi`・`full-border.yazi`・`smart-enter.yazi` があること。
- `git config --show-origin --get core.pager` が `delta` を返すこと。`delta` でなければ、出どころのファイルと行を本人に見せ、どちらを残すかを聞きます。

## 5. skill

やること:

```sh
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
[ -d ~/Developer/Skills ] || git clone https://github.com/Kyo1M/skills ~/Developer/Skills
cd ~/Developer/Skills && scripts/link-skills.sh
/Applications/Orca.app/Contents/Resources/bin/orca skills install --skill orca-cli --skill orchestration
uv tool install git+https://github.com/Kyo1M/claude-worklog
```

既にあるとき:

- Skills が既にあれば `git -C ~/Developer/Skills pull --ff-only` にします。
- `link-skills.sh` が `skip ... は実体ディレクトリ` と出したら、同じ名前の skill が別に置かれています。中身を本人に見せ、消してよいかを聞きます(勝手に消しません)。
- `link-skills.sh` は `~/.agents/skills` にも symlink を張ります。この Mac では Codex を使いませんが、害は無いのでそのままにします。
- `uv tool install` は、既に入っていればエラーになっても構いません。

確認:

- `cd ~/Developer/Skills && scripts/link-skills.sh --check` が「問題なし」で終わること(cwd は必ず `~/Developer/Skills` にします)。
- `~/.agents/skills/orca-cli/SKILL.md` と `~/.agents/skills/orchestration/SKILL.md` があること。
- `ls ~/.local/bin/worklog` があること(PATH には `zshenv.zsh` で入ります)。

## 6. Claude Code の設定と keybindings

ステップ 0 で管理設定と食い違ったキーがあれば、`SKIP_KEYS` に jq のパスで書きます(例：`SKIP_KEYS='.voice, .voiceEnabled'`)。無ければ空のままにします。

やること:

```sh
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
SKIP_KEYS=''
D="$HOME/Developer/dev-setup/config/claude"
S="$HOME/.claude/settings.json"
ts="$(date +%Y%m%d%H%M%S)"
mkdir -p ~/.claude
[ -f "$S" ] || echo '{}' > "$S"
jq -e 'type == "object"' "$S" >/dev/null || { echo "settings.json が JSON として読めないので止まる"; exit 1; }
cp "$S" "$S.bak.$ts"
partial="$(mktemp)"
if [ -n "$SKIP_KEYS" ]; then jq "del($SKIP_KEYS)" "$D/settings.partial.json" > "$partial"; else cp "$D/settings.partial.json" "$partial"; fi
jq -s '.[0] * .[1]' "$S.bak.$ts" "$partial" > "$S.tmp" && mv "$S.tmp" "$S"

K="$HOME/.claude/keybindings.json"
if ! { [ -L "$K" ] && [ "$(readlink "$K")" = "$D/keybindings.json" ]; }; then
  { [ -e "$K" ] || [ -L "$K" ]; } && mv "$K" "$K.bak.$ts"
  ln -s "$D/keybindings.json" "$K"
fi
```

既にあるとき:

- `settings.json` は Orca も書き込むファイルなので、symlink にせずマージします。Orca が入れた `statusLine` と `hooks` は残ります。
- `keybindings.json` が既にあって Ctrl+G 以外の割り当てを含んでいたら、退避した `.bak.<日時>` の中身を本人に見せ、dev-setup の割り当てに足すかを聞きます。

確認: `jq '.model, .language, .permissions.defaultMode' ~/.claude/settings.json` が入れた値を返すこと。

## 7. プラグインと Ctrl+G の mod

やること:

```sh
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
claude plugin marketplace list
claude plugin marketplace add anthropics/claude-plugins-official || echo "(既に登録済みなら問題なし)"
claude plugin marketplace add ayghri/i-have-adhd || echo "(既に登録済みなら問題なし)"
claude plugin marketplace add Kyo1M/claude-mods || echo "(既に登録済みなら問題なし)"
while IFS= read -r id; do
  [ -n "$id" ] && claude plugin install "$id" --scope user < /dev/null
done < ~/Developer/dev-setup/config/claude/plugins.txt
```

既にあるとき: 既に入っているプラグインはエラーになっても構いません。最後の確認で判断します。

確認: `claude plugin list --json` に `plugins.txt` の全件が `"enabled": true` で出ること。マーケットプレイスの追加が管理設定で止められたら、エラーの文言を添えて、そのプラグインを飛ばしたと報告に書きます。

## 8. コンテキストテンプレート

やること:

```sh
[ -d ~/Developer/project-context-template ] || git clone https://github.com/Kyo1M/project-context-template ~/Developer/project-context-template
```

既にあるとき: `git -C ~/Developer/project-context-template pull --ff-only` にします。

確認: `~/Developer/project-context-template/AGENTS.md` があること。新しい案件のリポジトリを作る手順は、この文書の末尾の「新しいコンテキストリポジトリを作るとき」にあります。

## 9. Orca の設定

Orca の設定は Orca の中のデータベースに入っていて、外から書き換える手段がありません。この手順を進めている Claude は Orca の中で動いているので、Orca を終了することもできません。そこで、値を本人に示して設定画面で入れてもらいます。

やること:

1. `jq . ~/Developer/dev-setup/config/orca/settings.json` の値を、「キー名・値・設定画面で探す手がかり(例：`terminalFontFamily` はターミナルのフォント)」の 3 列の表にして本人に示します。手がかりはキー名から推して書き、確かでないものは「設定画面の検索で探す」とします。
2. 次の 2 つは、入れるかどうかを本人に聞きます。
   - `terminalColorOverrides`(ターミナルの色の上書き 20 色ほど): 手間が大きいため。
   - `skipDeleteWorktreeConfirm`・`skipCloseTerminalWithRunningProcessConfirm`: 確認のダイアログを省く設定のため。
3. 本人が Orca の設定画面(Cmd+,)で入れます。入れないと決めたキーは控えておき、ステップ 10 の `--skip` に渡します。
4. 入れ終わったら次のコマンドで照合し、違う項目だけを本人に伝えます。

```sh
~/Developer/dev-setup/scripts/check.sh --skip "<入れないキー>" 2>/dev/null | grep "Orca の設定"
```

## 10. 点検と再起動

やること:

```sh
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)" && break; done
~/Developer/dev-setup/scripts/check.sh --skip "<ステップ 0 と 9 で外したキー>"
```

`--skip` には、Claude Code の settings のキー(`voice` や `voice.enabled` のように `.` でつなぐ)と Orca のキーを、カンマ区切りでまとめて渡します。`voice` と書けば `voice.*` も外れます。外したキーが無ければ `--skip` ごと省きます。

ng が残ったら、該当するステップに戻ります。ok にできない項目(会社の制限で入れられないもの等)は理由を添えて報告します。

すべて片付いたら、この時点の dev-setup を「反映済み」として記録します(次の更新で、どこから差分を見ればよいかの目印になります)。

```sh
git -C ~/Developer/dev-setup tag -f applied
```

最後に、本人に次の 2 つを頼みます。

1. Claude Code を終了して、Orca のターミナルで起動し直す。
2. プロンプト欄で Ctrl+G を押し、ペインが分割されて Helix が開くこと、保存して閉じると書いた文がプロンプト欄に入ることを確かめる。

### 報告に添えること

次の skill は入っていますが、使うには本人の設定が要ります。

- gemini-ja-proofread: Gemini の API キー(`GEMINI_API_KEY` か `~/.gemini/review.env`)
- docx-export の Google ドキュメント出力: gog CLI と Google の認証
- daily-log の Linear 部分: Linear の接続。定期実行の launchd 用 plist には作者の PC のパスが入っているので、使うときは書き換えが要る

## 作者の PC で変更があったとき

本人から「dev-setup を更新したので反映して」と頼まれたら、次のとおり進めます。

1. 取り込みと差分の確認。`applied` は前回反映したときの目印です。

   ```sh
   git -C ~/Developer/dev-setup pull --ff-only
   git -C ~/Developer/dev-setup diff --stat applied..HEAD
   ```

2. 変わったファイルごとに対応します。
   - `config/helix`・`config/starship.toml`・`config/zsh`・`config/git`・`config/claude/keybindings.json`: symlink・source・include で読んでいるので、何もしなくても反映されています。
   - `config/claude/settings.partial.json`: ステップ 6 をやり直します。
   - `config/claude/plugins.txt`: 増えたプラグインをステップ 7 の方法で入れます。減ったものは本人に聞いてから `claude plugin uninstall` します。
   - `config/orca/settings.json`: `git diff applied..HEAD -- config/orca/settings.json` で変わった項目だけを、ステップ 9 の方法で本人に示します。
   - `Brewfile`: `brew bundle --file ~/Developer/dev-setup/Brewfile` を実行します。
   - `SETUP.md`: 変わったステップを読み、この Mac に当てはまるものをやり直します。
3. skill は `git -C ~/Developer/Skills pull --ff-only` を実行し、新しい skill があれば `cd ~/Developer/Skills && scripts/link-skills.sh` を実行します。
4. mod は `claude plugin marketplace update claude-mods` → `claude plugin update orca-split-editor@claude-mods` を実行し、本人に `/reload-plugins` を頼みます。
5. `scripts/check.sh` を実行し、すべて片付いたら `git -C ~/Developer/dev-setup tag -f applied` で目印を進めて報告します。

## 新しいコンテキストリポジトリを作るとき

GitHub の「Use this template」はアカウントが要るので使いません。テンプレートの中身をコピーしてローカルの git で始めます。`<project>` は本人に聞いて決めます。

```sh
NAME=<project>-context
[ -e ~/Developer/$NAME ] && { echo "~/Developer/$NAME は既にあるので止まる"; exit 1; }
git -C ~/Developer/project-context-template pull --ff-only
rsync -a --exclude .git --exclude .github --exclude node_modules ~/Developer/project-context-template/ ~/Developer/$NAME/
cp ~/Developer/dev-setup/config/context/CLAUDE.local.md ~/Developer/$NAME/CLAUDE.local.md
git -C ~/Developer/$NAME init -b main
```

その後、`~/Developer/$NAME` で Claude Code を起動し、「セットアップしたい」と伝えます。`AGENTS.md` の初期セットアップフローは `CLAUDE.local.md` の読み替え(push・PR をしない、確定はローカルのマージ)に沿って進みます。
