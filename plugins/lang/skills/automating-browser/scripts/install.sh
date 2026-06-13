#!/bin/bash
#
# agent-browser Installation Script
# Installs agent-browser CLI tool for browser automation
#
# Usage:
#   bash install.sh           # Install with prompts
#   bash install.sh --force   # Force reinstall
#   bash install.sh --check   # Check installation only
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

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    # Check Node.js
    if ! command_exists node; then
        error "Node.js is not installed. Please install Node.js first."
        echo "  Visit: https://nodejs.org/"
        echo "  Or use nvm: https://github.com/nvm-sh/nvm"
        return 1
    fi

    local node_version
    node_version=$(node --version)
    info "Node.js version: $node_version"

    # Check npm
    if ! command_exists npm; then
        error "npm is not installed. Please install npm."
        return 1
    fi

    local npm_version
    npm_version=$(npm --version)
    info "npm version: $npm_version"

    success "Prerequisites check passed"
    return 0
}

# Install agent-browser
install_agent_browser() {
    info "Installing agent-browser via npm..."

    # Install globally
    npm install -g agent-browser

    if ! command_exists agent-browser; then
        error "Installation failed. agent-browser not found in PATH."
        return 1
    fi

    success "agent-browser installed successfully"
    return 0
}

# Install browser dependencies
install_browser_deps() {
    local os
    os=$(detect_os)

    info "Installing browser dependencies..."

    if [ "$os" = "linux" ]; then
        info "Detected Linux - installing with system dependencies..."
        agent-browser install --with-deps
    else
        agent-browser install
    fi

    success "Browser dependencies installed"
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

    # Check if already installed
    if check_installation && [ "$force_install" = false ]; then
        info "agent-browser is already installed."
        echo ""
        echo "To reinstall, run: $0 --force"
        exit 0
    fi

    # Check prerequisites
    if ! check_prerequisites; then
        error "Prerequisites not met. Please install Node.js and npm first."
        exit 1
    fi

    echo ""

    # Install agent-browser
    if ! install_agent_browser; then
        error "Failed to install agent-browser"
        exit 1
    fi

    echo ""

    # Install browser dependencies
    if ! install_browser_deps; then
        error "Failed to install browser dependencies"
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
    echo "  agent-browser open https://example.com"
    echo "  agent-browser snapshot -i"
    echo "  agent-browser close"
    echo ""
    echo "For more information:"
    echo "  agent-browser --help"
    echo "  https://github.com/vercel-labs/agent-browser"
    echo ""
}

# Run main function
main "$@"
