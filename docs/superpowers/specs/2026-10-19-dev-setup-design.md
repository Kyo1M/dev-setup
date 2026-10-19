# dev-setup 設計書

## 目的

会社用の Mac で、個人 PC と同じ作業環境(Orca・Helix・Ctrl+G で開くエディタの mod・自作 skill・コンテキストテンプレート)を、会社 PC の Claude Code にリポジトリを 1 つ渡すだけで再現できるようにする。

成功の条件は次のとおり。

- 会社 PC の Claude に README の 1 行を渡すと、`SETUP.md` に沿って上から設定が進み、最後の `scripts/check.sh` がすべて通る。
- Orca 上の Claude Code で Ctrl+G を押すと、ペインが分割されて Helix でプロンプトを書ける。
- 自作 skill が `/` の一覧に出て、skill が使う道具(node・pandoc・uv 等)も入っている。
- project-context-template から新しいコンテキストリポジトリをローカルに作り、AGENTS.md の運用で迷わず使える。
- 個人 PC で設定を変えたら、push → 会社 PC で `git pull` するだけで、ほぼ反映される。

## 前提

| 項目 | 内容 |
|---|---|
| 会社 PC | macOS、Homebrew を使える |
| GitHub | 会社 PC ではアカウントを使わない。公開リポジトリを HTTPS で匿名 clone・pull するだけ |
| 同期の向き | 個人 PC → 会社 PC の一方向。会社 PC での修正は持ち帰らない(直すときは個人 PC で直す) |
| 対象のエージェント | Claude Code のみ。Codex は使わない |
| グローバル CLAUDE.md・memory | 持ち込まない。会社 PC で一から育てる |
| 未確認の前提 | 会社のネットワークから github.com に届くこと(プロキシ・遮断)、会社の Claude のプランと管理設定でプラグインやマーケットプレイスを入れられること。どちらも SETUP.md のステップ 0 で確かめる |

既存の 3 リポジトリ(Kyo1M/skills・Kyo1M/claude-mods・Kyo1M/project-context-template)と、プラグインの i-have-adhd、worklog の CLI(Kyo1M/claude-worklog)はすべて公開で、認証なしで読めることを確認した。

## 方式

Claude が読む手順書(`SETUP.md`)と、移す設定ファイル、最後に通す点検スクリプトを 1 つの公開リポジトリ `Kyo1M/dev-setup` に置く。会社 PC では dev-setup を `~/Developer/dev-setup` に clone し、設定ファイルはコピーせず、symlink・`include`・`source` で dev-setup のファイルを直接読ませる。これで設定の更新は `git pull` だけで反映される。

一発で全部入れる `install.sh` と dotfiles 管理ツール(chezmoi 等)は採らない。前者は既存設定との衝突をスクリプトで全部さばく必要があり、壊れたときに直しにくい。後者は 2 台・一方向の今回には重い。

dev-setup は薄く保つ。skill・mod・テンプレートの中身は既存リポジトリが正本で、dev-setup はそれを指すだけにする。

## リポジトリ構成

```
dev-setup/
├── README.md          人向け。会社 PC の Claude に渡す 1 行と、更新の流れだけ
├── SETUP.md           会社 PC の Claude が上から実行する手順書
├── Brewfile           helix, starship, zoxide, bat, git-delta, jq, node, pandoc, uv, font-hack-nerd-font
├── .gitignore         .scrub-words を除外
├── config/
│   ├── helix/config.toml            ~/.config/helix/config.toml から symlink
│   ├── starship.toml                ~/.config/starship.toml から symlink
│   ├── zsh/zshenv.zsh               EDITOR / VISUAL / SUDO_EDITOR = hx。~/.zshenv から source
│   ├── zsh/zshrc.zsh                zoxide・starship・bat。~/.zshrc から source
│   ├── git/gitconfig                delta・merge・diff。~/.gitconfig から [include]
│   ├── claude/keybindings.json      Ctrl+G を mod に回す設定
│   ├── claude/settings.partial.json Claude Code 設定の自作部分だけ
│   ├── claude/plugins.txt           入れるプラグインの一覧(1 行 1 つ、マーケットプレイス付き)
│   ├── orca/settings.json           Orca の設定画面で入れる値(照合用)
│   └── context/CLAUDE.local.md      ローカルだけで運用するときの読み替え(コンテキストリポジトリに置く)
└── scripts/
    ├── export.sh     個人 PC で実行。今の設定を config/ に書き出し、禁止語を検索する
    ├── scrub.sh      リポジトリ全体の禁止語検索。export.sh と pre-commit hook から呼ぶ
    └── check.sh      会社 PC で最後に実行。全項目を点検する
```

