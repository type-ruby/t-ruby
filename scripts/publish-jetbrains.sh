#!/bin/bash
# JetBrains Marketplace 배포 스크립트
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JETBRAINS_DIR="$PROJECT_ROOT/editors/jetbrains"
SECRETS_DIR="$JETBRAINS_DIR/.secrets"

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🚀 JetBrains Marketplace 배포"
echo "================================"

# Java 확인
export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null || echo "/opt/homebrew/opt/openjdk@21")
export PATH="$JAVA_HOME/bin:$PATH"

if ! command -v java &> /dev/null; then
    echo -e "${RED}❌ Java가 설치되어 있지 않습니다${NC}"
    echo "   brew install openjdk@21"
    exit 1
fi

# Secrets 확인
if [ ! -f "$SECRETS_DIR/chain.crt" ] || [ ! -f "$SECRETS_DIR/private.pem" ]; then
    echo -e "${RED}❌ 서명 인증서가 없습니다${NC}"
    echo "   $SECRETS_DIR/chain.crt"
    echo "   $SECRETS_DIR/private.pem"
    exit 1
fi

if [ ! -f "$SECRETS_DIR/env.sh" ]; then
    echo -e "${RED}❌ 환경변수 파일이 없습니다: $SECRETS_DIR/env.sh${NC}"
    exit 1
fi

# 환경변수 설정
export CERTIFICATE_CHAIN="$(cat "$SECRETS_DIR/chain.crt")"
export PRIVATE_KEY="$(cat "$SECRETS_DIR/private.pem")"
export PRIVATE_KEY_PASSWORD=""

# env.sh에서 PUBLISH_TOKEN 읽기
source "$SECRETS_DIR/env.sh" 2>/dev/null || true

if [ -z "$PUBLISH_TOKEN" ]; then
    echo -e "${RED}❌ PUBLISH_TOKEN이 설정되지 않았습니다${NC}"
    echo "   $SECRETS_DIR/env.sh 파일에 PUBLISH_TOKEN을 추가하세요"
    exit 1
fi

# 현재 버전 확인
CURRENT_VERSION=$(grep 'version = ' "$JETBRAINS_DIR/build.gradle.kts" | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo -e "${YELLOW}현재 버전: $CURRENT_VERSION${NC}"

# 빌드 및 서명
echo ""
echo "📦 플러그인 빌드 및 서명..."
"$JETBRAINS_DIR/gradlew" clean signPlugin -p "$JETBRAINS_DIR"

# 배포
echo ""
echo "🌐 JetBrains Marketplace에 배포..."
"$JETBRAINS_DIR/gradlew" publishPlugin -p "$JETBRAINS_DIR"

echo ""
echo -e "${GREEN}✅ 배포 완료!${NC}"
echo "   https://plugins.jetbrains.com/plugin/29335-t-ruby"
