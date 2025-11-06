#!/bin/bash

# 現在の日付と時刻を取得し、コミットメッセージとして使用
COMMIT_MSG=$(date +"%m/%d %H:%M")

# 変更された行数を事前に取得 (プッシュ前の作業ディレクトリ内の変更をカウント)
# -zでNULLバイト区切り、--cachedでステージングされた変更のみを対象に、--numstatで変更行数を取得し、
# awkで追加行($1)と削除行($2)の合計を計算
TOTAL_CHANGES=$(git diff --cached --numstat | awk '{added+=$1; deleted+=$2} END {print added+deleted}')

# 変更がない場合は0として扱う
if [ -z "${TOTAL_CHANGES}" ]; then
    TOTAL_CHANGES=0
fi

# 1. すべての変更をステージング (出力を抑制)
git add . > /dev/null 2>&1

# 2. コミットを実行
echo "💬 コミットメッセージ: ${COMMIT_MSG}"
git commit -m "${COMMIT_MSG}"
COMMIT_STATUS=$?

if [ ${COMMIT_STATUS} -ne 0 ]; then
    if grep -q "nothing to commit" <<< "$(git status 2> /dev/null)"; then
        echo ""
        echo "⚠️ プッシュする新しい変更はありませんでした。"
        exit 0
    else
        echo ""
        echo "🚨 コミットに失敗しました。上記のエラーを確認してください。"
        exit 1
    fi
fi

# 3. メインブランチにプッシュを実行
echo ""
echo "📤 'main'ブランチにプッシュ中..."
git push origin main
PUSH_STATUS=$?

if [ ${PUSH_STATUS} -ne 0 ]; then
    echo ""
    echo "❌ プッシュに失敗しました。上記のエラーを確認してください。"
    exit 1
fi

# 4. プッシュ成功時のランダムメッセージ
# initial commit（変更行数が0の場合）の特別なメッセージ
if [ ${TOTAL_CHANGES} -eq 0 ]; then
    MESSAGE="リポジトリが作成できたね！これからgithubを活用して頑張っていこう！"
else
    # 通常のランダムメッセージ（すべてにTOTAL_CHANGESを含める）
    MESSAGES=(
        "${TOTAL_CHANGES}行も開発できたね！開発本当に偉い！"
        "${TOTAL_CHANGES}行も変更したよ！さすが！"
        "${TOTAL_CHANGES}行も進捗出せたね！今日も開発お疲れ様ー！"
    )

    # 配列の要素数からランダムなインデックスを生成
    # ${#MESSAGES[@]}で配列の要素数を取得し、RANDOM % 要素数で0から要素数-1の乱数を生成
    RANDOM_INDEX=$(( RANDOM % ${#MESSAGES[@]} ))
    MESSAGE="${MESSAGES[${RANDOM_INDEX}]}"
fi

echo ""
echo "------------------------------------------------"
echo "✅ GitHubへのプッシュが完了しました！"
echo ""
echo "👏 ${MESSAGE}"
echo "------------------------------------------------"