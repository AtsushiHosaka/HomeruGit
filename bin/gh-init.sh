#!/bin/bash

# ==========================================
# gh-init: 新しいリポジトリを作成してGitHubに接続
# 使い方: gh-init [リポジトリ名]
# ==========================================

# 褒めるメッセージ関数
praise_user() {
    local action=$1

    case $action in
        "init")
            MESSAGES=(
                "新しいプロジェクト開始！ワクワクするね！"
                "リポジトリ作成おめでとう！最初の一歩を踏み出したね！"
                "開発スタート！応援してるよ！"
            )
            ;;
        "already_repo")
            MESSAGES=(
                "既にGitリポジトリだね！準備万端！"
                "ちゃんと確認してから始める姿勢、いいね！"
            )
            ;;
        "connected")
            MESSAGES=(
                "GitHubと繋がったよ！世界に公開する準備完了！"
                "リモート設定完了！これでプッシュできるね！"
            )
            ;;
        *)
            MESSAGES=("よくできました！")
            ;;
    esac

    RANDOM_INDEX=$(( RANDOM % ${#MESSAGES[@]} ))
    echo "${MESSAGES[${RANDOM_INDEX}]}"
}

echo "================================================"
echo "🚀 HomeruGit 初期設定"
echo "================================================"
echo ""

# GitHub CLIの確認
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) がインストールされていません"
    echo ""
    echo "💡 インストール方法:"
    echo "   Mac:   brew install gh"
    echo "   Win:   winget install GitHub.cli"
    echo "   Linux: https://github.com/cli/cli#installation"
    echo ""
    exit 1
fi

# 認証状態の確認
if ! gh auth status &> /dev/null; then
    echo "🔑 GitHubにログインしていません"
    echo ""
    echo "今からログイン設定を行います！"
    echo ""
    echo "================================================"
    echo "📝 Personal Access Token (PAT) の取得方法"
    echo "================================================"
    echo ""
    echo "1. 以下のURLをブラウザで開いてください:"
    echo "   https://github.com/settings/tokens/new"
    echo ""
    echo "2. 設定項目:"
    echo "   - Note: HomeruGit (任意の名前)"
    echo "   - Expiration: お好みで (90 days推奨)"
    echo "   - スコープ: ✅ repo にチェック"
    echo ""
    echo "3. 'Generate token' をクリック"
    echo ""
    echo "4. 表示されたトークンをコピー (ghp_xxxx...)"
    echo "   ⚠️ この画面を閉じると二度と表示されません！"
    echo ""
    echo "================================================"
    echo ""
    read -p "PATを取得できたら Enter を押してください..."
    echo ""

    # gh auth login を対話的に実行
    echo "🔐 GitHub CLI でログインします..."
    echo ""
    echo "以下の選択肢が表示されたら:"
    echo "  - GitHub.com を選択"
    echo "  - HTTPS を選択"
    echo "  - 'Paste an authentication token' を選択"
    echo "  - コピーしたPATを貼り付け"
    echo ""
    read -p "準備ができたら Enter を押してください..."
    echo ""

    gh auth login

    # 再度確認
    if ! gh auth status &> /dev/null; then
        echo ""
        echo "❌ ログインに失敗しました"
        echo "💡 もう一度 gh-init を実行してください"
        exit 1
    fi

    echo ""
    echo "------------------------------------------------"
    echo "🎉 GitHubへのログイン成功！"
    echo "👏 初期設定できたね！これで準備万端！"
    echo "------------------------------------------------"
    echo ""
fi

echo "✅ GitHub CLI: 認証済み"
echo ""

# エイリアス設定の確認と追加
setup_aliases() {
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

    # シェル設定ファイルの特定
    if [ -n "${ZSH_VERSION}" ] || [ "${SHELL}" = "/bin/zsh" ]; then
        SHELL_RC="${HOME}/.zshrc"
    else
        SHELL_RC="${HOME}/.bashrc"
    fi

    # 既にエイリアスが設定されているか確認
    if grep -q "gh-init=" "${SHELL_RC}" 2>/dev/null; then
        echo "✅ エイリアス: 設定済み"
        return 0
    fi

    echo "🔧 エイリアスを設定しますか？"
    echo "   ${SHELL_RC} に追加されます"
    echo ""
    read -p "設定する？ [Y/n]: " ALIAS_CHOICE

    case "${ALIAS_CHOICE}" in
        [nN]|[nN][oO])
            echo ""
            echo "💡 後で手動で設定する場合:"
            echo "   以下を ${SHELL_RC} に追加してください:"
            echo ""
            echo "   alias gh-init='${SCRIPT_DIR}/gh-init.sh'"
            echo "   alias gh-status='${SCRIPT_DIR}/gh-status.sh'"
            echo "   alias gh-push='${SCRIPT_DIR}/gh-push.sh'"
            echo "   alias gh-branch='${SCRIPT_DIR}/gh-branch.sh'"
            echo "   alias gh-pull='${SCRIPT_DIR}/gh-pull.sh'"
            echo ""
            return 0
            ;;
        *)
            ;;
    esac

    # エイリアスを追加
    echo "" >> "${SHELL_RC}"
    echo "# HomeruGit aliases" >> "${SHELL_RC}"
    echo "alias gh-init='${SCRIPT_DIR}/gh-init.sh'" >> "${SHELL_RC}"
    echo "alias gh-status='${SCRIPT_DIR}/gh-status.sh'" >> "${SHELL_RC}"
    echo "alias gh-push='${SCRIPT_DIR}/gh-push.sh'" >> "${SHELL_RC}"
    echo "alias gh-branch='${SCRIPT_DIR}/gh-branch.sh'" >> "${SHELL_RC}"
    echo "alias gh-pull='${SCRIPT_DIR}/gh-pull.sh'" >> "${SHELL_RC}"

    echo ""
    echo "✅ エイリアスを ${SHELL_RC} に追加しました！"
    echo ""
    echo "💡 今すぐ使うには以下を実行:"
    echo "   source ${SHELL_RC}"
    echo ""
    echo "   または新しいターミナルを開いてください"
    echo ""

    return 0
}

