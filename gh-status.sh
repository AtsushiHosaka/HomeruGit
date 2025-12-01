#!/bin/bash

# ==========================================
# gh-status: 現在の状況を表示し、次のアクションを提案
# 使い方: gh-status
# ==========================================

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 褒めるメッセージ関数
praise_user() {
    MESSAGES=(
        "状況確認する癖、素晴らしい！"
        "現状把握えらい！"
        "確認してから動く、プロの姿勢だね！"
        "状況を見てから判断、いいね！"
    )
    RANDOM_INDEX=$(( RANDOM % ${#MESSAGES[@]} ))
    echo "${MESSAGES[${RANDOM_INDEX}]}"
}

CURRENT_BRANCH=$(git branch --show-current)

echo "================================================"
echo "📊 HomeruGit ステータス"
echo "================================================"
echo ""
echo "📍 現在のブランチ: ${CURRENT_BRANCH}"
echo ""

# ブランチ一覧
echo "📋 ローカルブランチ一覧:"
git branch --format="   %(if)%(HEAD)%(then)→ %(else)  %(end)%(refname:short)"
echo ""

# 最近のコミット履歴（現在のブランチ）
echo "📜 最近のコミット (${CURRENT_BRANCH}):"
git log --oneline -5 2>/dev/null | while read line; do
    echo "   ${line}"
done
echo ""

# 変更状況の確認
UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

HAS_CHANGES=false
if [ "${UNSTAGED}" != "0" ] || [ "${STAGED}" != "0" ] || [ "${UNTRACKED}" != "0" ]; then
    HAS_CHANGES=true
    echo "📝 変更状況:"
    if [ "${STAGED}" != "0" ]; then
        echo "   ✅ ステージ済み: ${STAGED}ファイル"
    fi
    if [ "${UNSTAGED}" != "0" ]; then
        echo "   📄 未ステージ: ${UNSTAGED}ファイル"
    fi
    if [ "${UNTRACKED}" != "0" ]; then
        echo "   🆕 新規ファイル: ${UNTRACKED}ファイル"
    fi
    echo ""
fi

# リモートとの差分確認
git fetch origin ${CURRENT_BRANCH} 2>/dev/null

REMOTE_EXISTS=$(git ls-remote --heads origin ${CURRENT_BRANCH} 2>/dev/null)
AHEAD=0
BEHIND=0

if [ -n "${REMOTE_EXISTS}" ]; then
    AHEAD=$(git rev-list --count origin/${CURRENT_BRANCH}..HEAD 2>/dev/null || echo "0")
    BEHIND=$(git rev-list --count HEAD..origin/${CURRENT_BRANCH} 2>/dev/null || echo "0")

    if [ "${AHEAD}" != "0" ] || [ "${BEHIND}" != "0" ]; then
        echo "🔄 リモートとの差分:"
        if [ "${AHEAD}" != "0" ]; then
            echo "   ⬆️ プッシュ待ち: ${AHEAD}コミット"
        fi
        if [ "${BEHIND}" != "0" ]; then
            echo "   ⬇️ プル待ち: ${BEHIND}コミット"
        fi
        echo ""
    fi
fi

# PRの状態確認（main以外の場合）
if [ "${CURRENT_BRANCH}" != "main" ]; then
    PR_INFO=$(gh pr view ${CURRENT_BRANCH} --json state,url,title 2>/dev/null)
    if [ -n "${PR_INFO}" ]; then
        PR_STATE=$(echo "${PR_INFO}" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
        PR_URL=$(echo "${PR_INFO}" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        PR_TITLE=$(echo "${PR_INFO}" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)

        echo "🔀 PR状態:"
        case ${PR_STATE} in
            "OPEN")
                echo "   📬 オープン中: ${PR_TITLE}"
                echo "   🔗 ${PR_URL}"
                ;;
            "MERGED")
                echo "   ✅ マージ済み: ${PR_TITLE}"
                ;;
            "CLOSED")
                echo "   ❌ クローズ: ${PR_TITLE}"
                ;;
        esac
        echo ""
    fi
fi

echo "================================================"
echo "💡 次にやること"
echo "================================================"
echo ""

# サジェストロジック
SUGGESTION_MADE=false

# 1. 未コミットの変更がある場合
if [ "${HAS_CHANGES}" = true ]; then
    echo "📌 コミットされていない変更があります！"
    echo ""
    echo "   → gh-push"
    echo "     変更をコミットしてプッシュしよう！"
    echo ""
    SUGGESTION_MADE=true
fi

# 2. プル待ちがある場合
if [ "${BEHIND}" != "0" ]; then
    echo "📌 リモートに新しい変更があります！"
    echo ""
    echo "   → gh-pull"
    echo "     最新の変更を取り込もう！"
    echo ""
    SUGGESTION_MADE=true
fi

# 3. プッシュ待ちがある場合（変更がない状態で）
if [ "${AHEAD}" != "0" ] && [ "${HAS_CHANGES}" = false ]; then
    echo "📌 プッシュされていないコミットがあります！"
    echo ""
    echo "   → gh-push"
    echo "     リモートにプッシュしよう！"
    echo ""
    SUGGESTION_MADE=true
fi

# 4. main以外でPRがオープンの場合
if [ "${CURRENT_BRANCH}" != "main" ] && [ "${PR_STATE}" = "OPEN" ]; then
    if [ "${SUGGESTION_MADE}" = false ] || [ "${HAS_CHANGES}" = false ]; then
        echo "📌 PRがオープン中です！"
        echo ""
        echo "   → GitHubでPRをレビュー＆マージしよう！"
        echo "     ${PR_URL}"
        echo ""
        SUGGESTION_MADE=true
    fi
fi

# 5. main以外でPRがマージ済みの場合
if [ "${CURRENT_BRANCH}" != "main" ] && [ "${PR_STATE}" = "MERGED" ]; then
    echo "📌 PRはマージ済みです！"
    echo ""
    echo "   → gh-branch main"
    echo "     mainブランチに戻って最新を取得しよう！"
    echo ""
    SUGGESTION_MADE=true
fi

# 6. main以外でPRがない場合（かつ変更もない）
if [ "${CURRENT_BRANCH}" != "main" ] && [ -z "${PR_INFO}" ] && [ "${HAS_CHANGES}" = false ] && [ "${AHEAD}" = "0" ]; then
    echo "📌 このブランチにはまだPRがありません"
    echo ""
    echo "   → コードを書いて gh-push しよう！"
    echo "     プッシュすると自動でPRが作成されるよ！"
    echo ""
    SUGGESTION_MADE=true
fi

# 7. mainにいて、特にやることがない場合
if [ "${CURRENT_BRANCH}" = "main" ] && [ "${SUGGESTION_MADE}" = false ]; then
    echo "📌 mainブランチは最新の状態です！"
    echo ""
    echo "   → gh-branch <新しいブランチ名>"
    echo "     新しい機能を開発しよう！"
    echo ""
    echo "   例: gh-branch feature/awesome-feature"
    echo ""
    SUGGESTION_MADE=true
fi

# 8. 特に何もない場合のフォールバック
if [ "${SUGGESTION_MADE}" = false ]; then
    echo "📌 特にやることはありません！"
    echo ""
    echo "   素晴らしい！すべて順調です！"
    echo ""
fi

echo "================================================"
echo "👏 $(praise_user)"
echo "================================================"
