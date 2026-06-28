#!/bin/bash
#
# agent-browser Installation Script
# Installs the agent-browser CLI (Vercel Labs / vercel-labs/agent-browser).
#
# agent-browser is a fast native (Rust) browser automation CLI. A Rust daemon
# drives Chrome directly via the Chrome DevTools Protocol (CDP) -- no Playwright
# or Node.js runtime is required for the daemon itself.
#
# This script tries several install paths (npm / Homebrew / Cargo) and then runs
# "agent-browser install", which DOWNLOADS Chrome for Testing (Google's official
# automation channel) on first run. That download step is mandatory and cannot be
# skipped -- the daemon needs a Chrome for Testing binary to control.
#
# Usage:
#   bash install.sh           # Install with prompts
#   bash install.sh --force   # Force reinstall
#   bash install.sh --check   # Check installation only
#   bash install.sh --help    # Show help
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# Check if agent-browser is installed
check_installation() {
    if command_exists agent-browser; then
        local version
        version=$(agent-browser --version 2>/dev/null || echo "unknown")
        success "agent-browser is installed (version: $version)"
        return 0
    else
        warn "agent-browser is not installed"
        return 1
    fi
}

# Decide which install route to use.
# Preference order:
#   - macOS: Homebrew first (native, no Node runtime), then npm, then Cargo
#   - other: npm first, then Homebrew, then Cargo
# Echoes one of: npm / homebrew / cargo / none
detect_install_route() {
    local os
    os=$(detect_os)

    if [ "$os" = "macos" ]; then
        if command_exists brew; then
            echo "homebrew"
            return 0
        fi
        if command_exists npm; then
            echo "npm"
            return 0
        fi
        if command_exists cargo; then
            echo "cargo"
            return 0
        fi
    else
        if command_exists npm; then
            echo "npm"
            return 0
        fi
        if command_exists brew; then
            echo "homebrew"
            return 0
        fi
        if command_exists cargo; then
            echo "cargo"
            return 0
        fi
    fi

    echo "none"
    return 0
}

# Install agent-browser via the selected route.
# Argument: route (npm / homebrew / cargo)
install_agent_browser() {
    local route="$1"

    case "$route" in
        npm)
            info "using npm"
            info "Installing agent-browser via npm (global)..."
            npm install -g agent-browser
            ;;
        homebrew)
            info "using homebrew"
            info "Installing agent-browser via Homebrew..."
            brew install agent-browser
            ;;
        cargo)
            info "using cargo"
            info "Installing agent-browser via Cargo (this compiles from source)..."
            cargo install agent-browser
            ;;
        *)
            error "No supported installer route was selected."
            return 1
            ;;
    esac

    if ! command_exists agent-browser; then
        error "Installation failed. agent-browser not found in PATH."
        return 1
    fi

    success "agent-browser installed successfully"
    return 0
}

# Install browser dependencies + Chrome for Testing.
# "agent-browser install" downloads Chrome for Testing on first run (mandatory).
# On Linux, --with-deps also installs the required system libraries.
install_browser_deps() {
    local os
    os=$(detect_os)

    info "Running 'agent-browser install' (downloads Chrome for Testing on first run)..."

    if [ "$os" = "linux" ]; then
        info "Detected Linux - installing with system dependencies (--with-deps)..."
        agent-browser install --with-deps
    else
        agent-browser install
    fi

    success "Chrome for Testing and browser dependencies installed"
    return 0
}

# Verify installation
verify_installation() {
    info "Verifying installation..."

    # Test basic command
    if agent-browser --version >/dev/null 2>&1; then
        success "Installation verified"

        # Show version info
        local version
        version=$(agent-browser --version)
        info "Installed version: $version"

        return 0
    else
        error "Verification failed"
        return 1
    fi
}

# Print guidance when no installer route is available.
print_no_route_guidance() {
    error "No supported installer found (npm / brew / cargo)."
    echo ""
    echo "Install one of the following, then re-run this script:"
    echo "  - Node.js + npm (recommended):  https://nodejs.org/"
    echo "      (or use nvm: https://github.com/nvm-sh/nvm)"
    echo "  - Homebrew (macOS/Linux):       https://brew.sh/"
    echo "  - Rust + Cargo:                 https://rustup.rs/"
    echo ""
    echo "After installing, this script will run 'agent-browser install',"
    echo "which downloads Chrome for Testing on first run."
}

# Main installation flow
main() {
    local force_install=false
    local check_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                force_install=true
                shift
                ;;
            --check|-c)
                check_only=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force, -f    Force reinstall even if already installed"
                echo "  --check, -c    Check installation only, don't install"
                echo "  --help, -h     Show this help message"
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    echo "=========================================="
    echo "  agent-browser Installation Script"
    echo "=========================================="
    echo ""

    # Check only mode
    if [ "$check_only" = true ]; then
        if check_installation; then
            exit 0
        else
            exit 1
        fi
    fi

    # Check if already installed (idempotent: skip unless --force)
    if check_installation && [ "$force_install" = false ]; then
        info "agent-browser is already installed."
        echo ""
        echo "To reinstall, run: $0 --force"
        exit 0
    fi

    # Pick an install route (npm / homebrew / cargo). If none, guide and exit.
    local route
    route=$(detect_install_route)

    if [ "$route" = "none" ]; then
        print_no_route_guidance
        exit 1
    fi

    echo ""

    # Install agent-browser
    if ! install_agent_browser "$route"; then
        error "Failed to install agent-browser"
        exit 1
    fi

    echo ""

    # Install browser dependencies + Chrome for Testing
    if ! install_browser_deps; then
        error "Failed to install Chrome for Testing / browser dependencies"
        exit 1
    fi

    echo ""

    # Verify installation
    if ! verify_installation; then
        error "Installation verification failed"
        exit 1
    fi

    echo ""
    echo "=========================================="
    success "Installation complete!"
    echo "=========================================="
    echo ""
    echo "Quick start:"
    echo "  agent-browser open example.com"
    echo "  agent-browser snapshot"
    echo "  agent-browser close"
    echo ""
    echo "Tip: set AGENT_BROWSER_PROFILE to a Chrome profile name or a directory"
    echo "     path to persist sessions across runs (e.g. logged-in state)."
    echo ""
    echo "For more information:"
    echo "  agent-browser --help"
    echo "  https://github.com/vercel-labs/agent-browser"
    echo ""
}

# Run main function
main "$@"
