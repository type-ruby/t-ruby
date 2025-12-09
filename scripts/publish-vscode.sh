#!/bin/bash
#
# VSCode Extension Publish Script for T-Ruby
#
# Usage:
#   ./scripts/publish-vscode.sh [options]
#
# Options:
#   --build         Compile TypeScript only
#   --package       Create VSIX package
#   --publish       Publish to marketplace(s)
#   --vscode        Target VSCode Marketplace only
#   --openvsx       Target Open VSX (Cursor) only
#   --all           Target both marketplaces (default)
#   --bump <type>   Bump version (patch|minor|major)
#   --dry-run       Test publish without actually publishing
#   -y, --yes       Skip confirmation prompts
#   --help          Show this help message
#
# Examples:
#   ./scripts/publish-vscode.sh --package
#   ./scripts/publish-vscode.sh --bump patch --package
#   ./scripts/publish-vscode.sh --bump minor --publish
#   ./scripts/publish-vscode.sh --publish --dry-run
#   ./scripts/publish-vscode.sh --publish --vscode      # VSCode only
#   ./scripts/publish-vscode.sh --publish --openvsx     # Open VSX (Cursor) only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VSCODE_DIR="$PROJECT_ROOT/editors/vscode"

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
TARGET="all"  # vscode | openvsx | all

