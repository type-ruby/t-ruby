#!/bin/bash
#
# JetBrains Plugin Publish Script for T-Ruby
#
# Usage:
#   ./scripts/publish-jetbrains.sh [options]
#
# Options:
#   --build         Build plugin only
#   --package       Create signed plugin ZIP
#   --publish       Publish to JetBrains Marketplace
#   --bump <type>   Bump version (patch|minor|major)
#   --dry-run       Test publish without actually publishing
#   -y, --yes       Skip confirmation prompts
#   --help          Show this help message
#
# Examples:
#   ./scripts/publish-jetbrains.sh --package
#   ./scripts/publish-jetbrains.sh --bump patch --package
#   ./scripts/publish-jetbrains.sh --bump minor --publish
#   ./scripts/publish-jetbrains.sh --publish --dry-run

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JETBRAINS_DIR="$PROJECT_ROOT/editors/jetbrains"
SECRETS_DIR="$JETBRAINS_DIR/.secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
DO_BUILD=false
DO_PACKAGE=false
DO_PUBLISH=false
DRY_RUN=false
YES=false
BUMP_TYPE=""

print_help() {
    echo "JetBrains Plugin Publish Script for T-Ruby"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --build           Build plugin only (unsigned)"
    echo "  --package         Create signed plugin ZIP (includes build)"
    echo "  --publish         Publish to JetBrains Marketplace (includes package)"
    echo "  --bump <type>     Bump version before build (patch|minor|major)"
    echo "  --dry-run         Test publish without actually publishing"
    echo "  -y, --yes         Skip confirmation prompts"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --package                    # Build and create signed ZIP"
    echo "  $0 --bump patch --package       # Bump patch version and package"
    echo "  $0 --bump minor --publish       # Bump minor version and publish"
    echo "  $0 --publish --dry-run          # Test the publish process"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_java() {
    export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null || echo "/opt/homebrew/opt/openjdk@21")
    export PATH="$JAVA_HOME/bin:$PATH"

    if ! command -v java &> /dev/null; then
        log_error "Java is not installed."
        echo ""
        echo "Install it with:"
        echo "  brew install openjdk@21"
        exit 1
    fi
    log_info "Java found: $(java -version 2>&1 | head -1)"
}

check_secrets() {
    if [ ! -f "$SECRETS_DIR/chain.crt" ] || [ ! -f "$SECRETS_DIR/private.pem" ]; then
        log_error "Signing certificates not found."
        echo ""
        echo "Required files:"
        echo "  $SECRETS_DIR/chain.crt"
        echo "  $SECRETS_DIR/private.pem"
        echo ""
        echo "Generate with:"
        echo "  openssl genpkey -algorithm RSA -out .secrets/private.pem -pkeyopt rsa_keygen_bits:4096"
        echo "  openssl req -new -key .secrets/private.pem -out .secrets/request.csr -subj '/CN=T-Ruby/O=T-Ruby'"
        echo "  openssl x509 -req -days 1095 -in .secrets/request.csr -signkey .secrets/private.pem -out .secrets/chain.crt"
        exit 1
    fi

    if [ ! -f "$SECRETS_DIR/env.sh" ]; then
        log_error "Environment file not found: $SECRETS_DIR/env.sh"
        exit 1
    fi

    # Load secrets
    export CERTIFICATE_CHAIN="$(cat "$SECRETS_DIR/chain.crt")"
    export PRIVATE_KEY="$(cat "$SECRETS_DIR/private.pem")"
    export PRIVATE_KEY_PASSWORD=""

    # Load PUBLISH_TOKEN from env.sh
    source "$SECRETS_DIR/env.sh" 2>/dev/null || true

    log_info "Signing certificates loaded"
}

check_publish_token() {
    if [ -z "$PUBLISH_TOKEN" ]; then
        log_error "PUBLISH_TOKEN is not set."
        echo ""
        echo "To publish to JetBrains Marketplace:"
        echo "  1. Go to https://hub.jetbrains.com"
        echo "  2. Profile → Authentication → Permanent Tokens"
        echo "  3. Create token with 'Plugin Repository' scope"
        echo "  4. Add to $SECRETS_DIR/env.sh:"
        echo "     export PUBLISH_TOKEN=\"your-token-here\""
        exit 1
    fi
    log_info "Publish token found"
}