## 何をどこが持つか

| 対象 | 会社 PC でのやり方 | 正本 |
|---|---|---|
| skill | `~/Developer/Skills` に clone → `scripts/link-skills.sh` | Kyo1M/skills |
| mod(Ctrl+G) | `claude plugin marketplace add Kyo1M/claude-mods` → `claude plugin install orca-split-editor@claude-mods --scope user` | Kyo1M/claude-mods |
| 公式などのプラグイン | `plugins.txt` の全件を `claude plugin install <id> --scope user`(マーケットプレイスは先に `marketplace add`) | dev-setup |
| コンテキストテンプレート | `~/Developer/project-context-template` に clone。新しい案件は中身を `.git` と `.github` 抜きでコピー → `git init` → `CLAUDE.local.md` を置く → AGENTS.md の初期セットアップフロー | Kyo1M/project-context-template |
| Claude Code 設定 | `settings.partial.json` を既存の settings.json へ jq でマージ(Orca も書き込むファイルなので symlink にしない)。`keybindings.json` は既存を `.bak` に退避して dev-setup への symlink にする | dev-setup |
| Orca 設定 | 本人が Orca の設定画面で `config/orca/settings.json` の値を入れる。Claude は値の表を示し、check.sh で照合する | dev-setup |
| Helix・starship・シェル・git | symlink・source・include の 1 行を足す。設定の中身は dev-setup 側 | dev-setup |

mod の入れ方は claude-mods の README の `/plugin install` と同じ内容を CLI で行うもので、会社 PC の Claude が対話なしで実行できるよう CLI 形式を使う。claude-mods の README にも CLI 形式を併記し、2 つの書き方が食い違わないようにする。

## 移すもの

### Claude Code(settings.partial.json・plugins.txt)

| キー | 値の扱い |
|---|---|
| model・language・effortLevel・modelSettings・advisorModel・tui・voice・voiceEnabled | 個人 PC の値。language は個人 PC 側の誤字(`Japaese`)を直してから書き出す |
| permissions.defaultMode | `auto` |

plugins.txt に載せるのは、公式マーケットプレイスで有効にしている 8 つ(claude-code-setup・claude-md-management・code-review・code-simplifier・context7・frontend-design・playwright・skill-creator)、`i-have-adhd@i-have-adhd`、`orca-split-editor@claude-mods`。`codex@openai-codex` と無効にしているものは載せない。マーケットプレイスは `marketplace add` で、enabledPlugins は `claude plugin install` で入るので、どちらも settings.partial.json に入れない。

マージは「既存の settings.json を残し、上のキーだけ上書き・追加する」。Orca が書き込む statusLine と hook は会社 PC の Orca が自分で入れるので、dev-setup からは触らない。

### Orca(settings.json)

Orca の設定の正本は `profiles/<profile>/profile-state.db`(SQLite)で、`orca-data.json` は移行前の書き出しが残っているだけである。Orca CLI には設定を読み書きするコマンドが無く、SQLite へ直接書くと版と整合を取る規則がわからないため、書き換えはしない。

- export.sh: 個人 PC の SQLite を読み取り専用で開き、`profile_state_documents` の settings から許可リストのキーだけを抜いて `config/orca/settings.json` に書く。
- 許可リストは見た目と操作感のキーにする(テーマ・アプリとエディタのフォント・エディタの折り返しやミニマップ・ターミナルのフォント・サイズ・太さ・行間・カーソル・テーマ・ペインの濃さ・スクロール感度・ブランチ名の接頭辞など)。キーの最終的な一覧は実装時に、Orca の設定画面の項目名との対応表を付けて決める。
- Ctrl+G の受け取りに関わりうる `terminalShortcutPolicy` と `terminalMacOptionAsAlt` は許可リストに入れ、実装時に Ctrl+G への影響を確かめる。
- `agentDefaultArgs`(Claude を権限確認なしで起動する引数を含む)は会社 PC に持ち込まない。パス(workspaceDir・履歴)、アカウント、端末固有の値、状態(repos・worktree・セッション等)も抜かない。
- check.sh: 会社 PC の SQLite を読み取り専用で開き、値を照合する。

### シェル・エディタ・git

