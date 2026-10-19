# SETUP.md(会社 PC の Claude Code が実行する手順)

この手順は、個人 PC と同じ作業環境(Orca・Helix・Ctrl+G で開くエディタの mod・自作 skill・コンテキストテンプレート)をこの Mac に作るためのものです。上から順に実行してください。

## 進め方の約束

- 各ステップは「やること」「既にあるときの扱い」「確認」の順に書いてあります。確認が通らなかったら、次へ進まずに本人へ状況を伝えてください。
- 既存のファイルは消さずに `.bak`(settings.json は `.bak.<日時>`)を付けて退避します。上書きの前に必ず中身を見てください。
- この PC では GitHub のアカウントを使いません。clone と pull は HTTPS の匿名アクセスだけで行い、push はしません。
- Claude Code の再起動は最後(ステップ 10)に 1 回だけ頼みます。途中で再起動すると、この手順を進めている文脈が切れるためです。
- 置き場は `~/Developer/` です(`~/Documents` は iCloud 同期で git が壊れることがあるので使いません)。
- 終わったら、ok だった項目、飛ばした項目とその理由、本人がやることを 1 つの報告にまとめてください。

## 0. 前提の確認

やること:

```sh
claude --version
ls -la "/Library/Application Support/ClaudeCode/" 2>/dev/null
git ls-remote https://github.com/Kyo1M/skills HEAD
```

確認:

- Claude Code が 2.1.303 以上であること(Ctrl+G の mod と `app:toggleReplTab` が動くことを確かめた版)。古ければ `claude update` を本人に勧めます。
- `managed-settings.json` があれば中身を読み、プラグインやマーケットプレイスの制限、`permissions.defaultMode`・`voice`・`advisorModel`・`model` の指定と食い違うものを本人に伝えます。食い違うキーはステップ 5 で入れず、ステップ 9 の `--skip` に渡します。
- `git ls-remote` が通ること。通らなければ社内のプロキシや遮断の可能性があるので、本人に確認して止まります。

## 1. Command Line Tools と Homebrew

やること:

```sh
xcode-select -p || xcode-select --install
command -v brew || echo "Homebrew が無い"
grep -n "brew shellenv" ~/.zprofile
```

- Command Line Tools が無ければ `xcode-select --install` のダイアログを本人に進めてもらい、終わるまで待ちます。
- Homebrew が無ければ https://brew.sh の導入コマンドを本人に案内して止まります(管理者パスワードが要るため)。
- `~/.zprofile` に `brew shellenv` が無ければ、`eval "$(/opt/homebrew/bin/brew shellenv)"` を末尾に追記します。

## 2. dev-setup と brew のパッケージ

やること:

```sh
mkdir -p ~/Developer
[ -d ~/Developer/dev-setup ] || git clone https://github.com/Kyo1M/dev-setup ~/Developer/dev-setup
brew bundle --file ~/Developer/dev-setup/Brewfile
```

既にあるとき: dev-setup が既にあれば `git -C ~/Developer/dev-setup pull --ff-only` にします。

確認: `hx --version`、`starship --version`、`node --version`、`pandoc --version`、`uv --version` がそれぞれ版を返すこと。

## 3. Orca

やること: `ls /Applications/Orca.app/Contents/Resources/bin/orca` で確かめます。

- 無ければ、Orca を公式サイトから入れて `/Applications` に置くよう本人に頼んで止まります。brew の `orca` は別のソフトなので使いません。
- Ctrl+G の mod は `/Applications/Orca.app/Contents/Resources/bin/orca` を直接呼ぶので、置き場所を変えないでください。

確認: `/Applications/Orca.app/Contents/Resources/bin/orca --version` が版を返すこと。この手順自体を Orca の中の Claude Code で進めていれば、Orca は動いています。

## 4. シェル・Helix・starship・git

やること(既にある行は足しません):

