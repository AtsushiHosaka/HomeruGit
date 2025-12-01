#!/bin/bash

# ==========================================
# gh-push: 変更をプッシュ（main以外はPR自動作成）
# 使い方: gh-push [ブランチ名]
# ==========================================

# 褒めるメッセージ関数
praise_user() {
    local action=$1
    local detail=$2

    case $action in
        "push_main")
            MESSAGES=(
                "${detail}行も開発できたね！開発本当に偉い！"
                "${detail}行も変更したよ！さすが！"
                "${detail}行も進捗出せたね！今日も開発お疲れ様ー！"
                "${detail}行の変更をmainに直接プッシュ！決断力があるね！"
            )
            ;;
        "push_branch")
            MESSAGES=(
                "${detail}行の変更をプッシュできたね！ブランチ運用えらい！"
                "ちゃんとブランチで開発してるの偉すぎ！${detail}行も進んだよ！"
                "${detail}行の進捗！ブランチ戦略バッチリだね！"
            )
            ;;
        "pr_created")
            MESSAGES=(
                "PRまで作っちゃった！レビュー待ちだね、わくわく！"
                "PR作成完了！チーム開発の鑑だよ！"
                "自動でPR作れた！あとはマージを待つだけ！"
            )
            ;;
        "initial")
            MESSAGES=(
                "最初のプッシュおめでとう！これから頑張っていこう！"
                "リポジトリにプッシュできたね！素晴らしいスタート！"
            )
            ;;
        *)
            MESSAGES=("よくできました！")
            ;;
    esac

    RANDOM_INDEX=$(( RANDOM % ${#MESSAGES[@]} ))
    echo "${MESSAGES[${RANDOM_INDEX}]}"
}

# 引数からブランチ名を取得（なければ現在のブランチ）
TARGET_BRANCH=${1:-$(git branch --show-current)}

# 現在のブランチを取得
CURRENT_BRANCH=$(git branch --show-current)

# 指定ブランチが現在のブランチと異なる場合はエラー
if [ "${TARGET_BRANCH}" != "${CURRENT_BRANCH}" ]; then
    echo "⚠️ 現在のブランチ(${CURRENT_BRANCH})と指定ブランチ(${TARGET_BRANCH})が異なります"
    echo "💡 先に gh-branch ${TARGET_BRANCH} でブランチを切り替えてください"
    exit 1
fi

echo "🔍 ブランチ: ${CURRENT_BRANCH}"

# 1. すべての変更をステージング
git add . > /dev/null 2>&1

# 変更行数を取得
TOTAL_CHANGES=$(git diff --cached --numstat | awk '{added+=$1; deleted+=$2} END {print added+deleted}')
if [ -z "${TOTAL_CHANGES}" ]; then
    TOTAL_CHANGES=0
fi

# 2. コミット
COMMIT_MSG=$(date +"%m/%d %H:%M")
echo "💬 コミットメッセージ: ${COMMIT_MSG}"
git commit -m "${COMMIT_MSG}"
COMMIT_STATUS=$?

if [ ${COMMIT_STATUS} -ne 0 ]; then
    if git status 2>/dev/null | grep -q "nothing to commit"; then
        echo ""
        echo "⚠️ プッシュする新しい変更はありませんでした。"
        echo "👏 でも確認する姿勢は素晴らしい！"
        exit 0
    else
        echo ""
        echo "🚨 コミットに失敗しました。"
        exit 1
    fi
fi

# 3. リモートブランチが存在するか確認
REMOTE_EXISTS=$(git ls-remote --heads origin ${CURRENT_BRANCH} 2>/dev/null)

# 4. プッシュ
echo ""
echo "📤 '${CURRENT_BRANCH}'ブランチにプッシュ中..."

if [ -z "${REMOTE_EXISTS}" ]; then
    # リモートにブランチがない場合は upstream を設定してプッシュ
    git push -u origin ${CURRENT_BRANCH}
else
    git push origin ${CURRENT_BRANCH}
fi
PUSH_STATUS=$?

if [ ${PUSH_STATUS} -ne 0 ]; then
    echo ""
    echo "❌ プッシュに失敗しました。"
    echo "💡 先に gh-pull でリモートの変更を取り込んでみてください"
    exit 1
fi

# 5. 成功メッセージ
echo ""
echo "------------------------------------------------"
echo "✅ プッシュが完了しました！"
echo ""

if [ ${TOTAL_CHANGES} -eq 0 ]; then
    echo "👏 $(praise_user "initial" "")"
elif [ "${CURRENT_BRANCH}" = "main" ]; then
    echo "👏 $(praise_user "push_main" "${TOTAL_CHANGES}")"
else
    echo "👏 $(praise_user "push_branch" "${TOTAL_CHANGES}")"
fi
echo "------------------------------------------------"

# 6. main以外の場合はPR作成を提案/実行
if [ "${CURRENT_BRANCH}" != "main" ]; then
    echo ""
    echo "🔀 PRを作成中..."

    # 既存のPRがあるか確認
    EXISTING_PR=$(gh pr view ${CURRENT_BRANCH} --json url 2>/dev/null)

    if [ -n "${EXISTING_PR}" ]; then
        PR_URL=$(echo "${EXISTING_PR}" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        echo ""
        echo "📝 既存のPRが見つかりました: ${PR_URL}"
        echo "👏 PRを更新したよ！レビューしてもらおう！"
    else
        # PR作成
        PR_TITLE="${CURRENT_BRANCH}: $(date +"%Y/%m/%d %H:%M")"
        gh pr create --title "${PR_TITLE}" --body "$(cat <<EOF
## 変更内容
このPRは \`${CURRENT_BRANCH}\` ブランチからの変更です。

---
🤖 gh-push で自動作成されました
EOF
)" --base main 2>/dev/null

        if [ $? -eq 0 ]; then
            echo ""
            echo "🎉 PRを作成しました！"
            echo "👏 $(praise_user "pr_created" "")"
        else
            echo ""
            echo "⚠️ PR作成をスキップしました（既に存在するか、権限がない可能性があります）"
        fi
    fi
fi