- `~/.zshenv` に `source ~/Developer/dev-setup/config/zsh/zshenv.zsh`。EDITOR / VISUAL / SUDO_EDITOR = hx を、Ctrl+G の mod が呼ぶ非対話シェルにも効かせる。
- `~/.zshrc` に `source ~/Developer/dev-setup/config/zsh/zshrc.zsh`。zoxide と starship は brew の PATH が前提なので、ステップ 1 で `~/.zprofile` に `brew shellenv` があるかを確かめる。
- `~/.gitconfig` に `[include] path = ~/Developer/dev-setup/config/git/gitconfig`。user.name と email は手順の中で本人に聞いて `git config --global` で入れる。credential helper は載せない。
- Helix と starship は、既存ファイルがあれば `.bak` に退避してから symlink を張る。

### コンテキストテンプレートのローカル運用(CLAUDE.local.md)

project-context-template の AGENTS.md は、push・PR のマージによる確定・`git pull --ff-only`・GitHub Actions の lint を前提にしている。リモートの無い会社 PC でそのまま読むと、pull と push が毎回失敗して Claude が迷う。そこで、新しいコンテキストリポジトリに `CLAUDE.local.md` を置き、次の読み替えを書く。

- push・pull・PR は行わない。確定は main への commit(作業ブランチを使ったときはローカルで main にマージ)とする。
- lint はローカルで `npm run lint --prefix scripts` を実行する(node は Brewfile で入る)。
- AGENTS.md の推奨 skill の導入手順(`npx skills add Kyo1M/skills`)は使わない。skill は dev-setup で配布済みで、実行すると skill の実体が `~/.claude/skills` にでき、`link-skills.sh` が止まる。

テンプレート本体は変えない。

## 移さないもの

- グローバル CLAUDE.md・memory
- Codex 関連(プラグイン・`~/.codex`・Orca の codex 設定)
- Orca が自動で書く statusLine・hook、herdr の hook
- Orca の `agentDefaultArgs`
- 認証情報(`.credentials.json`・`~/.claude.json`・各種トークン)
- gh と gh 関連の設定(2 アカウント自動切り替え・`gh pr merge` の確認 hook)。会社 PC では GitHub アカウントを使わないため
- ssh 設定、案件別の gitconfig の include
- autoMode と permissions.allow(クライアント名や個人の Google アカウントを含むため)
- スラッシュコマンド(speed-commit・agmsg・ui-skills)
- conda・Windsurf・Antigravity・julia・nvm 等の PATH 行

## SETUP.md の書き方

会社 PC の Claude が無人で迷わないよう、各ステップを次の 3 点で書く。

- やること(実行するコマンド)
- 既にあるときの扱い(上書きしない・追記を飛ばす・退避してから置き換える、のどれか)
- 確認コマンド

ステップの順は次のとおり。

0. 前提の確認。`claude --version` が 2.1.303 以上(個人 PC で mod と `app:toggleReplTab` が動いている版。これより古ければ `claude update` を案内する)、管理設定(`/Library/Application Support/ClaudeCode/managed-settings.json`)の有無と中身、`git ls-remote https://github.com/Kyo1M/skills` が通るか。管理設定で使えない値(defaultMode・voice・advisorModel 等)があれば、その値を飛ばして報告に添える。
1. Command Line Tools(`xcode-select -p`)と Homebrew の確認、`~/.zprofile` の `brew shellenv`。
2. dev-setup の clone と `brew bundle`。
3. Orca の確認。brew の `orca` は別のソフトなので使わない。`/Applications/Orca.app/Contents/Resources/bin/orca` が無ければ、公式サイトから入れて /Applications に置くよう本人に頼んで止まる。
4. シェル・Helix・starship・git の 1 行追加と symlink。
5. skill の clone と `link-skills.sh`(cwd を `~/Developer/Skills` にして実行)。worklog の CLI は `uv tool install git+https://github.com/Kyo1M/claude-worklog`。
6. Claude Code 設定のマージと keybindings の symlink。
7. マーケットプレイスの追加と plugins.txt の全件 install。
8. コンテキストテンプレートの clone。
9. Orca 設定。`config/orca/settings.json` の値を、設定画面で探す手がかりつきの表で本人に示し、入れてもらう。
10. `scripts/check.sh` で点検して結果を本人に報告し、最後に 1 回だけ Claude Code の再起動を本人に頼む(途中で再起動すると、手順を実行している Claude の文脈が切れるため)。再起動後に Ctrl+G を本人に試してもらう。