get_version() {
    grep 'version = ' "$JETBRAINS_DIR/build.gradle.kts" | head -1 | sed 's/.*"\(.*\)".*/\1/'
}

bump_version() {
    local bump_type=$1

    OLD_VERSION=$(get_version)

    # Parse version components
    IFS='.' read -r MAJOR MINOR PATCH <<< "$OLD_VERSION"

    case $bump_type in
        patch)
            PATCH=$((PATCH + 1))
            ;;
        minor)
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        major)
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        *)
            log_error "Invalid bump type: $bump_type (use patch|minor|major)"
            exit 1
            ;;
    esac

    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

    log_info "Bumping version: $OLD_VERSION -> $NEW_VERSION"

    # Update build.gradle.kts
    sed -i '' "s/version = \"$OLD_VERSION\"/version = \"$NEW_VERSION\"/" "$JETBRAINS_DIR/build.gradle.kts"

    log_success "Version updated to $NEW_VERSION"
}

do_build() {
    log_info "Building plugin..."
    "$JETBRAINS_DIR/gradlew" buildPlugin -p "$JETBRAINS_DIR"
    log_success "Build completed"
}

do_package() {
    log_info "Creating signed plugin package..."

    # Clean previous builds
    "$JETBRAINS_DIR/gradlew" clean -p "$JETBRAINS_DIR"

    # Build and sign
    "$JETBRAINS_DIR/gradlew" signPlugin -p "$JETBRAINS_DIR"

    VERSION=$(get_version)
    SIGNED_FILE="$JETBRAINS_DIR/build/distributions/t-ruby-intellij-${VERSION}-signed.zip"

    if [ -f "$SIGNED_FILE" ]; then
        SIZE=$(du -h "$SIGNED_FILE" | cut -f1)
        log_success "Package created: $(basename "$SIGNED_FILE") ($SIZE)"
    else
        log_error "Failed to create signed package"
        exit 1
    fi
}

do_publish() {
    log_info "Publishing to JetBrains Marketplace..."

    VERSION=$(get_version)

    if [ "$DRY_RUN" = true ]; then
        log_warn "Dry run mode - not actually publishing"
        log_info "Would publish: t-ruby-intellij-${VERSION}-signed.zip"
        return
    fi

    if [ "$YES" = true ]; then
        "$JETBRAINS_DIR/gradlew" publishPlugin -p "$JETBRAINS_DIR"
        log_success "Published version $VERSION to JetBrains Marketplace"
    else
        echo ""
        echo -e "${YELLOW}You are about to publish version $VERSION to JetBrains Marketplace.${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$JETBRAINS_DIR/gradlew" publishPlugin -p "$JETBRAINS_DIR"
            log_success "Published version $VERSION to JetBrains Marketplace"
        else
            log_warn "Publish cancelled"
        fi
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            DO_BUILD=true
            shift
            ;;
        --package)
            DO_PACKAGE=true
            shift
            ;;
        --publish)
            DO_PUBLISH=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            YES=true
            shift
            ;;
        --bump)
            BUMP_TYPE="$2"
            if [ -z "$BUMP_TYPE" ]; then
                log_error "--bump requires a type (patch|minor|major)"
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# If no action specified, show help
if [ "$DO_BUILD" = false ] && [ "$DO_PACKAGE" = false ] && [ "$DO_PUBLISH" = false ] && [ -z "$BUMP_TYPE" ]; then
    print_help
    exit 0
fi

# Check dependencies
check_java

if [ "$DO_PACKAGE" = true ] || [ "$DO_PUBLISH" = true ]; then
    check_secrets
fi

if [ "$DO_PUBLISH" = true ]; then
    check_publish_token
fi

# Bump version if requested
if [ -n "$BUMP_TYPE" ]; then
    bump_version "$BUMP_TYPE"
fi

# Print version info
VERSION=$(get_version)
log_info "T-Ruby JetBrains Plugin v$VERSION"
echo ""

# Execute actions
if [ "$DO_BUILD" = true ]; then
    do_build
fi

if [ "$DO_PACKAGE" = true ] || [ "$DO_PUBLISH" = true ]; then
    do_package
fi

if [ "$DO_PUBLISH" = true ]; then
    do_publish
fi

echo ""
log_success "Done!"
echo "Plugin URL: https://plugins.jetbrains.com/plugin/29335-t-ruby"