setup_aliases
echo ""

# 既にgitリポジトリか確認
if [ -d ".git" ]; then
    echo "📁 既にGitリポジトリです"
    echo ""

    # リモートの確認
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)
    if [ -n "${REMOTE_URL}" ]; then
        echo "🔗 リモート: ${REMOTE_URL}"
        echo ""
        echo "------------------------------------------------"
        echo "👏 $(praise_user "already_repo")"
        echo "------------------------------------------------"
        echo ""
        echo "💡 次のコマンドを試してみよう:"
        echo "   gh-status  - 現在の状況を確認"
        echo "   gh-push    - 変更をプッシュ"
        exit 0
    else
        echo "⚠️ リモートが設定されていません"
        echo ""
    fi
else
    # git init
    echo "📦 Gitリポジトリを初期化中..."
    git init
    echo ""
fi

# リポジトリ名の決定
REPO_NAME=${1:-$(basename "$(pwd)")}

echo "📝 リポジトリ名: ${REPO_NAME}"
echo ""

# GitHubにリポジトリを作成するか確認
echo "🤔 GitHubに新しいリポジトリを作成しますか？"
echo "   公開設定を選んでください:"
echo ""
echo "   1: Public  (誰でも見れる)"
echo "   2: Private (自分だけ見れる)"
echo "   n: 作成しない (後で手動で設定)"
echo ""
read -p "選択 [1/2/n]: " VISIBILITY_CHOICE

case "${VISIBILITY_CHOICE}" in
    1)
        VISIBILITY="public"
        ;;
    2)
        VISIBILITY="private"
        ;;
    *)
        echo ""
        echo "💡 後でリモートを設定する場合:"
        echo "   git remote add origin https://github.com/USERNAME/${REPO_NAME}.git"
        exit 0
        ;;
esac

echo ""
echo "📤 GitHubにリポジトリを作成中..."

# リポジトリ作成
gh repo create "${REPO_NAME}" --${VISIBILITY} --source=. --remote=origin 2>/dev/null
CREATE_STATUS=$?

if [ ${CREATE_STATUS} -ne 0 ]; then
    echo ""
    echo "⚠️ リポジトリの作成に失敗しました"
    echo ""
    echo "💡 考えられる原因:"
    echo "   - 同名のリポジトリが既に存在する"
    echo "   - 認証の権限が不足している"
    echo ""
    exit 1
fi

echo ""
echo "------------------------------------------------"
echo "✅ リポジトリの作成が完了しました！"
echo ""
echo "👏 $(praise_user "init")"
echo "------------------------------------------------"
echo ""

# 初回コミット＆プッシュの提案
echo "💡 次のステップ:"
echo ""
echo "   1. コードを書く"
echo "   2. gh-push でプッシュ！"
echo ""
echo "   または gh-status で状況を確認しよう！"
