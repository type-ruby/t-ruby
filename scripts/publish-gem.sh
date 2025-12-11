#!/bin/bash
#
# RubyGems Publish Script for T-Ruby
#
# Usage:
#   ./scripts/publish-gem.sh [options]
#
# Options:
#   --build         Build gem only
#   --publish       Publish to RubyGems (includes build)
#   --bump <type>   Bump version (patch|minor|major)
#   --dry-run       Test publish without actually publishing
#   -y, --yes       Skip confirmation prompts
#   --help          Show this help message
#
# Examples:
#   ./scripts/publish-gem.sh --build
#   ./scripts/publish-gem.sh --bump patch --build
#   ./scripts/publish-gem.sh --bump minor --publish
#   ./scripts/publish-gem.sh --publish --dry-run

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
DO_BUILD=false
DO_PUBLISH=false
DRY_RUN=false
YES=false
BUMP_TYPE=""

print_help() {
    echo "RubyGems Publish Script for T-Ruby"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --build           Build gem only"
    echo "  --publish         Publish to RubyGems (includes build)"
    echo "  --bump <type>     Bump version before build (patch|minor|major)"
    echo "  --dry-run         Test publish without actually publishing"
    echo "  -y, --yes         Skip confirmation prompts"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --build                    # Build gem"
    echo "  $0 --bump patch --build       # Bump patch version and build"
    echo "  $0 --bump minor --publish     # Bump minor version and publish"
    echo "  $0 --publish --dry-run        # Test the publish process"
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

check_gem() {
    if ! command -v gem &> /dev/null; then
        log_error "gem command is not installed."
        exit 1
    fi
    log_info "gem found: $(gem --version)"
}

check_git() {
    if ! command -v git &> /dev/null; then
        log_error "git is not installed."
        exit 1
    fi
}

get_version() {
    grep -E "VERSION\s*=" "$PROJECT_ROOT/lib/t_ruby/version.rb" | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/'
}

bump_version() {
    local bump_type=$1
    cd "$PROJECT_ROOT"

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

    # Update lib/t_ruby/version.rb
    sed -i '' "s/VERSION = \"$OLD_VERSION\"/VERSION = \"$NEW_VERSION\"/" "$PROJECT_ROOT/lib/t_ruby/version.rb"

    # Update README badges
    update_readme_badges "$NEW_VERSION"

    log_success "Version updated to $NEW_VERSION"

    # Auto commit
    commit_version_bump "$NEW_VERSION"
}

update_readme_badges() {
    local version=$1
    cd "$PROJECT_ROOT"

    log_info "Updating README badges..."

    # Update all README files
    for readme in README.md README.ko.md README.ja.md; do
        if [ -f "$readme" ]; then
            # Update badge URL: gem-vX.X.X
            sed -i '' "s/gem-v[0-9]*\.[0-9]*\.[0-9]*/gem-v$version/g" "$readme"
            # Update alt text: Gem: vX.X.X
            sed -i '' "s/Gem: v[0-9]*\.[0-9]*\.[0-9]*/Gem: v$version/g" "$readme"
            log_info "Updated $readme"
        fi
    done

    log_success "README badges updated"
}

commit_version_bump() {
    local version=$1
    cd "$PROJECT_ROOT"

    check_git

    log_info "Committing version bump..."

    git add lib/t_ruby/version.rb README.md README.ko.md README.ja.md

    git commit -m "chore: bump version to v$version"

    log_success "Committed version bump to v$version"
}

do_build() {
    log_info "Building gem..."
    cd "$PROJECT_ROOT"

    # Clean previous gem files
    rm -f *.gem

    gem build t_ruby.gemspec

    VERSION=$(get_version)
    GEM_FILE="t-ruby-${VERSION}.gem"

    if [ -f "$GEM_FILE" ]; then
        SIZE=$(du -h "$GEM_FILE" | cut -f1)
        log_success "Gem built: $GEM_FILE ($SIZE)"
    else
        log_error "Failed to build gem"
        exit 1
    fi
}

do_publish() {
    log_info "Publishing to RubyGems..."
    cd "$PROJECT_ROOT"

    VERSION=$(get_version)
    GEM_FILE="t-ruby-${VERSION}.gem"

    if [ ! -f "$GEM_FILE" ]; then
        log_error "Gem file not found: $GEM_FILE"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        log_warn "Dry run mode - not actually publishing"
        log_info "Would publish: $GEM_FILE"
        return
    fi

    if [ "$YES" = true ]; then
        gem push "$GEM_FILE"
        log_success "Published version $VERSION to RubyGems"
    else
        echo ""
        echo -e "${YELLOW}You are about to publish version $VERSION to RubyGems.${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gem push "$GEM_FILE"
            log_success "Published version $VERSION to RubyGems"
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
if [ "$DO_BUILD" = false ] && [ "$DO_PUBLISH" = false ] && [ -z "$BUMP_TYPE" ]; then
    print_help
    exit 0
fi

# Check dependencies
check_gem

# Bump version if requested
if [ -n "$BUMP_TYPE" ]; then
    bump_version "$BUMP_TYPE"
fi

# Print version info
VERSION=$(get_version)
log_info "T-Ruby Gem v$VERSION"
echo ""

# Execute actions
if [ "$DO_BUILD" = true ] || [ "$DO_PUBLISH" = true ]; then
    do_build
fi

if [ "$DO_PUBLISH" = true ]; then
    do_publish
fi

echo ""
log_success "Done!"