```sh
D=~/Developer/dev-setup/config
line_zshenv='source "$HOME/Developer/dev-setup/config/zsh/zshenv.zsh"'
line_zshrc='source "$HOME/Developer/dev-setup/config/zsh/zshrc.zsh"'
grep -qsF "$line_zshenv" ~/.zshenv || printf '\n%s\n' "$line_zshenv" >> ~/.zshenv
grep -qsF "$line_zshrc" ~/.zshrc || printf '\n%s\n' "$line_zshrc" >> ~/.zshrc

mkdir -p ~/.config/helix
for pair in "$HOME/.config/helix/config.toml:$D/helix/config.toml" "$HOME/.config/starship.toml:$D/starship.toml"; do
  link="${pair%%:*}"; target="${pair#*:}"
  [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ] && continue
  [ -e "$link" ] && mv "$link" "$link.bak"
  ln -s "$target" "$link"
done

git config --global --get-all include.path | grep -qF "$D/git/gitconfig" || git config --global --add include.path "$D/git/gitconfig"
```

既にあるとき:

- `~/.zshenv` と `~/.zshrc` に `EDITOR`・`VISUAL`・starship・zoxide の設定が別にあれば、どちらを残すかを本人に聞きます(後に書いた方が勝ちます)。
- Helix と starship の既存の設定は `.bak` に退避されます。退避したら本人に伝えます。

本人に聞くこと: git の名前とメールアドレス。聞いたら `git config --global user.name "<名前>"` と `git config --global user.email "<メール>"` を実行します。

確認: `env -i HOME="$HOME" PATH="$PATH" zsh -c 'echo $VISUAL'` が `hx` を返すこと。`git config --get core.pager` が `delta` を返すこと。

## 5. skill

やること:

```sh
[ -d ~/Developer/Skills ] || git clone https://github.com/Kyo1M/skills ~/Developer/Skills
cd ~/Developer/Skills && scripts/link-skills.sh
uv tool install git+https://github.com/Kyo1M/claude-worklog
```

既にあるとき:

- Skills が既にあれば `git -C ~/Developer/Skills pull --ff-only` にします。
- `link-skills.sh` が `skip ... は実体ディレクトリ` と出したら、同じ名前の skill が別に置かれています。中身を本人に見せ、消してよいかを聞きます(勝手に消しません)。
- `link-skills.sh` は `~/.agents/skills` にも symlink を張ります。この PC では Codex を使いませんが、害は無いのでそのままにします。

確認: `cd ~/Developer/Skills && scripts/link-skills.sh --check` が「問題なし」で終わること(cwd は必ず `~/Developer/Skills` にします)。

## 6. Claude Code の設定と keybindings

やること:

```sh
D=~/Developer/dev-setup/config/claude
S=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$S" ] || echo '{}' > "$S"
B="$S.bak.$(date +%Y%m%d%H%M%S)"
cp "$S" "$B"
jq -s '.[0] * .[1]' "$B" "$D/settings.partial.json" > "$S.tmp" && mv "$S.tmp" "$S"

K=~/.claude/keybindings.json
if ! { [ -L "$K" ] && [ "$(readlink "$K")" = "$D/keybindings.json" ]; }; then
  [ -e "$K" ] && mv "$K" "$K.bak"
  ln -s "$D/keybindings.json" "$K"
fi
```

既にあるとき:

- ステップ 0 で管理設定と食い違ったキーは、マージ前に `settings.partial.json` のコピーから外して使います(dev-setup のファイル自体は直しません)。
- `settings.json` は Orca も書き込むファイルなので、symlink にせずマージします。Orca が入れた `statusLine` と `hooks` は残ります。
- `keybindings.json` が既にあって Ctrl+G 以外の割り当てを含んでいたら、`.bak` の中身を本人に見せ、dev-setup の割り当てに足すかを聞きます。

確認: `jq '.model, .language, .permissions.defaultMode' ~/.claude/settings.json` が入れた値を返すこと。

## 7. プラグインと Ctrl+G の mod

やること:

```sh
claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
claude plugin marketplace add ayghri/i-have-adhd
claude plugin marketplace add Kyo1M/claude-mods
while read -r id; do
  [ -n "$id" ] && claude plugin install "$id" --scope user
done < ~/Developer/dev-setup/config/claude/plugins.txt
```

既にあるとき: 既に登録されたマーケットプレイスや入っているプラグインはエラーになっても構いません。最後の確認で判断します。

確認: `claude plugin list --json` に `plugins.txt` の全件が `"enabled": true` で出ること。マーケットプレイスの追加が管理設定で止められたら、そのプラグインを飛ばして報告に書きます。

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