print_help() {
    echo "VSCode Extension Publish Script for T-Ruby"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --build           Compile TypeScript only"
    echo "  --package         Create VSIX package (includes build)"
    echo "  --publish         Publish to marketplace(s) (includes package)"
    echo "  --vscode          Target VSCode Marketplace only"
    echo "  --openvsx         Target Open VSX (Cursor) only"
    echo "  --all             Target both marketplaces (default)"
    echo "  --bump <type>     Bump version before build (patch|minor|major)"
    echo "  --dry-run         Test publish without actually publishing"
    echo "  -y, --yes         Skip confirmation prompts"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --package                    # Build and create VSIX"
    echo "  $0 --bump patch --package       # Bump patch version and package"
    echo "  $0 --bump minor --publish       # Bump minor version and publish"
    echo "  $0 --publish --dry-run          # Test the publish process"
    echo "  $0 --publish --vscode           # Publish to VSCode Marketplace only"
    echo "  $0 --publish --openvsx          # Publish to Open VSX (Cursor) only"
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

check_vsce() {
    if ! command -v vsce &> /dev/null; then
        log_error "vsce is not installed."
        echo ""
        echo "Install it with:"
        echo "  npm install -g @vscode/vsce"
        exit 1
    fi
    log_info "vsce found: $(vsce --version)"
}

check_ovsx() {
    # ovsx is used via npx, so we just need npm
    log_info "ovsx will be used via npx"
}

check_npm() {
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed."
        exit 1
    fi
}

get_version() {
    cd "$VSCODE_DIR"
    node -p "require('./package.json').version"
}

bump_version() {
    local bump_type=$1
    cd "$VSCODE_DIR"

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

    # Update package.json
    node -e "
        const fs = require('fs');
        const pkg = require('./package.json');
        pkg.version = '$NEW_VERSION';
        fs.writeFileSync('./package.json', JSON.stringify(pkg, null, 2) + '\n');
    "

    log_success "Version updated to $NEW_VERSION"
}

do_build() {
    log_info "Compiling TypeScript..."
    cd "$VSCODE_DIR"

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        log_info "Installing dependencies..."
        npm install
    fi

    npm run compile
    log_success "Build completed"
}

do_package() {
    log_info "Creating VSIX package..."
    cd "$VSCODE_DIR"

    # Clean previous VSIX files
    rm -f *.vsix

    vsce package

    VERSION=$(get_version)
    VSIX_FILE="t-ruby-${VERSION}.vsix"

    if [ -f "$VSIX_FILE" ]; then
        SIZE=$(du -h "$VSIX_FILE" | cut -f1)
        log_success "Package created: $VSIX_FILE ($SIZE)"
    else
        log_error "Failed to create VSIX package"
        exit 1
    fi
}

do_publish_vscode() {
    log_info "Publishing to VSCode Marketplace..."
    cd "$VSCODE_DIR"

    VERSION=$(get_version)
    VSIX_FILE="t-ruby-${VERSION}.vsix"

    if [ "$DRY_RUN" = true ]; then
        log_warn "Dry run mode - not actually publishing to VSCode Marketplace"
        log_info "Would publish: $VSIX_FILE"
        return
    fi

    if [ "$YES" = true ]; then
        vsce publish
        log_success "Published version $VERSION to VSCode Marketplace"
    else
        echo ""
        echo -e "${YELLOW}You are about to publish version $VERSION to VSCode Marketplace.${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            vsce publish
            log_success "Published version $VERSION to VSCode Marketplace"
        else
            log_warn "VSCode Marketplace publish cancelled"
        fi
    fi
}

do_publish_openvsx() {
    log_info "Publishing to Open VSX (Cursor)..."
    cd "$VSCODE_DIR"

    VERSION=$(get_version)
    VSIX_FILE="t-ruby-${VERSION}.vsix"

    if [ ! -f "$VSIX_FILE" ]; then
        log_error "VSIX file not found: $VSIX_FILE"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        log_warn "Dry run mode - not actually publishing to Open VSX"
        log_info "Would publish: $VSIX_FILE"
        return
    fi

    # Check for OVSX_PAT environment variable
    if [ -z "$OVSX_PAT" ]; then
        log_error "OVSX_PAT environment variable is not set."
        echo ""
        echo "To publish to Open VSX:"
        echo "  1. Create an account at https://open-vsx.org"
        echo "  2. Generate an access token (Settings → Access Tokens)"
        echo "  3. Create namespace: npx ovsx create-namespace t-ruby --pat <token>"
        echo "  4. Set environment variable: export OVSX_PAT=<token>"
        exit 1
    fi

    if [ "$YES" = true ]; then
        npx ovsx publish "$VSIX_FILE" --pat "$OVSX_PAT"
        log_success "Published version $VERSION to Open VSX (Cursor)"
    else
        echo ""
        echo -e "${YELLOW}You are about to publish version $VERSION to Open VSX (Cursor).${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            npx ovsx publish "$VSIX_FILE" --pat "$OVSX_PAT"
            log_success "Published version $VERSION to Open VSX (Cursor)"
        else
            log_warn "Open VSX publish cancelled"
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
        --vscode)
            TARGET="vscode"
            shift
            ;;
        --openvsx)
            TARGET="openvsx"
            shift
            ;;
        --all)
            TARGET="all"
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
check_npm

if [ "$DO_PACKAGE" = true ] || [ "$DO_PUBLISH" = true ]; then
    if [ "$TARGET" = "vscode" ] || [ "$TARGET" = "all" ]; then
        check_vsce
    fi
    if [ "$TARGET" = "openvsx" ] || [ "$TARGET" = "all" ]; then
        check_ovsx
    fi
fi

# Bump version if requested
if [ -n "$BUMP_TYPE" ]; then
    bump_version "$BUMP_TYPE"
fi

# Print version info
VERSION=$(get_version)
log_info "T-Ruby VSCode Extension v$VERSION"
echo ""

# Execute actions
if [ "$DO_BUILD" = true ] || [ "$DO_PACKAGE" = true ] || [ "$DO_PUBLISH" = true ]; then
    do_build
fi

if [ "$DO_PACKAGE" = true ] || [ "$DO_PUBLISH" = true ]; then
    do_package
fi

if [ "$DO_PUBLISH" = true ]; then
    if [ "$TARGET" = "vscode" ] || [ "$TARGET" = "all" ]; then
        do_publish_vscode
    fi
    if [ "$TARGET" = "openvsx" ] || [ "$TARGET" = "all" ]; then
        do_publish_openvsx
    fi
fi

echo ""
log_success "Done!"
