#!/bin/bash
set -e

# UserPromptSubmit フック: タスク完了後の学び記録リマインダー
# capturing-learnings スキルと連携して .learnings/ への記録を促す

cat <<'EOF'
<learning-reminder>
このタスクで抽出すべき知見が生まれたか評価せよ:
- 調査で判明した非自明な解・回避策
- 想定外の挙動・エラーの原因と対処
- プロジェクト固有のパターン・制約
- デバッグを要した手順

あれば .learnings/ に capturing-learnings 形式（LRN-/ERR-/FEAT- エントリ）で記録すること。
反復・汎用性が高い場合はスキル抽出（authoring-plugins）を検討。
</learning-reminder>
EOF
