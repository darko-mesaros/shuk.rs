#!/bin/sh
# Universal installer script
set -e

# REQUIREMENTS:
# curl, tar

# Configuration
GITHUB_REPO="darko-mesaros/shuk"
BINARY_NAME="shuk"
INSTALL_DIR="$HOME/.local/bin"

# Print error, cleanup and exit
error() {
    echo "❌ Error: $1"
    cleanup
    exit 1
}

# Cleanup function
cleanup() {
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}${ext}.backup" ]; then
        echo "🔄 Restoring backup..."
        mv "${INSTALL_DIR}/${BINARY_NAME}${ext}.backup" "${INSTALL_DIR}/${BINARY_NAME}${ext}"
    fi
    [ -d "$tmp_dir" ] && rm -rf "$tmp_dir"
}

# Welcome message
print_welcome() {
    cat << "EOF"
  ____  _   _ _   _ _  __
 / ___|| | | | | | | |/ /
 \___ \| |_| | | | | ' /
  ___) |  _  | |_| | . \
 |____/|_| |_|\___/|_|\_\

EOF
    echo "Installing shuk..."
    echo "----------------------------------------"
}

# Check for root - please do not install as root
check_not_root() {
    if [ "$(id -u)" = "0" ]; then
        error "This script should not be run as root/sudo"
    fi
}

# Check network connectivity - this should always work, but just in case
check_network() {
    echo "🌐 Checking network connectivity..."
    curl --silent --head https://github.com >/dev/null 2>&1 || error "No internet connection"
}

# Preflight checks
preflight_checks() {
    command -v curl >/dev/null 2>&1 || error "curl is required but not installed"
    command -v tar >/dev/null 2>&1 || error "tar is required but not installed"
    check_not_root
    check_network
}

# Detect OS and architecture
detect_platform() {
    local os arch

    # Detect OS
    case "$(uname -s)" in
        Linux)
            os="unknown-linux-musl"
            ;;
        Darwin)
            os="apple-darwin"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            os="pc-windows-msvc"
            ;;
        *)
            error "unsupported OS: $(uname -s)"
            ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        arm64|aarch64)
            arch="aarch64"
            ;;
        *)
            error "unsupported architecture: $(uname -m)"
            ;;
    esac
    # This is how my archives are named:
    # shuk-x86_64-unknown-linux-gnu.tar.gz
    echo "${arch}-${os}"
}

# Get latest version from GitHub
get_latest_version() {
    VERSION=$(curl --silent --proto '=https' --tlsv1.2 "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/')
    echo "$VERSION"
}

# Download and install the binary
install() {
    local platform="$1"
    local version="$2"
    local tmp_dir
    local ext

    # Determine file extension
    case "$platform" in
        *windows*)
            ext=".exe"
            ;;
        *)
            ext=""
            ;;
    esac

    # Create temporary directory
    tmp_dir=$(mktemp -d)
    trap cleanup ERR

    echo "📥 Downloading ${BINARY_NAME} ${version} for ${platform}..."

    # Download and extract
    curl --proto '=https' --tlsv1.2 -sL "https://github.com/${GITHUB_REPO}/releases/download/${version}/${BINARY_NAME}-${platform}.tar.gz" |
    tar xz -C "$tmp_dir"

    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Backup existing installation
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}${ext}" ]; then
        echo "📦 Backing up existing installation..."
        mv "${INSTALL_DIR}/${BINARY_NAME}${ext}" "${INSTALL_DIR}/${BINARY_NAME}${ext}.backup"
    fi

    # Install binary
    mv "${tmp_dir}/${BINARY_NAME}${ext}" "${INSTALL_DIR}/${BINARY_NAME}${ext}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}${ext}"

    echo "✅ Successfully installed ${BINARY_NAME} to ${INSTALL_DIR}/${BINARY_NAME}${ext}"
}

# Verify installation
verify_installation() {
    echo "🔍 Verifying installation..."
    if ! command -v "${INSTALL_DIR}/${BINARY_NAME}" >/dev/null 2>&1; then
        error "Installation failed: Binary not found in PATH"
    fi
    echo "✅ Verification: $("${INSTALL_DIR}/${BINARY_NAME}" --version)"
}

# Print success message with PATH instructions
print_success_message() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            echo "
🎉 Installation complete! Please add ${INSTALL_DIR} to your PATH:
    setx PATH \"%PATH%;${INSTALL_DIR}\"
"
            ;;
        *)
            echo "
🎉 Installation complete! Please add ${INSTALL_DIR} to your PATH:
    export PATH=\"\$PATH:${INSTALL_DIR}\"

You can add this line to your ~/.bashrc or ~/.zshrc file to make it permanent.
"
            ;;
    esac
}

# Main function
main() {
    print_welcome
    preflight_checks
    echo "🔍 Detecting system..."
    PLATFORM=$(detect_platform)
    echo "📍 Detected platform: $PLATFORM"
    echo "🔍 Getting latest version..."
    VERSION=$(get_latest_version)
    echo "📦 Latest version: $VERSION"
    install "$PLATFORM" "$VERSION"
    verify_installation
    print_success_message
}

# Run main function
main
