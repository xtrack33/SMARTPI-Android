#!/bin/bash
# build_local.sh - Build SmartPi Android 10 locally
# Requirements: Ubuntu 20.04/22.04, 32GB+ RAM, 300GB+ disk

set -e

# Configuration
ANDROID_VERSION="android-10.0.0_r47"
DEVICE="smartpi1"
BUILD_TYPE="${1:-userdebug}"
WORK_DIR="${WORK_DIR:-$HOME/smartpi-android}"
JOBS="${JOBS:-$(nproc)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check requirements
check_requirements() {
    log_info "Checking system requirements..."

    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect OS. This script requires Ubuntu."
        exit 1
    fi

    # Check RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 16 ]; then
        log_warn "Only ${TOTAL_RAM}GB RAM detected. 32GB+ recommended."
        log_warn "Build may fail or be very slow."
    fi

    # Check disk space
    AVAILABLE_DISK=$(df -BG "$HOME" | awk 'NR==2{print $4}' | tr -d 'G')
    if [ "$AVAILABLE_DISK" -lt 200 ]; then
        log_error "Only ${AVAILABLE_DISK}GB disk space available. Need 300GB+."
        exit 1
    fi

    log_info "System check passed. RAM: ${TOTAL_RAM}GB, Disk: ${AVAILABLE_DISK}GB"
}

# Install dependencies
install_deps() {
    log_info "Installing build dependencies..."

    sudo apt-get update
    sudo apt-get install -y \
        git-core gnupg flex bison build-essential zip curl \
        zlib1g-dev libc6-dev-i386 libncurses5 x11proto-core-dev \
        libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils \
        xsltproc unzip fontconfig python3 python-is-python3 \
        bc cpio gettext libssl-dev rsync wget lz4 \
        openjdk-11-jdk ccache repo

    # Configure ccache
    ccache -M 50G
    export USE_CCACHE=1
    export CCACHE_EXEC=/usr/bin/ccache

    log_info "Dependencies installed."
}

# Initialize and sync AOSP
sync_sources() {
    log_info "Syncing Android sources to $WORK_DIR..."

    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    # Configure git
    git config --global user.email "build@smartpi.local"
    git config --global user.name "SmartPi Builder"

    # Initialize repo if needed
    if [ ! -d ".repo" ]; then
        log_info "Initializing AOSP manifest..."
        repo init \
            -u https://android.googlesource.com/platform/manifest \
            -b "$ANDROID_VERSION" \
            --depth=1 \
            --partial-clone
    fi

    # Copy local manifests
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    mkdir -p .repo/local_manifests
    cp "$SCRIPT_DIR/local_manifests/"*.xml .repo/local_manifests/

    # Sync
    log_info "Starting repo sync (this may take several hours)..."
    repo sync -c -j"$JOBS" --no-tags --optimized-fetch

    log_info "Source sync complete."
}

# Copy device tree and vendor
setup_device() {
    log_info "Setting up SmartPi device tree..."

    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

    # Copy device tree
    mkdir -p "$WORK_DIR/device/smartpi/smartpi1"
    cp -r "$SCRIPT_DIR/device/smartpi/smartpi1/"* "$WORK_DIR/device/smartpi/smartpi1/"

    # Copy vendor blobs
    mkdir -p "$WORK_DIR/vendor/smartpi"
    cp -r "$SCRIPT_DIR/vendor/smartpi/"* "$WORK_DIR/vendor/smartpi/"

    log_info "Device tree setup complete."
}

# Build Android
build_android() {
    log_info "Starting Android build..."

    cd "$WORK_DIR"

    # Setup environment
    source build/envsetup.sh

    # Select target
    lunch "${DEVICE}-${BUILD_TYPE}"

    # Build
    log_info "Building with $JOBS parallel jobs..."
    make -j"$JOBS" 2>&1 | tee build.log

    log_info "Build complete!"
}

# Package output
package_output() {
    log_info "Packaging build output..."

    OUTPUT_DIR="$WORK_DIR/out/target/product/$DEVICE"
    RELEASE_DIR="$WORK_DIR/release"

    mkdir -p "$RELEASE_DIR"

    # Copy images
    for img in boot.img system.img vendor.img recovery.img; do
        if [ -f "$OUTPUT_DIR/$img" ]; then
            cp "$OUTPUT_DIR/$img" "$RELEASE_DIR/"
            log_info "Copied: $img"
        fi
    done

    # Create checksums
    cd "$RELEASE_DIR"
    sha256sum *.img > SHA256SUMS.txt

    # Create archive
    ARCHIVE_NAME="smartpi1-android10-$(date +%Y%m%d).tar.gz"
    tar -czvf "$ARCHIVE_NAME" *.img SHA256SUMS.txt

    log_info "Release package: $RELEASE_DIR/$ARCHIVE_NAME"
}

# Main
main() {
    echo "========================================"
    echo "  SmartPi Android 10 Builder"
    echo "========================================"
    echo ""
    echo "Device: $DEVICE"
    echo "Build type: $BUILD_TYPE"
    echo "Work directory: $WORK_DIR"
    echo ""

    check_requirements

    case "${2:-full}" in
        deps)
            install_deps
            ;;
        sync)
            sync_sources
            ;;
        setup)
            setup_device
            ;;
        build)
            build_android
            ;;
        package)
            package_output
            ;;
        full|*)
            install_deps
            sync_sources
            setup_device
            build_android
            package_output
            ;;
    esac

    log_info "Done!"
}

main "$@"