1. `jq . ~/Developer/dev-setup/config/orca/settings.json` の値を、キー名・値・Orca の設定画面で探すときの手がかり(例：`terminalFontFamily` はターミナルのフォント)の 3 列の表にして本人に示します。
2. 本人が Orca の設定画面(Cmd+,)で入れます。`terminalColorOverrides`(ターミナルの色の上書き 20 色ほど)は手間が大きいので、入れるかどうかを本人に聞きます。
3. 入れ終わったら次のコマンドで照合し、違う項目だけを本人に伝えます。

```sh
~/Developer/dev-setup/scripts/check.sh 2>/dev/null | grep "Orca の設定"
```

## 10. 点検と再起動

やること:

```sh
~/Developer/dev-setup/scripts/check.sh
```

ステップ 0 で飛ばしたキーがあれば、`--skip model,voice.enabled` のように、キーを `.` でつないだ形でカンマ区切りにして渡します。

ng が残ったら、該当するステップに戻ります。ok にできない項目(会社の制限で入れられないもの等)は理由を添えて報告します。

終わったら、本人に次の 2 つを頼みます。

1. Claude Code を終了して、Orca のターミナルで起動し直す。
2. プロンプト欄で Ctrl+G を押し、ペインが分割されて Helix が開くこと、保存して閉じると書いた文がプロンプト欄に入ることを確かめる。

### 報告に添えること

次の skill は入っていますが、使うには本人の設定が要ります。

- gemini-ja-proofread: Gemini の API キー(`GEMINI_API_KEY` か `~/.gemini/review.env`)
- docx-export の Google ドキュメント出力: gog CLI と Google の認証
- daily-log の Linear 部分: Linear の接続。定期実行の launchd 用 plist には個人 PC のパスが入っているので、使うときは書き換えが要る

## 個人 PC で変更があったとき(pull のあと)

本人から「dev-setup を更新したので反映して」と頼まれたら、次のとおり進めます。

1. `git -C ~/Developer/dev-setup pull --ff-only` を実行し、`git log -p ORIG_HEAD..HEAD --stat` で変わったファイルを確かめます。
2. 変わったファイルごとに対応します。
   - `config/helix`・`config/starship.toml`・`config/zsh`・`config/git`・`config/claude/keybindings.json`: symlink・source・include で読んでいるので、何もしなくても反映されています。
   - `config/claude/settings.partial.json`: ステップ 6 のマージをやり直します。
   - `config/claude/plugins.txt`: 増えたプラグインをステップ 7 の方法で入れます。減ったものは本人に聞いてから `claude plugin uninstall` します。
   - `config/orca/settings.json`: 変わった項目だけをステップ 9 の方法で本人に示します。
   - `Brewfile`: `brew bundle --file ~/Developer/dev-setup/Brewfile` を実行します。
   - `SETUP.md`: 変わったステップを読み、この PC に当てはまるものをやり直します。
3. skill は `git -C ~/Developer/Skills pull --ff-only` を実行し、新しい skill があれば `cd ~/Developer/Skills && scripts/link-skills.sh` を実行します。
4. mod は `claude plugin marketplace update claude-mods` → `claude plugin update orca-split-editor@claude-mods` を実行し、本人に `/reload-plugins` を頼みます。
5. 最後に `scripts/check.sh` を実行して報告します。

## 新しいコンテキストリポジトリを作るとき

GitHub の「Use this template」はアカウントが要るので使いません。テンプレートの中身をコピーしてローカルの git で始めます。

```sh
git -C ~/Developer/project-context-template pull --ff-only
NAME=<project>-context
rsync -a --exclude .git --exclude .github --exclude node_modules ~/Developer/project-context-template/ ~/Developer/$NAME/
cp ~/Developer/dev-setup/config/context/CLAUDE.local.md ~/Developer/$NAME/CLAUDE.local.md
git -C ~/Developer/$NAME init -b main
```

その後、`~/Developer/$NAME` で Claude Code を起動し、「セットアップしたい」と伝えます。`AGENTS.md` の初期セットアップフローは `CLAUDE.local.md` の読み替え(push・PR をしない、確定はローカルのマージ)に沿って進みます。
