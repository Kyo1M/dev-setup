# このリポジトリのローカル運用

このリポジトリはリモート(GitHub)を持たず、この PC の git だけで運用する。`AGENTS.md` の Git 運用ルールと初期セットアップフローは、次のとおり読み替える。

- `git pull`・`git push`・PR の作成は行わない。push の提案もしない。
- ブランチの作り方・命名・コミットの区切り・コミットメッセージ案を確認してから commit する点は `AGENTS.md` のとおり。
- 作業の区切りでは「main にマージしますか？」とだけ尋ね、依頼があったら `git switch main && git merge --no-ff <branch>` でローカルにマージする。確定はこのマージで行う。
- lint は `npm run lint --prefix scripts` をローカルで実行する(初回は `npm install --prefix scripts`)。
- `AGENTS.md` の推奨 skill の導入手順(`npx skills add ...`)は使わない。skill はこの PC に配布済みで、実行すると `~/.claude/skills` に実体ができて配布の点検が通らなくなる。足りない skill があれば本人に伝える。
- `.github/` は使わない(GitHub Actions が動かないため、コピー時に除いてある)。