skill のうち、使うのに認証や API キーが要るもの(gemini-ja-proofread の Gemini API キー、docx-export の Google Drive 部分の gog CLI と Google 認証、daily-log の Linear 部分)は、入れたうえで「認証が要る」と報告に添える。daily-log の launchd 用 plist には個人 PC の絶対パスが入っているので、会社 PC で定期実行するときは書き換えが要ることも添える。

## 個人情報を公開リポジトリに出さない仕組み

`export.sh` は許可リスト方式にする。設定ファイルから載せてよいキーだけを抜き、全部をコピーしてから消す方式は採らない(新しく増えた設定が素通りで公開されるため)。

禁止語の検索(`scrub.sh`)は `git ls-files` の全体と、commit 予定の差分を対象にし(画像などのバイナリは、圧縮データの偶然の一致を拾うので除く)、1 件でもあれば止めて該当箇所を表示する。export.sh の最後と、個人 PC の pre-commit hook の両方から呼ぶ(手で直したあとの commit も通すため。公開リポジトリは一度 push すると履歴に残る)。禁止語はメールアドレス・クライアント名・ホームディレクトリの絶対パス・token や key 形式の文字列。一覧はクライアント名を含むので、git 管理外の `.scrub-words`(個人 PC にだけ置く)に書く。`.scrub-words` が無いときは止める。

## 個人 PC と会社 PC のずれを防ぐ

会社 PC は 3 リポジトリの main を GitHub から取る。個人 PC の手元が作業ブランチにいたり未コミットの変更があったりすると、個人 PC で動いているものと会社 PC に届くものがずれる。export.sh の最初に、Skills・claude-mods・project-context-template が main にいて、未コミットの変更が無く、origin/main と一致しているかを確かめ、ずれていれば止める。

mod は版の番号つきで入るので、claude-mods を直したら plugin.json の version を上げる(claude-mods の README の開発手順に追記する)。

## 更新の流れ

| 変えたもの | 個人 PC | 会社 PC |
|---|---|---|
| Helix・starship・シェル・git | dev-setup の config を直して push(export.sh で書き出してもよい) | `git -C ~/Developer/dev-setup pull` で反映 |
| Claude Code 設定・プラグイン・Orca 設定 | `scripts/export.sh` → commit → push | `git pull` → Claude に「差分を反映して」と頼み、ステップ 6・7・9 のうち該当するものをやり直す |
| skill | Skills の main に push | `git -C ~/Developer/Skills pull`(新しい skill があれば `link-skills.sh` を再実行) |
| mod | version を上げて claude-mods の main に push | `claude plugin marketplace update claude-mods` → `claude plugin update orca-split-editor@claude-mods` → `/reload-plugins` |
| テンプレート | project-context-template の main に push | `git -C ~/Developer/project-context-template pull`(既に作ったコンテキストリポジトリへは反映しない) |

## check.sh の点検項目

- Brewfile の各パッケージと Hack Nerd Font が入っている
- `/Applications/Orca.app/Contents/Resources/bin/orca` があり、版を表示する
- 非対話シェルで `$VISUAL` が `hx`
- Helix・starship の設定が dev-setup への symlink、`~/.gitconfig` に include がある
- `~/.claude/keybindings.json` で Chat の ctrl+g が null、Global の ctrl+g が `app:toggleReplTab`
- `~/.claude/settings.json` に settings.partial.json のキーが入っている(ステップ 0 で飛ばした値は除く)
- `claude plugin list --json` に plugins.txt の全件が有効で出る
- `~/Developer/Skills` で `scripts/link-skills.sh --check` が通る
- `~/.agents/skills` に orca-cli・orchestration がある。無ければ `orca skills install` で入れるよう案内する
- `~/Developer/project-context-template` がある
- Orca の SQLite の settings が `config/orca/settings.json` と一致する

1 項目ずつ ok / ng を出し、ng が 1 つでもあれば exit 1 にする。

## テスト

- 個人 PC で `export.sh` を実行し、禁止語検索が通ること、わざと禁止語を入れたファイルで export.sh と pre-commit hook の両方が止まること、3 リポジトリのどれかを作業ブランチにすると止まることを確かめる。
- 個人 PC で `check.sh` を実行する。個人 PC は会社 PC の上位集合ではない(symlink でなく実ファイルの設定・directory 指定の claude-mods など)ので、ng になる項目が上の違いで説明できることを確かめる。
- 空の HOME(`HOME=<scratchpad>`)で SETUP.md のステップ 3〜5 を試し、symlink・source・include・マージが既存ファイルを壊さないことを確かめる。
- 会社 PC での初回実行が本番の確認になる。止まった箇所は SETUP.md を直して個人 PC から push する。
