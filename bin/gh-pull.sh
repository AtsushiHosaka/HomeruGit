#!/bin/bash

# ==========================================
# gh-pull: 現在のブランチで最新の変更を取得
# 使い方: gh-pull
# ==========================================

# 褒めるメッセージ関数
praise_user() {
    local action=$1

    case $action in
        "pulled")
            MESSAGES=(
                "最新の状態になったよ！常に同期する姿勢、えらい！"
                "リモートと同期完了！チームワークバッチリだね！"
                "プル完了！これで最新の状態で開発できるね！"
                "同期できた！コンフリクトを防ぐ意識、素晴らしい！"
            )
            ;;
        "already_latest")
            MESSAGES=(
                "既に最新だったよ！確認する癖、いいね！"
                "最新の状態！準備万端だね！"
                "同期済み！すぐに開発を始められるよ！"
            )
            ;;
        "first_sync")
            MESSAGES=(
                "リモートと繋がったよ！これでチーム開発もバッチリ！"
                "初めてのプル成功！素晴らしいスタート！"
            )
            ;;
        *)
            MESSAGES=("よくできました！")
            ;;
    esac

    RANDOM_INDEX=$(( RANDOM % ${#MESSAGES[@]} ))
    echo "${MESSAGES[${RANDOM_INDEX}]}"
}

CURRENT_BRANCH=$(git branch --show-current)

echo "📍 現在のブランチ: ${CURRENT_BRANCH}"
echo ""

# 未コミットの変更があるか確認
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️ 未コミットの変更があります"
    echo ""
    echo "📋 変更されたファイル:"
    git status --short
    echo ""
    echo "💡 プルする前に gh-push でコミットするか、変更を退避してください"
    echo "   (変更を退避: git stash)"
    exit 1
fi

# リモートの情報を取得
echo "🔍 リモートの状態を確認中..."
git fetch origin ${CURRENT_BRANCH} 2>/dev/null
FETCH_STATUS=$?

# リモートにブランチが存在するか確認
REMOTE_EXISTS=$(git ls-remote --heads origin ${CURRENT_BRANCH} 2>/dev/null)

if [ -z "${REMOTE_EXISTS}" ]; then
    echo ""
    echo "💡 リモートにブランチ '${CURRENT_BRANCH}' がまだ存在しません"
    echo "   gh-push で初めてプッシュするとリモートブランチが作成されます"
    echo ""
    echo "👏 確認してくれてありがとう！"
    exit 0
fi

# ローカルとリモートの差分を確認
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse origin/${CURRENT_BRANCH} 2>/dev/null)

if [ "${LOCAL_COMMIT}" = "${REMOTE_COMMIT}" ]; then
    echo ""
    echo "------------------------------------------------"
    echo "✅ 既に最新の状態です！"
    echo ""
    echo "👏 $(praise_user "already_latest")"
    echo "------------------------------------------------"
    exit 0
fi

# プルを実行
echo "📥 最新の変更を取得中..."
git pull origin ${CURRENT_BRANCH}
PULL_STATUS=$?

if [ ${PULL_STATUS} -ne 0 ]; then
    echo ""
    echo "❌ プルに失敗しました"
    echo ""
    echo "💡 コンフリクトが発生している可能性があります"
    echo "   以下のコマンドで状態を確認してください:"
    echo "   git status"
    exit 1
fi

# 取得した変更の数を表示
CHANGES=$(git log ${LOCAL_COMMIT}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "------------------------------------------------"
echo "✅ プルが完了しました！"
echo ""
if [ "${CHANGES}" != "0" ]; then
    echo "📊 ${CHANGES}件のコミットを取得しました"
    echo ""
fi
echo "👏 $(praise_user "pulled")"
echo "------------------------------------------------"
