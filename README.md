# dev-setup

個人 PC と同じ作業環境(Orca・Helix・yazi・Ctrl+G で開くエディタの mod・自作 skill・コンテキストテンプレート)を、別の Mac に作るためのリポジトリです。手順は Claude Code が読んで実行します。

## 別の Mac に入れる

その Mac の Orca で Claude Code を起動し、次の文を渡します。GitHub のアカウントは要りません。

```
git clone https://github.com/Kyo1M/dev-setup ~/Developer/dev-setup を実行し、~/Developer/dev-setup/SETUP.md を読んで、上から順にこの Mac をセットアップしてください
```

手順は clone したファイルを読ませます(Web ページとして読ませると要約されて、コマンドが落ちることがあるため)。Command Line Tools が無い Mac では、最初の `git clone` で導入のダイアログが出るので、先に済ませてください。

途中で、git の名前とメールアドレス、Orca の設定画面での入力、最後の Claude Code の再起動を頼まれます。

## 中身

| 置き場 | 中身 | 別の Mac での読み方 |
|---|---|---|
| `SETUP.md` | Claude Code が上から実行する手順 | Claude が読む |
| `Brewfile` | Helix・starship・zoxide・bat・delta・jq・node・pandoc・uv・yazi(と yazi が検索に使う fd・ripgrep・fzf、プレビューに使う ffmpeg・poppler・imagemagick・sevenzip)・Hack Nerd Font | `brew bundle` |
| `config/helix`・`config/starship.toml` | エディタとプロンプトの設定 | symlink |
| `config/yazi` | ファイラーの設定(ファイルを Helix で開く)と、入れるプラグインの一覧 | symlink・`ya pkg install` |
| `config/ghostty` | Ghostty の設定と配色(Mariana)。Orca のターミナルの配色・フォント・余白の元 | symlink → Orca の「Import from Ghostty」 |
| `config/zsh` | `EDITOR=hx` 等と、zoxide・starship・bat の設定 | `~/.zshenv`・`~/.zshrc` から source |
| `config/git/gitconfig` | delta・merge・diff の設定 | `~/.gitconfig` から include |
| `config/claude` | Claude Code の設定の一部・keybindings(Ctrl+G を mod に回す)・入れるプラグインの一覧 | マージ・symlink・`claude plugin install` |
| `config/orca/settings.json` | Orca の見た目と操作感の設定値 | 設定画面で入れる |
| `config/context/CLAUDE.local.md` | コンテキストリポジトリをローカルの git だけで使うときの読み替え | 新しいコンテキストリポジトリに置く |

skill・mod・コンテキストテンプレートの中身は、それぞれ [Kyo1M/skills](https://github.com/Kyo1M/skills)・[Kyo1M/claude-mods](https://github.com/Kyo1M/claude-mods)・[Kyo1M/project-context-template](https://github.com/Kyo1M/project-context-template) にあり、このリポジトリはそれを指すだけです。

グローバルの CLAUDE.md・memory・認証情報・Codex の設定は持っていきません。

`config/ghostty/themes/Mariana` は Ghostty に同梱の配色ファイル(元は [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)、MIT ライセンス)の写しです。

## 個人 PC で設定を変えたとき

| 変えたもの | 個人 PC | 別の Mac |
|---|---|---|
| Helix・starship・yazi・Ghostty・Claude Code の設定・プラグイン・Orca の設定 | `scripts/export.sh` → commit → push | Claude に「dev-setup を更新したので反映して」(pull も Claude が行う) |
| シェル・git の設定 | `config/zsh`・`config/git` を直して push | 同上(pull すれば読み直しは要らない) |
| skill | Skills の main に push | `git -C ~/Developer/Skills pull` |
| mod | `plugin.json` の version を上げて claude-mods の main に push | Claude に「dev-setup を更新したので反映して」 |

`export.sh` は、Skills・claude-mods・project-context-template の手元が main で GitHub と一致していないと止まります。別の Mac は GitHub の main を取るので、手元とずれたまま書き出さないためです。

## 公開してはいけない語の検索

このリポジトリは公開です。`scripts/scrub.sh` が、メールアドレス・ホームディレクトリの絶対パス・トークンの形の文字列と、`.scrub-words` に書いた語(案件名など)を検索し、見つかれば止めます。

検索は `export.sh` の最後と、commit 前(pre-commit)・commit メッセージ(commit-msg)・push 前(pre-push)の hook で動きます。`.scrub-words` は git 管理外で、個人 PC にだけ置きます。clone し直したときは、`.scrub-words` を作ってから `git config core.hooksPath .githooks` を実行してください。

## 点検

`scripts/check.sh` で、別の Mac の設定が揃っているかを 1 項目ずつ確かめます。個人 PC で実行すると、設定が symlink でなく実ファイルであることなどから ng がいくつか出ますが、想定どおりです。
