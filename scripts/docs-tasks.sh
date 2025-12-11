#!/bin/bash
# t-ruby.github.io 문서 사이트 태스크 래퍼
# moon 대신 bash로 문서 사이트 태스크 실행

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$PROJECT_ROOT/../t-ruby.github.io"

# 문서 디렉토리 확인
if [ ! -d "$DOCS_DIR" ]; then
    echo "Error: Documentation directory not found at $DOCS_DIR"
    echo "Please clone t-ruby.github.io repository first."
    exit 1
fi

# 명령어 처리
case "$1" in
    start)
        echo "Starting documentation development server..."
        cd "$DOCS_DIR" && pnpm start
        ;;
    build)
        echo "Building documentation site..."
        cd "$DOCS_DIR" && pnpm build
        ;;
    typecheck)
        echo "Running TypeScript type check..."
        cd "$DOCS_DIR" && pnpm typecheck
        ;;
    deploy)
        echo "Deploying documentation site..."
        cd "$DOCS_DIR" && pnpm deploy
        ;;
    install)
        echo "Installing documentation dependencies..."
        cd "$DOCS_DIR" && pnpm install
        ;;
    *)
        echo "T-Ruby Documentation Tasks"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start      Start development server (localhost:3000)"
        echo "  build      Build production site"
        echo "  typecheck  Run TypeScript type checking"
        echo "  deploy     Deploy to GitHub Pages"
        echo "  install    Install dependencies"
        echo ""
        exit 1
        ;;
esac
