#!/bin/bash

# ==========================================
# gh-branch: ブランチ切り替え（なければ作成 + pull自動実行）
# 使い方: gh-branch <ブランチ名>
# ==========================================

# 褒めるメッセージ関数
praise_user() {
    local action=$1

    case $action in
        "new_branch")
            MESSAGES=(
                "新しいブランチを作ったね！挑戦する姿勢が素晴らしい！"
                "ブランチ作成完了！ここから新しい機能を作っていこう！"
                "新ブランチでスタート！ワクワクするね！"
            )
            ;;
        "switch_branch")
            MESSAGES=(
                "ブランチを切り替えたよ！マルチタスクえらい！"
                "サクッと切り替え完了！作業効率バッチリだね！"
                "ブランチ移動OK！どんどん進めていこう！"
            )
            ;;
        "pulled")
            MESSAGES=(
                "最新の状態に同期できたよ！準備万端！"
                "リモートと同期完了！これで安心して開発できるね！"
            )
            ;;
        "back_to_main")
            MESSAGES=(
                "mainブランチに戻ってきたね！お疲れ様！"
                "mainに帰還！次は何を作る？"
            )
            ;;
        *)
            MESSAGES=("よくできました！")
            ;;
    esac

    RANDOM_INDEX=$(( RANDOM % ${#MESSAGES[@]} ))
    echo "${MESSAGES[${RANDOM_INDEX}]}"
}

# 引数チェック
if [ -z "$1" ]; then
    echo "❌ ブランチ名を指定してください"
    echo "💡 使い方: gh-branch <ブランチ名>"
    echo ""
    echo "📋 ローカルブランチ一覧:"
    git branch
    exit 1
fi

TARGET_BRANCH=$1
CURRENT_BRANCH=$(git branch --show-current)

# 同じブランチにいる場合
if [ "${TARGET_BRANCH}" = "${CURRENT_BRANCH}" ]; then
    echo "📍 既に '${TARGET_BRANCH}' ブランチにいます"
    echo "👏 確認する癖、いいね！"
    exit 0
fi

# 未コミットの変更があるか確認（未追跡ファイルも含む）
HAS_CHANGES=false
if ! git diff --quiet || ! git diff --cached --quiet; then
    HAS_CHANGES=true
fi
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
if [ "${UNTRACKED}" != "0" ]; then
    HAS_CHANGES=true
fi

if [ "${HAS_CHANGES}" = true ]; then
    echo "⚠️ コミットされていない変更があります"
    echo ""
    echo "📋 変更されたファイル:"
    git status --short
    echo ""
    echo "🤔 変更を新しいブランチ '${TARGET_BRANCH}' に持っていく？"
    echo "   y: 変更を持っていく（そのまま切り替え）"
    echo "   N: 今のブランチ(${CURRENT_BRANCH})でコミット＆プッシュしてから切り替え"
    echo ""
    read -p "選択 [y/N]: " CHOICE

    case "${CHOICE}" in
        [yY]|[yY][eE][sS])
            echo ""
            echo "📦 変更を持ったまま切り替えます..."
            # そのまま続行（変更を持っていく）
            ;;
        *)
            echo ""
            echo "📤 現在のブランチでプッシュしてから切り替えます..."
            echo ""

            # gh-push を実行
            SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
            "${SCRIPT_DIR}/gh-push.sh"
            PUSH_STATUS=$?

            if [ ${PUSH_STATUS} -ne 0 ]; then
                echo ""
                echo "❌ プッシュに失敗したため、ブランチ切り替えを中止します"
                exit 1
            fi

            echo ""
            echo "✅ プッシュ完了！ブランチを切り替えます..."
            echo ""
            ;;
    esac
fi

# ブランチが存在するか確認（ローカル）
LOCAL_EXISTS=$(git branch --list ${TARGET_BRANCH})

# ブランチが存在するか確認（リモート）
REMOTE_EXISTS=$(git ls-remote --heads origin ${TARGET_BRANCH} 2>/dev/null)

echo "🔀 ブランチ '${TARGET_BRANCH}' に切り替え中..."

if [ -n "${LOCAL_EXISTS}" ]; then
    # ローカルに存在する場合はチェックアウト
    git checkout ${TARGET_BRANCH}
    CHECKOUT_STATUS=$?
    BRANCH_ACTION="switch_branch"

    if [ "${TARGET_BRANCH}" = "main" ]; then
        BRANCH_ACTION="back_to_main"
    fi
elif [ -n "${REMOTE_EXISTS}" ]; then
    # リモートにのみ存在する場合はトラッキングブランチとして作成
    echo "📥 リモートブランチを取得中..."
    git fetch origin ${TARGET_BRANCH}
    git checkout -b ${TARGET_BRANCH} origin/${TARGET_BRANCH}
    CHECKOUT_STATUS=$?
    BRANCH_ACTION="switch_branch"
else
    # どこにも存在しない場合は新規作成
    git checkout -b ${TARGET_BRANCH}
    CHECKOUT_STATUS=$?
    BRANCH_ACTION="new_branch"
fi

if [ ${CHECKOUT_STATUS} -ne 0 ]; then
    echo ""
    echo "❌ ブランチの切り替えに失敗しました"
    exit 1
fi

echo ""
echo "------------------------------------------------"
echo "✅ ブランチ '${TARGET_BRANCH}' に切り替えました！"
echo ""
echo "👏 $(praise_user "${BRANCH_ACTION}")"
echo "------------------------------------------------"

# リモートブランチが存在する場合はpull
if [ -n "${REMOTE_EXISTS}" ] || [ "${TARGET_BRANCH}" = "main" ]; then
    echo ""
    echo "📥 リモートから最新の変更を取得中..."
    git pull origin ${TARGET_BRANCH} 2>/dev/null

    if [ $? -eq 0 ]; then
        echo ""
        echo "👏 $(praise_user "pulled")"
    else
        echo ""
        echo "💡 リモートに変更がないか、まだプッシュされていないブランチです"
    fi
fi
